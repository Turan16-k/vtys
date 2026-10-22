-- =====================================================================
--  E-SPOR TURNUVA YÖNETİM SİSTEMİ
--  03 - TETİKLEYİCİLER (TRIGGER) VE TETİKLEYİCİ FONKSİYONLARI
-- =====================================================================

-- ---------------------------------------------------------------------
-- T1) Alt tip tutarlılığı ve yaş kontrolü
--     oyuncu / koc / hakem tablolarına eklenen kişinin kisi_turu değeri
--     tabloyla uyumlu olmalıdır. Oyuncular en az 16, koç ve hakemler en
--     az 18 yaşında olmalıdır.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_kisi_alt_tip_kontrol()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_tur      CHAR(1);
    v_dogum    DATE;
    v_beklenen CHAR(1);
    v_min_yas  INT;
BEGIN
    SELECT kisi_turu, dogum_tarihi INTO v_tur, v_dogum
      FROM kisi WHERE kisi_id = NEW.kisi_id;

    IF TG_TABLE_NAME = 'oyuncu' THEN
        v_beklenen := 'O'; v_min_yas := 16;
    ELSIF TG_TABLE_NAME = 'koc' THEN
        v_beklenen := 'K'; v_min_yas := 18;
    ELSE
        v_beklenen := 'H'; v_min_yas := 18;
    END IF;

    IF v_tur IS DISTINCT FROM v_beklenen THEN
        RAISE EXCEPTION 'Kişi türü uyumsuz: % tablosuna yalnızca türü "%" olan kişiler eklenebilir.',
            TG_TABLE_NAME, v_beklenen;
    END IF;

    IF date_part('year', age(v_dogum)) < v_min_yas THEN
        RAISE EXCEPTION '% kaydı için en az % yaşında olmak gerekir.', initcap(TG_TABLE_NAME), v_min_yas;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_oyuncu_alt_tip BEFORE INSERT ON oyuncu
    FOR EACH ROW EXECUTE FUNCTION trg_kisi_alt_tip_kontrol();
CREATE TRIGGER trg_koc_alt_tip BEFORE INSERT ON koc
    FOR EACH ROW EXECUTE FUNCTION trg_kisi_alt_tip_kontrol();
CREATE TRIGGER trg_hakem_alt_tip BEFORE INSERT ON hakem
    FOR EACH ROW EXECUTE FUNCTION trg_kisi_alt_tip_kontrol();

-- ---------------------------------------------------------------------
-- T2) Kadro kontrolü
--     Bir takımın aktif kadrosu, oyunun takım boyutunun en fazla 2 fazlası
--     (yedekler) kadar olabilir. Bir takımın tek kaptanı olur: yeni kaptan
--     atanınca eski kaptanın kaptanlığı otomatik olarak kaldırılır.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_kadro_kontrol()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_limit  INT;
    v_aktif  INT;
BEGIN
    IF NEW.ayrilma_tarihi IS NOT NULL THEN
        NEW.kaptan := FALSE;
        RETURN NEW;
    END IF;

    SELECT o.takim_boyutu + 2 INTO v_limit
      FROM takim t JOIN oyun o ON o.oyun_id = t.oyun_id
     WHERE t.takim_id = NEW.takim_id;

    SELECT count(*) INTO v_aktif
      FROM takim_oyuncu
     WHERE takim_id = NEW.takim_id AND ayrilma_tarihi IS NULL
       AND kadro_id <> NEW.kadro_id;

    IF v_aktif >= v_limit THEN
        RAISE EXCEPTION 'Takım kadrosu dolu: bu oyun için en fazla % aktif oyuncu olabilir.', v_limit;
    END IF;

    IF NEW.kaptan THEN
        UPDATE takim_oyuncu SET kaptan = FALSE
         WHERE takim_id = NEW.takim_id AND kaptan AND kadro_id <> NEW.kadro_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_kadro_kontrol BEFORE INSERT OR UPDATE ON takim_oyuncu
    FOR EACH ROW EXECUTE FUNCTION trg_kadro_kontrol();

