-- =====================================================================
--  E-SPOR TURNUVA YÖNETİM SİSTEMİ
--  02 - FONKSİYONLAR VE SAKLI YORDAMLAR
--  (Tetikleyici fonksiyonları 03_tetikleyiciler.sql dosyasındadır.)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) oyuncu_ekle: Kalıtım hiyerarşisine uygun şekilde önce üst tipe (kisi),
--    ardından alt tipe (oyuncu) kayıt ekler; yeni kişinin numarasını döndürür.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION oyuncu_ekle(
    p_ad         VARCHAR,
    p_soyad      VARCHAR,
    p_eposta     VARCHAR,
    p_dogum      DATE,
    p_ulke_id    INT,
    p_takma_ad   VARCHAR,
    p_elo        INT DEFAULT 1000
) RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
    v_kisi_id INT;
BEGIN
    INSERT INTO kisi (ad, soyad, eposta, dogum_tarihi, ulke_id, kisi_turu)
    VALUES (p_ad, p_soyad, lower(p_eposta), p_dogum, p_ulke_id, 'O')
    RETURNING kisi_id INTO v_kisi_id;

    INSERT INTO oyuncu (kisi_id, takma_ad, elo_puani)
    VALUES (v_kisi_id, p_takma_ad, COALESCE(p_elo, 1000));

    RETURN v_kisi_id;
END;
$$;

-- ---------------------------------------------------------------------
-- 2) oyuncu_guncelle (SAKLI YORDAM): Üst tip (kisi) ve alt tip (oyuncu)
--    tablolarındaki bilgileri tek işlemde günceller.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE oyuncu_guncelle(
    p_kisi_id    INT,
    p_ad         VARCHAR,
    p_soyad      VARCHAR,
    p_eposta     VARCHAR,
    p_dogum      DATE,
    p_ulke_id    INT,
    p_takma_ad   VARCHAR,
    p_elo        INT
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE kisi
       SET ad = p_ad, soyad = p_soyad, eposta = lower(p_eposta),
           dogum_tarihi = p_dogum, ulke_id = p_ulke_id
     WHERE kisi_id = p_kisi_id AND kisi_turu = 'O';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Güncellenecek oyuncu bulunamadı (no: %).', p_kisi_id;
    END IF;

    UPDATE oyuncu
       SET takma_ad = p_takma_ad, elo_puani = p_elo
     WHERE kisi_id = p_kisi_id;
END;
$$;

-- ---------------------------------------------------------------------
-- 3) oyuncu_ara: Takma ad, ad, soyad veya takım adına göre oyuncu arar.
--    Boş arama metni tüm oyuncuları getirir.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION oyuncu_ara(p_aranan VARCHAR DEFAULT '')
RETURNS TABLE (
    oyuncu_id   INT,
    takma_ad    VARCHAR,
    ad_soyad    TEXT,
    ulke_adi    VARCHAR,
    yas         INT,
    takim_adi   VARCHAR,
    oyun_adi    VARCHAR,
    elo_puani   INT
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT o.kisi_id,
           o.takma_ad,
           k.ad || ' ' || k.soyad,
           u.ulke_adi,
           date_part('year', age(k.dogum_tarihi))::INT,
           t.takim_adi,
           oy.oyun_adi,
           o.elo_puani
      FROM oyuncu o
      JOIN kisi k              ON k.kisi_id = o.kisi_id
      JOIN ulke u              ON u.ulke_id = k.ulke_id
      LEFT JOIN takim_oyuncu ko ON ko.oyuncu_id = o.kisi_id AND ko.ayrilma_tarihi IS NULL
      LEFT JOIN takim t        ON t.takim_id = ko.takim_id
      LEFT JOIN oyun oy        ON oy.oyun_id = t.oyun_id
     WHERE COALESCE(p_aranan, '') = ''
        OR o.takma_ad ILIKE '%' || p_aranan || '%'
        OR k.ad       ILIKE '%' || p_aranan || '%'
        OR k.soyad    ILIKE '%' || p_aranan || '%'
        OR t.takim_adi ILIKE '%' || p_aranan || '%'
     ORDER BY o.elo_puani DESC, o.takma_ad;
END;
$$;

-- ---------------------------------------------------------------------
-- 4) turnuva_olustur: Turnuva türüne göre üst tip (turnuva) ile birlikte
--    ilgili alt tipe (online_turnuva veya salon_turnuva) kayıt ekler.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION turnuva_olustur(
    p_adi        VARCHAR,
    p_oyun_id    INT,
    p_baslangic  DATE,
    p_bitis      DATE,
    p_odul       NUMERIC,
    p_max_takim  SMALLINT,
    p_tur        CHAR,                       -- 'O' online, 'S' salon
    p_platform   VARCHAR DEFAULT NULL,       -- online için
    p_bolge      VARCHAR DEFAULT NULL,       -- online için
    p_mekan_id   INT     DEFAULT NULL,       -- salon için
    p_bilet      NUMERIC DEFAULT 0           -- salon için
) RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
    v_id INT;