-- ---------------------------------------------------------------------
-- T3) Turnuva kayıt kontrolü
--     Takım; yalnızca kendi oyununa ait, kaydı açık ve kontenjanı dolmamış
--     turnuvalara kaydolabilir. Kayıt için takımın aktif kadrosunda en az
--     oyunun takım boyutu kadar oyuncu bulunmalıdır.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_katilim_kontrol()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_turnuva  turnuva%ROWTYPE;
    v_takim    takim%ROWTYPE;
    v_boyut    SMALLINT;
    v_kayitli  INT;
    v_kadro    INT;
BEGIN
    SELECT * INTO v_turnuva FROM turnuva WHERE turnuva_id = NEW.turnuva_id;
    SELECT * INTO v_takim   FROM takim   WHERE takim_id   = NEW.takim_id;

    IF v_turnuva.durum <> 'Kayıt Açık' THEN
        RAISE EXCEPTION 'Bu turnuvanın kaydı kapalı (durum: %).', v_turnuva.durum;
    END IF;

    IF v_turnuva.oyun_id <> v_takim.oyun_id THEN
        RAISE EXCEPTION '% takımı bu turnuvanın oyununda yarışmıyor.', v_takim.takim_adi;
    END IF;

    SELECT count(*) INTO v_kayitli FROM turnuva_katilim WHERE turnuva_id = NEW.turnuva_id;
    IF v_kayitli >= v_turnuva.max_takim THEN
        RAISE EXCEPTION 'Turnuva kontenjanı dolu (en fazla % takım).', v_turnuva.max_takim;
    END IF;

    SELECT takim_boyutu INTO v_boyut FROM oyun WHERE oyun_id = v_takim.oyun_id;
    SELECT count(*) INTO v_kadro
      FROM takim_oyuncu WHERE takim_id = NEW.takim_id AND ayrilma_tarihi IS NULL;
    IF v_kadro < v_boyut THEN
        RAISE EXCEPTION '% takımının aktif kadrosu yetersiz (% / % oyuncu).',
            v_takim.takim_adi, v_kadro, v_boyut;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_katilim_kontrol BEFORE INSERT ON turnuva_katilim
    FOR EACH ROW EXECUTE FUNCTION trg_katilim_kontrol();

-- ---------------------------------------------------------------------
-- T4) Maç kontrolü ve kazananın belirlenmesi
--     Maçtaki iki takım da turnuvaya kayıtlı olmalıdır. Sonuç yalnızca
--     "Devam Ediyor" durumundaki turnuvalarda girilebilir ve sonucu girilmiş
--     maç değiştirilemez. Skor girildiğinde kazanan otomatik atanır.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_mac_kontrol()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_durum VARCHAR;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.durum = 'Oynandı' THEN
        IF NEW.takim1_skor IS DISTINCT FROM OLD.takim1_skor
           OR NEW.takim2_skor IS DISTINCT FROM OLD.takim2_skor
           OR NEW.durum <> OLD.durum
           OR NEW.takim1_id <> OLD.takim1_id OR NEW.takim2_id <> OLD.takim2_id THEN
            RAISE EXCEPTION 'Sonucu girilmiş bir maçın skoru, durumu veya takımları değiştirilemez.';
        END IF;
    END IF;

    IF (SELECT count(*) FROM turnuva_katilim
         WHERE turnuva_id = NEW.turnuva_id
           AND takim_id IN (NEW.takim1_id, NEW.takim2_id)) < 2 THEN
        RAISE EXCEPTION 'Maçtaki iki takım da bu turnuvaya kayıtlı olmalıdır.';
    END IF;

    IF NEW.durum = 'Oynandı' THEN
        SELECT durum INTO v_durum FROM turnuva WHERE turnuva_id = NEW.turnuva_id;
        IF v_durum <> 'Devam Ediyor' THEN
            RAISE EXCEPTION 'Maç sonucu yalnızca devam eden turnuvalarda girilebilir.';
        END IF;
        NEW.kazanan_id := CASE WHEN NEW.takim1_skor > NEW.takim2_skor
                               THEN NEW.takim1_id ELSE NEW.takim2_id END;
    ELSE
        NEW.kazanan_id := NULL;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_mac_kontrol BEFORE INSERT OR UPDATE ON mac
    FOR EACH ROW EXECUTE FUNCTION trg_mac_kontrol();

-- ---------------------------------------------------------------------
-- T5) Puan tablosunun güncellenmesi
--     Maç "Oynandı" durumuna geçtiğinde kazanan takıma +3 puan ve galibiyet,
--     kaybeden takıma mağlubiyet yazılır; skor farkları güncellenir.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_mac_puan_guncelle()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_kaybeden INT;
    v_fark     INT;
BEGIN
    v_kaybeden := CASE WHEN NEW.kazanan_id = NEW.takim1_id THEN NEW.takim2_id ELSE NEW.takim1_id END;
    v_fark     := abs(NEW.takim1_skor - NEW.takim2_skor);

    UPDATE turnuva_katilim
       SET galibiyet = galibiyet + 1, puan = puan + 3, skor_farki = skor_farki + v_fark
     WHERE turnuva_id = NEW.turnuva_id AND takim_id = NEW.kazanan_id;

    UPDATE turnuva_katilim
       SET maglubiyet = maglubiyet + 1, skor_farki = skor_farki - v_fark
     WHERE turnuva_id = NEW.turnuva_id AND takim_id = v_kaybeden;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_mac_puan_guncelle AFTER UPDATE OF durum ON mac
    FOR EACH ROW
    WHEN (OLD.durum <> 'Oynandı' AND NEW.durum = 'Oynandı')
    EXECUTE FUNCTION trg_mac_puan_guncelle();

-- ---------------------------------------------------------------------
-- T6) Oyuncu maç istatistiği kontrolü
--     İstatistik yalnızca oynanmış maçlar için ve maç tarihinde maçtaki
--     takımlardan birinin kadrosunda olan oyuncular için girilebilir.
--     Oyuncunun takımı otomatik bulunur. Bir maçta tek MVP olur.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_istatistik_kontrol()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_mac    mac%ROWTYPE;
    v_takim  INT;
BEGIN
    SELECT * INTO v_mac FROM mac WHERE mac_id = NEW.mac_id;

    IF v_mac.durum <> 'Oynandı' THEN
        RAISE EXCEPTION 'İstatistik yalnızca oynanmış maçlar için girilebilir.';
    END IF;

    SELECT takim_id INTO v_takim
      FROM takim_oyuncu
     WHERE oyuncu_id = NEW.oyuncu_id
       AND takim_id IN (v_mac.takim1_id, v_mac.takim2_id)
       AND katilma_tarihi <= v_mac.mac_zamani::DATE
       AND (ayrilma_tarihi IS NULL OR ayrilma_tarihi >= v_mac.mac_zamani::DATE)
     ORDER BY katilma_tarihi DESC
     LIMIT 1;

    IF v_takim IS NULL THEN
        RAISE EXCEPTION 'Oyuncu, maç tarihinde maçtaki takımlardan hiçbirinin kadrosunda değildi.';
    END IF;

    NEW.takim_id := v_takim;

    IF NEW.mvp THEN
        UPDATE oyuncu_mac_istatistik SET mvp = FALSE
         WHERE mac_id = NEW.mac_id AND mvp AND istatistik_id <> NEW.istatistik_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_istatistik_kontrol BEFORE INSERT OR UPDATE ON oyuncu_mac_istatistik
    FOR EACH ROW EXECUTE FUNCTION trg_istatistik_kontrol();