BEGIN
    IF p_tur = 'O' AND (p_platform IS NULL OR p_bolge IS NULL) THEN
        RAISE EXCEPTION 'Online turnuva için yayın platformu ve sunucu bölgesi zorunludur.';
    ELSIF p_tur = 'S' AND p_mekan_id IS NULL THEN
        RAISE EXCEPTION 'Salon turnuvası için mekan seçilmelidir.';
    END IF;

    INSERT INTO turnuva (turnuva_adi, oyun_id, baslangic_tarihi, bitis_tarihi,
                         odul_havuzu, max_takim, turnuva_turu)
    VALUES (p_adi, p_oyun_id, p_baslangic, p_bitis, p_odul, p_max_takim, p_tur)
    RETURNING turnuva_id INTO v_id;

    IF p_tur = 'O' THEN
        INSERT INTO online_turnuva (turnuva_id, yayin_platformu, sunucu_bolgesi)
        VALUES (v_id, p_platform, p_bolge);
    ELSE
        INSERT INTO salon_turnuva (turnuva_id, mekan_id, bilet_fiyati)
        VALUES (v_id, p_mekan_id, COALESCE(p_bilet, 0));
    END IF;

    RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------
-- 5) fikstur_olustur: Turnuvaya kayıtlı takımlar için "herkes herkesle"
--    (lig usulü) grup maçlarını oluşturur, hakemleri sırayla atar ve
--    turnuvayı "Devam Ediyor" durumuna getirir. Oluşan maç sayısını döndürür.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fikstur_olustur(
    p_turnuva_id  INT,
    p_ilk_mac     TIMESTAMP,
    p_aralik      INTERVAL DEFAULT '2 hours'
) RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
    v_durum     VARCHAR;
    v_takimlar  INT[];
    v_hakemler  INT[];
    v_asama_id  INT;
    v_sayac     INT := 0;
    i           INT;
    j           INT;
BEGIN
    SELECT durum INTO v_durum FROM turnuva WHERE turnuva_id = p_turnuva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Turnuva bulunamadı.';
    ELSIF v_durum <> 'Kayıt Açık' THEN
        RAISE EXCEPTION 'Fikstür yalnızca "Kayıt Açık" durumundaki turnuvalar için oluşturulabilir.';
    ELSIF EXISTS (SELECT 1 FROM mac WHERE turnuva_id = p_turnuva_id) THEN
        RAISE EXCEPTION 'Bu turnuvanın fikstürü zaten oluşturulmuş.';
    END IF;

    SELECT array_agg(takim_id ORDER BY katilim_id) INTO v_takimlar
      FROM turnuva_katilim WHERE turnuva_id = p_turnuva_id;

    IF COALESCE(array_length(v_takimlar, 1), 0) < 2 THEN
        RAISE EXCEPTION 'Fikstür için en az 2 takımın kayıtlı olması gerekir.';
    END IF;

    SELECT array_agg(kisi_id ORDER BY kisi_id) INTO v_hakemler FROM hakem;
    SELECT asama_id INTO v_asama_id FROM asama ORDER BY sira_no LIMIT 1;

    FOR i IN 1 .. array_length(v_takimlar, 1) - 1 LOOP
        FOR j IN i + 1 .. array_length(v_takimlar, 1) LOOP
            INSERT INTO mac (turnuva_id, asama_id, takim1_id, takim2_id, hakem_id, mac_zamani)
            VALUES (p_turnuva_id, v_asama_id, v_takimlar[i], v_takimlar[j],
                    CASE WHEN v_hakemler IS NULL THEN NULL
                         ELSE v_hakemler[(v_sayac % array_length(v_hakemler, 1)) + 1] END,
                    p_ilk_mac + v_sayac * p_aralik);
            v_sayac := v_sayac + 1;
        END LOOP;
    END LOOP;

    UPDATE turnuva SET durum = 'Devam Ediyor' WHERE turnuva_id = p_turnuva_id;
    RETURN v_sayac;
END;
$$;