-- ---------------------------------------------------------------------
-- T7) Turnuva durum geçişleri ve ödül dağıtımı
--     Tamamlanan turnuva tekrar açılamaz. Turnuva "Tamamlandı" yapılırken
--     tüm maçlar oynanmış (veya iptal edilmiş) olmalıdır. Turnuva
--     tamamlandığında takımların final sıraları yazılır ve ödüller
--     dereceye göre ilgili takımlara otomatik atanır.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_turnuva_durum()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.durum = 'Tamamlandı' THEN
        RAISE EXCEPTION 'Tamamlanmış bir turnuvanın durumu değiştirilemez.';
    END IF;

    IF NEW.durum = 'Tamamlandı' THEN
        IF NOT EXISTS (SELECT 1 FROM mac WHERE turnuva_id = NEW.turnuva_id) THEN
            RAISE EXCEPTION 'Hiç maç oynanmamış bir turnuva tamamlanamaz.';
        END IF;
        IF EXISTS (SELECT 1 FROM mac WHERE turnuva_id = NEW.turnuva_id AND durum = 'Planlandı') THEN
            RAISE EXCEPTION 'Turnuvada henüz oynanmamış maçlar var.';
        END IF;

        UPDATE turnuva_katilim tk
           SET sira = pt.sira
          FROM puan_tablosu(NEW.turnuva_id) pt
         WHERE tk.turnuva_id = NEW.turnuva_id AND tk.takim_id = pt.takim_id;

        UPDATE odul o
           SET takim_id = tk.takim_id
          FROM turnuva_katilim tk
         WHERE o.turnuva_id = NEW.turnuva_id
           AND tk.turnuva_id = NEW.turnuva_id
           AND tk.sira = o.derece;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_turnuva_durum AFTER UPDATE OF durum ON turnuva
    FOR EACH ROW
    WHEN (OLD.durum IS DISTINCT FROM NEW.durum)
    EXECUTE FUNCTION trg_turnuva_durum();

-- ---------------------------------------------------------------------
-- T8) Devam eden turnuvanın silinmesinin engellenmesi
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_turnuva_silme_kontrol()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.durum = 'Devam Ediyor' THEN
        RAISE EXCEPTION 'Devam eden bir turnuva silinemez.';
    END IF;
    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_turnuva_silme_kontrol BEFORE DELETE ON turnuva
    FOR EACH ROW EXECUTE FUNCTION trg_turnuva_silme_kontrol();

-- ---------------------------------------------------------------------
-- T9) Ödül havuzu kontrolü
--     Bir turnuvanın ödüllerinin toplamı, ödül havuzunu aşamaz.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_odul_kontrol()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_havuz   NUMERIC;
    v_toplam  NUMERIC;
BEGIN
    SELECT odul_havuzu INTO v_havuz FROM turnuva WHERE turnuva_id = NEW.turnuva_id;

    SELECT COALESCE(sum(tutar), 0) INTO v_toplam
      FROM odul
     WHERE turnuva_id = NEW.turnuva_id AND odul_id <> NEW.odul_id;

    IF v_toplam + NEW.tutar > v_havuz THEN
        RAISE EXCEPTION 'Ödüller toplamı (%) ödül havuzunu (%) aşamaz.', v_toplam + NEW.tutar, v_havuz;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_odul_kontrol BEFORE INSERT OR UPDATE OF tutar ON odul
    FOR EACH ROW EXECUTE FUNCTION trg_odul_kontrol();

-- ---------------------------------------------------------------------
-- T10) İşlem günlüğü (denetim kaydı)
--      kisi, takim ve turnuva tablolarındaki her ekleme, güncelleme ve
--      silme işlemi islem_log tablosuna JSON olarak kaydedilir.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_islem_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO islem_log (tablo_adi, islem_turu, kayit_bilgisi)
    VALUES (TG_TABLE_NAME, TG_OP,
            CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD)::TEXT
                 ELSE row_to_json(NEW)::TEXT END);
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_kisi_log AFTER INSERT OR UPDATE OR DELETE ON kisi
    FOR EACH ROW EXECUTE FUNCTION trg_islem_log();
CREATE TRIGGER trg_takim_log AFTER INSERT OR UPDATE OR DELETE ON takim
    FOR EACH ROW EXECUTE FUNCTION trg_islem_log();
CREATE TRIGGER trg_turnuva_log AFTER INSERT OR UPDATE OR DELETE ON turnuva
    FOR EACH ROW EXECUTE FUNCTION trg_islem_log();