-- ---------------------------------------------------------------------
-- 6) mac_sonucu_gir (SAKLI YORDAM): Maç skorunu kaydeder ve maçı
--    "Oynandı" yapar. Kazananın belirlenmesi ve puan tablosunun
--    güncellenmesi tetikleyiciler tarafından yapılır.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE mac_sonucu_gir(p_mac_id INT, p_skor1 SMALLINT, p_skor2 SMALLINT)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_skor1 = p_skor2 THEN
        RAISE EXCEPTION 'E-spor maçlarında beraberlik olamaz; skorlar farklı olmalıdır.';
    END IF;

    UPDATE mac
       SET takim1_skor = p_skor1, takim2_skor = p_skor2, durum = 'Oynandı'
     WHERE mac_id = p_mac_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Maç bulunamadı (no: %).', p_mac_id;
    END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- 7) puan_tablosu: Turnuvanın güncel sıralamasını döndürür.
--    Sıralama ölçütü: puan, skor farkı, galibiyet, takım adı.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION puan_tablosu(p_turnuva_id INT)
RETURNS TABLE (
    sira        INT,
    takim_id    INT,
    takim_adi   VARCHAR,
    oynanan     INT,
    galibiyet   SMALLINT,
    maglubiyet  SMALLINT,
    skor_farki  SMALLINT,
    puan        SMALLINT
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT (row_number() OVER (ORDER BY tk.puan DESC, tk.skor_farki DESC,
                                        tk.galibiyet DESC, t.takim_adi))::INT,
           t.takim_id,
           t.takim_adi,
           (tk.galibiyet + tk.maglubiyet)::INT,
           tk.galibiyet,
           tk.maglubiyet,
           tk.skor_farki,
           tk.puan
      FROM turnuva_katilim tk
      JOIN takim t ON t.takim_id = tk.takim_id
     WHERE tk.turnuva_id = p_turnuva_id
     ORDER BY 1;
END;
$$;

-- ---------------------------------------------------------------------
-- 8) oyuncu_istatistik: Bir oyuncunun tüm maçlarındaki toplam
--    istatistiklerini ve KDA oranını ((öldürme + asist) / ölüm) hesaplar.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION oyuncu_istatistik(p_oyuncu_id INT)
RETURNS TABLE (
    mac_sayisi      INT,
    toplam_oldurme  INT,
    toplam_olum     INT,
    toplam_asist    INT,
    kda             NUMERIC,
    mvp_sayisi      INT
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT count(*)::INT,
           COALESCE(sum(s.oldurme), 0)::INT,
           COALESCE(sum(s.olum), 0)::INT,
           COALESCE(sum(s.asist), 0)::INT,
           round(COALESCE(sum(s.oldurme + s.asist), 0)::NUMERIC
                 / GREATEST(COALESCE(sum(s.olum), 0), 1), 2),
           count(*) FILTER (WHERE s.mvp)::INT
      FROM oyuncu_mac_istatistik s
     WHERE s.oyuncu_id = p_oyuncu_id;
END;
$$;

-- ---------------------------------------------------------------------
-- 9) oyuncu_transfer (SAKLI YORDAM): Oyuncunun aktif kadro kaydını
--    bugünün tarihiyle kapatır ve (verilmişse) yeni takıma ekler.
--    p_yeni_takim_id NULL ise oyuncu serbest kalır.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE oyuncu_transfer(
    p_oyuncu_id      INT,
    p_yeni_takim_id  INT,
    p_rol            VARCHAR DEFAULT 'Oyuncu'
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM oyuncu WHERE kisi_id = p_oyuncu_id) THEN
        RAISE EXCEPTION 'Oyuncu bulunamadı.';
    END IF;

    IF EXISTS (SELECT 1 FROM takim_oyuncu
                WHERE oyuncu_id = p_oyuncu_id AND ayrilma_tarihi IS NULL
                  AND takim_id = p_yeni_takim_id) THEN
        RAISE EXCEPTION 'Oyuncu zaten bu takımın kadrosunda.';
    END IF;

    UPDATE takim_oyuncu
       SET ayrilma_tarihi = current_date, kaptan = FALSE
     WHERE oyuncu_id = p_oyuncu_id AND ayrilma_tarihi IS NULL;

    IF p_yeni_takim_id IS NOT NULL THEN
        INSERT INTO takim_oyuncu (takim_id, oyuncu_id, rol)
        VALUES (p_yeni_takim_id, p_oyuncu_id, COALESCE(NULLIF(p_rol, ''), 'Oyuncu'));
    END IF;
END;
$$;
