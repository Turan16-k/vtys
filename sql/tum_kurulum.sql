-- =====================================================================
--  E-SPOR TURNUVA YÖNETİM SİSTEMİ
--  01 - TABLOLAR
--  Veritabanı: PostgreSQL   Yaklaşım: Database-First
-- =====================================================================

DROP TABLE IF EXISTS islem_log, odul, oyuncu_mac_istatistik, mac, asama,
    turnuva_katilim, salon_turnuva, online_turnuva, turnuva, mekan,
    takim_sponsor, sponsor, takim_oyuncu, takim, hakem, koc, oyuncu, kisi,
    oyun, oyun_turu, ulke
    CASCADE;

-- ---------------------------------------------------------------------
--  TANIM TABLOLARI
-- ---------------------------------------------------------------------
CREATE TABLE ulke (
    ulke_id     SERIAL       PRIMARY KEY,
    ulke_adi    VARCHAR(50)  NOT NULL UNIQUE,
    ulke_kodu   CHAR(2)      NOT NULL UNIQUE
);

CREATE TABLE oyun_turu (
    tur_id      SERIAL       PRIMARY KEY,
    tur_adi     VARCHAR(40)  NOT NULL UNIQUE
);

CREATE TABLE oyun (
    oyun_id       SERIAL       PRIMARY KEY,
    oyun_adi      VARCHAR(60)  NOT NULL UNIQUE,
    tur_id        INT          NOT NULL REFERENCES oyun_turu(tur_id),
    yayinci       VARCHAR(60)  NOT NULL,
    takim_boyutu  SMALLINT     NOT NULL CHECK (takim_boyutu BETWEEN 1 AND 10)  -- sahadaki oyuncu sayısı
);

-- ---------------------------------------------------------------------
--  KİŞİ  (KALITIM: kisi  ->  oyuncu | koc | hakem)
--  Ayrık (disjoint) ve tam (total) genelleme; ayırt edici nitelik: kisi_turu
-- ---------------------------------------------------------------------
CREATE TABLE kisi (
    kisi_id        SERIAL        PRIMARY KEY,
    ad             VARCHAR(40)   NOT NULL,
    soyad          VARCHAR(40)   NOT NULL,
    eposta         VARCHAR(100)  NOT NULL UNIQUE CHECK (eposta LIKE '%_@_%._%'),
    dogum_tarihi   DATE          NOT NULL,
    ulke_id        INT           NOT NULL REFERENCES ulke(ulke_id),
    kisi_turu      CHAR(1)       NOT NULL CHECK (kisi_turu IN ('O', 'K', 'H')),  -- O: oyuncu, K: koç, H: hakem
    kayit_tarihi   TIMESTAMP     NOT NULL DEFAULT now()
);

CREATE TABLE oyuncu (
    kisi_id      INT          PRIMARY KEY REFERENCES kisi(kisi_id) ON DELETE CASCADE,
    takma_ad     VARCHAR(30)  NOT NULL UNIQUE,
    elo_puani    INT          NOT NULL DEFAULT 1000 CHECK (elo_puani >= 0)
);

CREATE TABLE koc (
    kisi_id       INT       PRIMARY KEY REFERENCES kisi(kisi_id) ON DELETE CASCADE,
    deneyim_yili  SMALLINT  NOT NULL DEFAULT 0 CHECK (deneyim_yili >= 0)
);

CREATE TABLE hakem (
    kisi_id    INT          PRIMARY KEY REFERENCES kisi(kisi_id) ON DELETE CASCADE,
    lisans_no  VARCHAR(20)  NOT NULL UNIQUE,
    seviye     VARCHAR(15)  NOT NULL CHECK (seviye IN ('Ulusal', 'Uluslararası'))
);

-- ---------------------------------------------------------------------
--  TAKIM, KADRO, SPONSOR
-- ---------------------------------------------------------------------
CREATE TABLE takim (
    takim_id        SERIAL       PRIMARY KEY,
    takim_adi       VARCHAR(60)  NOT NULL UNIQUE,
    kisa_ad         VARCHAR(5)   NOT NULL UNIQUE,
    oyun_id         INT          NOT NULL REFERENCES oyun(oyun_id),
    ulke_id         INT          NOT NULL REFERENCES ulke(ulke_id),
    koc_id          INT          UNIQUE REFERENCES koc(kisi_id) ON DELETE SET NULL,  -- bir koç tek takımı çalıştırır
    kurulus_tarihi  DATE         NOT NULL DEFAULT current_date
);

CREATE TABLE takim_oyuncu (
    kadro_id        SERIAL       PRIMARY KEY,
    takim_id        INT          NOT NULL REFERENCES takim(takim_id) ON DELETE CASCADE,
    oyuncu_id       INT          NOT NULL REFERENCES oyuncu(kisi_id) ON DELETE CASCADE,
    rol             VARCHAR(20)  NOT NULL DEFAULT 'Oyuncu',
    kaptan          BOOLEAN      NOT NULL DEFAULT FALSE,
    katilma_tarihi  DATE         NOT NULL DEFAULT current_date,
    ayrilma_tarihi  DATE,
    CONSTRAINT ck_kadro_tarih CHECK (ayrilma_tarihi IS NULL OR ayrilma_tarihi >= katilma_tarihi)
);
-- Bir oyuncu aynı anda yalnızca bir takımın aktif kadrosunda bulunabilir
CREATE UNIQUE INDEX uq_aktif_kadro ON takim_oyuncu (oyuncu_id) WHERE ayrilma_tarihi IS NULL;

CREATE TABLE sponsor (
    sponsor_id   SERIAL       PRIMARY KEY,
    sponsor_adi  VARCHAR(60)  NOT NULL UNIQUE,
    sektor       VARCHAR(40)  NOT NULL
);

CREATE TABLE takim_sponsor (
    takim_id      INT            NOT NULL REFERENCES takim(takim_id) ON DELETE CASCADE,
    sponsor_id    INT            NOT NULL REFERENCES sponsor(sponsor_id) ON DELETE CASCADE,
    baslangic     DATE           NOT NULL,
    bitis         DATE           NOT NULL,
    yillik_tutar  NUMERIC(12,2)  NOT NULL CHECK (yillik_tutar > 0),
    PRIMARY KEY (takim_id, sponsor_id),
    CONSTRAINT ck_sponsor_tarih CHECK (bitis > baslangic)
);

-- ---------------------------------------------------------------------
--  TURNUVA  (KALITIM: turnuva  ->  online_turnuva | salon_turnuva)
--  Ayrık ve tam genelleme; ayırt edici nitelik: turnuva_turu
-- ---------------------------------------------------------------------
CREATE TABLE mekan (
    mekan_id    SERIAL        PRIMARY KEY,
    mekan_adi   VARCHAR(80)   NOT NULL UNIQUE,
    ulke_id     INT           NOT NULL REFERENCES ulke(ulke_id),
    sehir       VARCHAR(50)   NOT NULL,
    adres       VARCHAR(200)  NOT NULL,
    kapasite    INT           NOT NULL CHECK (kapasite > 0)
);

CREATE TABLE turnuva (
    turnuva_id        SERIAL         PRIMARY KEY,
    turnuva_adi       VARCHAR(80)    NOT NULL UNIQUE,
    oyun_id           INT            NOT NULL REFERENCES oyun(oyun_id),
    baslangic_tarihi  DATE           NOT NULL,
    bitis_tarihi      DATE           NOT NULL,
    odul_havuzu       NUMERIC(12,2)  NOT NULL DEFAULT 0 CHECK (odul_havuzu >= 0),
    max_takim         SMALLINT       NOT NULL CHECK (max_takim BETWEEN 2 AND 64),
    durum             VARCHAR(15)    NOT NULL DEFAULT 'Kayıt Açık'
                                     CHECK (durum IN ('Kayıt Açık', 'Devam Ediyor', 'Tamamlandı')),
    turnuva_turu      CHAR(1)        NOT NULL CHECK (turnuva_turu IN ('O', 'S')),  -- O: online, S: salon
    CONSTRAINT ck_turnuva_tarih CHECK (bitis_tarihi >= baslangic_tarihi)
);

CREATE TABLE online_turnuva (
    turnuva_id      INT          PRIMARY KEY REFERENCES turnuva(turnuva_id) ON DELETE CASCADE,
    yayin_platformu VARCHAR(30)  NOT NULL,
    sunucu_bolgesi  VARCHAR(30)  NOT NULL
);

CREATE TABLE salon_turnuva (
    turnuva_id   INT           PRIMARY KEY REFERENCES turnuva(turnuva_id) ON DELETE CASCADE,
    mekan_id     INT           NOT NULL REFERENCES mekan(mekan_id),
    bilet_fiyati NUMERIC(8,2)  NOT NULL DEFAULT 0 CHECK (bilet_fiyati >= 0)
);

-- ---------------------------------------------------------------------
--  KATILIM (aynı zamanda puan tablosu), AŞAMA, MAÇ, İSTATİSTİK, ÖDÜL
-- ---------------------------------------------------------------------
CREATE TABLE turnuva_katilim (
    katilim_id    SERIAL     PRIMARY KEY,
    turnuva_id    INT        NOT NULL REFERENCES turnuva(turnuva_id) ON DELETE CASCADE,
    takim_id      INT        NOT NULL REFERENCES takim(takim_id) ON DELETE CASCADE,
    kayit_tarihi  TIMESTAMP  NOT NULL DEFAULT now(),
    galibiyet     SMALLINT   NOT NULL DEFAULT 0,
    maglubiyet    SMALLINT   NOT NULL DEFAULT 0,
    skor_farki    SMALLINT   NOT NULL DEFAULT 0,
    puan          SMALLINT   NOT NULL DEFAULT 0,
    sira          SMALLINT,                       -- turnuva bitince tetikleyici ile atanır
    CONSTRAINT uq_katilim UNIQUE (turnuva_id, takim_id)
);

CREATE TABLE asama (
    asama_id   SERIAL       PRIMARY KEY,
    asama_adi  VARCHAR(30)  NOT NULL UNIQUE,
    sira_no    SMALLINT     NOT NULL UNIQUE
);

CREATE TABLE mac (
    mac_id       SERIAL       PRIMARY KEY,
    turnuva_id   INT          NOT NULL REFERENCES turnuva(turnuva_id) ON DELETE CASCADE,
    asama_id     INT          NOT NULL REFERENCES asama(asama_id),
    takim1_id    INT          NOT NULL REFERENCES takim(takim_id),
    takim2_id    INT          NOT NULL REFERENCES takim(takim_id),
    hakem_id     INT          REFERENCES hakem(kisi_id) ON DELETE SET NULL,
    mac_zamani   TIMESTAMP    NOT NULL,
    takim1_skor  SMALLINT     CHECK (takim1_skor >= 0),
    takim2_skor  SMALLINT     CHECK (takim2_skor >= 0),
    kazanan_id   INT          REFERENCES takim(takim_id),   -- tetikleyici ile atanır
    durum        VARCHAR(10)  NOT NULL DEFAULT 'Planlandı'
                              CHECK (durum IN ('Planlandı', 'Oynandı', 'İptal')),
    CONSTRAINT ck_farkli_takim CHECK (takim1_id <> takim2_id),
    -- e-sporda beraberlik yoktur: oynanmış maçın skorları farklı olmalıdır
    CONSTRAINT ck_mac_skor CHECK (durum <> 'Oynandı'
        OR (takim1_skor IS NOT NULL AND takim2_skor IS NOT NULL AND takim1_skor <> takim2_skor))
);

CREATE TABLE oyuncu_mac_istatistik (
    istatistik_id  SERIAL    PRIMARY KEY,
    mac_id         INT       NOT NULL REFERENCES mac(mac_id) ON DELETE CASCADE,
    oyuncu_id      INT       NOT NULL REFERENCES oyuncu(kisi_id) ON DELETE CASCADE,
    takim_id       INT       NOT NULL REFERENCES takim(takim_id) ON DELETE CASCADE,  -- tetikleyici ile atanır
    oldurme        SMALLINT  NOT NULL DEFAULT 0 CHECK (oldurme >= 0),
    olum           SMALLINT  NOT NULL DEFAULT 0 CHECK (olum >= 0),
    asist          SMALLINT  NOT NULL DEFAULT 0 CHECK (asist >= 0),
    mvp            BOOLEAN   NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_istatistik UNIQUE (mac_id, oyuncu_id)
);

CREATE TABLE odul (
    odul_id     SERIAL         PRIMARY KEY,
    turnuva_id  INT            NOT NULL REFERENCES turnuva(turnuva_id) ON DELETE CASCADE,
    derece      SMALLINT       NOT NULL CHECK (derece > 0),
    tutar       NUMERIC(12,2)  NOT NULL CHECK (tutar > 0),
    takim_id    INT            REFERENCES takim(takim_id) ON DELETE SET NULL,  -- turnuva bitince atanır
    CONSTRAINT uq_odul UNIQUE (turnuva_id, derece)
);

-- ---------------------------------------------------------------------
--  DENETİM KAYITLARI
-- ---------------------------------------------------------------------
CREATE TABLE islem_log (
    log_id         SERIAL       PRIMARY KEY,
    tablo_adi      VARCHAR(30)  NOT NULL,
    islem_turu     VARCHAR(10)  NOT NULL,
    kayit_bilgisi  TEXT,
    kullanici      VARCHAR(50)  NOT NULL DEFAULT current_user,
    islem_zamani   TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE INDEX ix_mac_turnuva        ON mac (turnuva_id);
CREATE INDEX ix_istatistik_oyuncu  ON oyuncu_mac_istatistik (oyuncu_id);
CREATE INDEX ix_kadro_takim        ON takim_oyuncu (takim_id);


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


-- =====================================================================
--  E-SPOR TURNUVA YÖNETİM SİSTEMİ
--  04 - ÖRNEK VERİLER
--  (01, 02 ve 03 numaralı dosyalar çalıştırıldıktan sonra çalıştırılır.)
-- =====================================================================

-- ---------------------------------------------------------------------
--  Tanım verileri
-- ---------------------------------------------------------------------
INSERT INTO ulke (ulke_adi, ulke_kodu) VALUES
    ('Türkiye', 'TR'), ('Almanya', 'DE'), ('Fransa', 'FR'), ('İsveç', 'SE'),
    ('Güney Kore', 'KR'), ('Danimarka', 'DK'), ('Brezilya', 'BR'), ('Ukrayna', 'UA');

INSERT INTO oyun_turu (tur_adi) VALUES
    ('Taktiksel Nişancı'), ('MOBA'), ('Araç Sporu'), ('Dövüş');

INSERT INTO oyun (oyun_adi, tur_id, yayinci, takim_boyutu) VALUES
    ('Valorant',           1, 'Riot Games',   5),
    ('Counter-Strike 2',   1, 'Valve',        5),
    ('League of Legends',  2, 'Riot Games',   5),
    ('Rocket League',      3, 'Psyonix',      3),
    ('Tekken 8',           4, 'Bandai Namco', 1);

INSERT INTO asama (asama_adi, sira_no) VALUES
    ('Grup Aşaması', 1), ('Çeyrek Final', 2), ('Yarı Final', 3), ('Final', 4);

INSERT INTO sponsor (sponsor_adi, sektor) VALUES
    ('Kuzgun Donanım',  'Bilgisayar Donanımı'),
    ('HızNet Fiber',    'Telekomünikasyon'),
    ('Enerjix',         'İçecek'),
    ('NovaChair',       'Mobilya'),
    ('Atlas Sigorta',   'Sigorta'),
    ('Pixel Kafe',      'Yiyecek');

INSERT INTO mekan (mekan_adi, ulke_id, sehir, adres, kapasite) VALUES
    ('Haliç E-spor Arenası',          1, 'İstanbul', 'Haliç Kongre Merkezi Yanı, Beyoğlu',   2500),
    ('Ankara Dijital Salon',          1, 'Ankara',   'Eskişehir Yolu No: 120, Çankaya',      1200),
    ('İzmir Kordon Gösteri Merkezi',  1, 'İzmir',    'Atatürk Caddesi No: 45, Konak',        1800);

-- ---------------------------------------------------------------------
--  KİŞİLER (üst tip)   1-6: koç,  7-10: hakem,  11-57: oyuncu
-- ---------------------------------------------------------------------
INSERT INTO kisi (kisi_id, ad, soyad, eposta, dogum_tarihi, ulke_id, kisi_turu) VALUES
    ( 1, 'Murat',     'Ersoy',      'murat.ersoy@ornek.com',      '1985-04-12', 1, 'K'),
    ( 2, 'Selim',     'Karaca',     'selim.karaca@ornek.com',     '1988-09-03', 1, 'K'),
    ( 3, 'Gökhan',    'Tekin',      'gokhan.tekin@ornek.com',     '1990-01-27', 1, 'K'),
    ( 4, 'Anders',    'Svensson',   'anders.svensson@ornek.com',  '1983-06-15', 4, 'K'),
    ( 5, 'Stefan',    'Krüger',     'stefan.kruger@ornek.com',    '1986-11-02', 2, 'K'),
    ( 6, 'Jae-won',   'Han',        'jaewon.han@ornek.com',       '1984-03-19', 5, 'K'),

    ( 7, 'Ayşe',      'Demirtaş',   'ayse.demirtas@ornek.com',    '1987-02-08', 1, 'H'),
    ( 8, 'Kemal',     'Uçar',       'kemal.ucar@ornek.com',       '1991-07-30', 1, 'H'),
    ( 9, 'Sofia',     'Andersson',  'sofia.andersson@ornek.com',  '1989-12-11', 4, 'H'),
    (10, 'Pierre',    'Laurent',    'pierre.laurent@ornek.com',   '1982-05-24', 3, 'H'),

    -- Anadolu Kartalları (Valorant)
    (11, 'Emre',      'Yıldız',     'emre.yildiz@ornek.com',      '2001-03-14', 1, 'O'),
    (12, 'Burak',     'Aydın',      'burak.aydin@ornek.com',      '2002-07-22', 1, 'O'),
    (13, 'Mert',      'Kaya',       'mert.kaya@ornek.com',        '2000-11-05', 1, 'O'),
    (14, 'Ozan',      'Çelik',      'ozan.celik@ornek.com',       '2003-01-30', 1, 'O'),
    (15, 'Kaan',      'Demir',      'kaan.demir@ornek.com',       '2001-09-18', 1, 'O'),
    -- Boğaziçi Kurtları (Valorant)
    (16, 'Can',       'Öztürk',     'can.ozturk@ornek.com',       '2000-02-11', 1, 'O'),
    (17, 'Efe',       'Arslan',     'efe.arslan@ornek.com',       '2002-12-03', 1, 'O'),
    (18, 'Yusuf',     'Koç',        'yusuf.koc@ornek.com',        '2001-06-27', 1, 'O'),
    (19, 'Deniz',     'Kurt',       'deniz.kurt@ornek.com',       '2003-04-15', 1, 'O'),
    (20, 'Barış',     'Aksoy',      'baris.aksoy@ornek.com',      '2002-08-08', 1, 'O'),
    -- Kapadokya Ejderleri (Valorant)
    (21, 'Furkan',    'Yılmaz',     'furkan.yilmaz@ornek.com',    '2001-10-10', 1, 'O'),
    (22, 'Serkan',    'Doğan',      'serkan.dogan@ornek.com',     '2000-05-25', 1, 'O'),
    (23, 'Tolga',     'Erdem',      'tolga.erdem@ornek.com',      '1999-12-01', 1, 'O'),
    (24, 'Hakan',     'Güneş',      'hakan.gunes@ornek.com',      '2002-03-03', 1, 'O'),
    (25, 'Cem',       'Özdemir',    'cem.ozdemir@ornek.com',      '2003-09-09', 1, 'O'),
    -- Nordic Frost (Valorant)
    (26, 'Erik',      'Lindqvist',  'erik.lindqvist@ornek.com',   '2000-01-17', 4, 'O'),
    (27, 'Oskar',     'Nilsson',    'oskar.nilsson@ornek.com',    '2001-04-04', 4, 'O'),
    (28, 'Lukas',     'Berg',       'lukas.berg@ornek.com',       '1999-08-19', 4, 'O'),
    (29, 'Viktor',    'Holm',       'viktor.holm@ornek.com',      '2002-11-11', 4, 'O'),
    (30, 'Axel',      'Strand',     'axel.strand@ornek.com',      '2003-02-28', 4, 'O'),
    -- Berlin Phantoms (Valorant)
    (31, 'Jonas',     'Becker',     'jonas.becker@ornek.com',     '2000-06-06', 2, 'O'),
    (32, 'Felix',     'Wagner',     'felix.wagner@ornek.com',     '2001-12-12', 2, 'O'),
    (33, 'Leon',      'Schulz',     'leon.schulz@ornek.com',      '2002-09-29', 2, 'O'),
    (34, 'Maximilian','Hoffmann',   'max.hoffmann@ornek.com',     '1999-03-21', 2, 'O'),
    (35, 'Paul',      'Richter',    'paul.richter@ornek.com',     '2003-07-07', 2, 'O'),
    -- Seoul Tigers (Valorant)
    (36, 'Min-jun',   'Kim',        'minjun.kim@ornek.com',       '2001-05-05', 5, 'O'),
    (37, 'Ji-ho',     'Park',       'jiho.park@ornek.com',        '2002-02-14', 5, 'O'),
    (38, 'Seo-jun',   'Lee',        'seojun.lee@ornek.com',       '2000-10-20', 5, 'O'),
    (39, 'Do-yun',    'Choi',       'doyun.choi@ornek.com',       '2003-08-31', 5, 'O'),
    (40, 'Ha-jun',    'Jung',       'hajun.jung@ornek.com',       '2002-06-16', 5, 'O'),
    -- Yedek oyuncular
    (41, 'Arda',      'Şahin',      'arda.sahin@ornek.com',       '2004-05-09', 1, 'O'),
    (42, 'Onur',      'Polat',      'onur.polat@ornek.com',       '2005-01-21', 1, 'O'),
    -- Turbo Turkuaz (Rocket League)
    (43, 'Alp',       'Turan',      'alp.turan@ornek.com',        '2002-04-12', 1, 'O'),
    (44, 'Sinan',     'Bulut',      'sinan.bulut@ornek.com',      '2003-06-02', 1, 'O'),
    (45, 'Eren',      'Yavuz',      'eren.yavuz@ornek.com',       '2004-02-19', 1, 'O'),
    -- Ege Rüzgarı (Rocket League)
    (46, 'Umut',      'Keskin',     'umut.keskin@ornek.com',      '2001-08-23', 1, 'O'),
    (47, 'Batuhan',   'Sarı',       'batuhan.sari@ornek.com',     '2003-11-30', 1, 'O'),
    (48, 'Mustafa',   'Ateş',       'mustafa.ates@ornek.com',     '2002-01-08', 1, 'O'),
    -- Paris Boost (Rocket League)
    (49, 'Hugo',      'Martin',     'hugo.martin@ornek.com',      '2001-09-14', 3, 'O'),
    (50, 'Louis',     'Bernard',    'louis.bernard@ornek.com',    '2002-05-27', 3, 'O'),
    (51, 'Théo',      'Dubois',     'theo.dubois@ornek.com',      '2003-03-16', 3, 'O'),
    -- Copenhagen Wings (Rocket League)
    (52, 'Mikkel',    'Jensen',     'mikkel.jensen@ornek.com',    '2000-12-24', 6, 'O'),
    (53, 'Frederik',  'Nielsen',    'frederik.nielsen@ornek.com', '2002-10-05', 6, 'O'),
    (54, 'Rasmus',    'Hansen',     'rasmus.hansen@ornek.com',    '2003-07-19', 6, 'O'),
    -- Serbest oyuncular
    (55, 'Selin',     'Aydemir',    'selin.aydemir@ornek.com',    '2004-09-12', 1, 'O'),
    (56, 'Zeynep',    'Kılıç',      'zeynep.kilic@ornek.com',     '2005-03-08', 1, 'O'),
    (57, 'Lars',      'Eriksson',   'lars.eriksson@ornek.com',    '2001-11-25', 4, 'O');

SELECT setval('kisi_kisi_id_seq', (SELECT max(kisi_id) FROM kisi));

-- ---------------------------------------------------------------------
--  ALT TİPLER: koç, hakem, oyuncu
-- ---------------------------------------------------------------------
INSERT INTO koc (kisi_id, deneyim_yili) VALUES
    (1, 8), (2, 6), (3, 5), (4, 10), (5, 7), (6, 9);

INSERT INTO hakem (kisi_id, lisans_no, seviye) VALUES
    (7,  'TR-H-1001', 'Uluslararası'),
    (8,  'TR-H-1002', 'Ulusal'),
    (9,  'SE-H-2201', 'Uluslararası'),
    (10, 'FR-H-3105', 'Uluslararası');

INSERT INTO oyuncu (kisi_id, takma_ad, elo_puani) VALUES
    (11, 'Kartal', 2150), (12, 'Sis', 2080), (13, 'Kalkan', 2010), (14, 'Radar', 1990), (15, 'Volt', 1970),
    (16, 'Bozkurt', 2120), (17, 'Duman', 2040), (18, 'Tuzak', 1995), (19, 'Pusula', 1960), (20, 'Kıvılcım', 1940),
    (21, 'Ejder', 2060), (22, 'Bulut', 1980), (23, 'Kale', 1950), (24, 'Şimşek', 1930), (25, 'Fırtına', 1900),
    (26, 'Frostbite', 2140), (27, 'Aurora', 2070), (28, 'Glacier', 2020), (29, 'Tundra', 1985), (30, 'Polar', 1955),
    (31, 'Phantom', 2090), (32, 'Specter', 2030), (33, 'Wraith', 1975), (34, 'Haze', 1945), (35, 'Ember', 1915),
    (36, 'Tiger', 2180), (37, 'Lotus', 2100), (38, 'Haneul', 2050), (39, 'Byeol', 2000), (40, 'Raon', 1965),
    (41, 'Gölge', 1850), (42, 'Yankı', 1820),
    (43, 'Nitro', 1720), (44, 'Drift', 1680), (45, 'Roket', 1650),
    (46, 'Meltem', 1700), (47, 'Dalga', 1660), (48, 'Poyraz', 1640),
    (49, 'Boost', 1750), (50, 'Flip', 1710), (51, 'Aerial', 1690),
    (52, 'Wingman', 1730), (53, 'Kickoff', 1700), (54, 'Dribble', 1670),
    (55, 'Valkür', 1880), (56, 'Nova', 1790), (57, 'Viking', 1760);

-- ---------------------------------------------------------------------
--  TAKIMLAR
-- ---------------------------------------------------------------------
INSERT INTO takim (takim_id, takim_adi, kisa_ad, oyun_id, ulke_id, koc_id, kurulus_tarihi) VALUES
    ( 1, 'Anadolu Kartalları',   'AKR', 1, 1, 1,    '2021-03-01'),
    ( 2, 'Boğaziçi Kurtları',    'BGK', 1, 1, 2,    '2020-09-15'),
    ( 3, 'Kapadokya Ejderleri',  'KPE', 1, 1, 3,    '2022-01-20'),
    ( 4, 'Nordic Frost',         'NFR', 1, 4, 4,    '2019-06-10'),
    ( 5, 'Berlin Phantoms',      'BPH', 1, 2, 5,    '2020-02-02'),
    ( 6, 'Seoul Tigers',         'STG', 1, 5, 6,    '2018-11-11'),
    ( 7, 'Turbo Turkuaz',        'TRB', 4, 1, NULL, '2023-04-04'),
    ( 8, 'Ege Rüzgarı',          'EGR', 4, 1, NULL, '2022-08-17'),
    ( 9, 'Paris Boost',          'PBO', 4, 3, NULL, '2021-05-05'),
    (10, 'Copenhagen Wings',     'CPW', 4, 6, NULL, '2022-12-01');

SELECT setval('takim_takim_id_seq', (SELECT max(takim_id) FROM takim));

-- ---------------------------------------------------------------------
--  KADROLAR (geçmiş kayıtlar dahil)
-- ---------------------------------------------------------------------
-- Geçmiş (sona ermiş) kadro kayıtları
INSERT INTO takim_oyuncu (takim_id, oyuncu_id, rol, kaptan, katilma_tarihi, ayrilma_tarihi) VALUES
    (4, 57, 'Düellocu', FALSE, '2023-01-10', '2025-12-31'),
    (3, 41, 'Nöbetçi',  FALSE, '2024-02-01', '2025-06-30');

-- Aktif kadrolar
INSERT INTO takim_oyuncu (takim_id, oyuncu_id, rol, kaptan, katilma_tarihi) VALUES
    (1, 11, 'Düellocu',   TRUE,  '2024-01-15'), (1, 12, 'Kontrolcü', FALSE, '2024-01-15'),
    (1, 13, 'Nöbetçi',    FALSE, '2024-06-01'), (1, 14, 'Öncü',      FALSE, '2025-01-10'),
    (1, 15, 'Esnek',      FALSE, '2025-01-10'), (1, 41, 'Yedek',     FALSE, '2025-07-15'),

    (2, 16, 'Düellocu',   TRUE,  '2023-09-01'), (2, 17, 'Kontrolcü', FALSE, '2023-09-01'),
    (2, 18, 'Nöbetçi',    FALSE, '2024-03-12'), (2, 19, 'Öncü',      FALSE, '2024-03-12'),
    (2, 20, 'Esnek',      FALSE, '2025-02-20'), (2, 42, 'Yedek',     FALSE, '2026-01-05'),

    (3, 21, 'Düellocu',   TRUE,  '2024-02-01'), (3, 22, 'Kontrolcü', FALSE, '2024-02-01'),
    (3, 23, 'Nöbetçi',    FALSE, '2025-07-01'), (3, 24, 'Öncü',      FALSE, '2024-02-01'),
    (3, 25, 'Esnek',      FALSE, '2025-03-15'),

    (4, 26, 'Düellocu',   TRUE,  '2023-01-10'), (4, 27, 'Kontrolcü', FALSE, '2023-01-10'),
    (4, 28, 'Nöbetçi',    FALSE, '2023-01-10'), (4, 29, 'Öncü',      FALSE, '2024-05-05'),
    (4, 30, 'Esnek',      FALSE, '2026-01-02'),

    (5, 31, 'Düellocu',   TRUE,  '2023-03-03'), (5, 32, 'Kontrolcü', FALSE, '2023-03-03'),
    (5, 33, 'Nöbetçi',    FALSE, '2024-08-08'), (5, 34, 'Öncü',      FALSE, '2023-03-03'),
    (5, 35, 'Esnek',      FALSE, '2025-04-01'),

    (6, 36, 'Düellocu',   TRUE,  '2022-12-01'), (6, 37, 'Kontrolcü', FALSE, '2022-12-01'),
    (6, 38, 'Nöbetçi',    FALSE, '2023-06-15'), (6, 39, 'Öncü',      FALSE, '2024-01-20'),
    (6, 40, 'Esnek',      FALSE, '2024-01-20'),

    (7, 43, 'Hücum',      TRUE,  '2023-04-04'), (7, 44, 'Orta Saha', FALSE, '2023-04-04'),
    (7, 45, 'Defans',     FALSE, '2024-09-01'),
    (8, 46, 'Hücum',      TRUE,  '2022-08-17'), (8, 47, 'Orta Saha', FALSE, '2023-02-01'),
    (8, 48, 'Defans',     FALSE, '2023-02-01'),
    (9, 49, 'Hücum',      TRUE,  '2021-05-05'), (9, 50, 'Orta Saha', FALSE, '2022-01-01'),
    (9, 51, 'Defans',     FALSE, '2023-06-01'),
    (10, 52, 'Hücum',     TRUE,  '2022-12-01'), (10, 53, 'Orta Saha', FALSE, '2022-12-01'),
    (10, 54, 'Defans',    FALSE, '2024-03-03');

-- ---------------------------------------------------------------------
--  SPONSORLUKLAR
-- ---------------------------------------------------------------------
INSERT INTO takim_sponsor (takim_id, sponsor_id, baslangic, bitis, yillik_tutar) VALUES
    (1, 1, '2025-01-01', '2027-12-31', 1200000),
    (1, 3, '2026-01-01', '2026-12-31',  450000),
    (2, 2, '2024-06-01', '2026-12-31',  900000),
    (3, 6, '2025-03-01', '2027-02-28',  300000),
    (4, 4, '2024-01-01', '2026-12-31',  650000),
    (6, 1, '2025-06-01', '2027-05-31',  800000),
    (7, 5, '2025-09-01', '2026-08-31',  150000),
    (8, 3, '2026-02-01', '2027-01-31',  120000);

-- ---------------------------------------------------------------------
--  TURNUVALAR (kalıtım: turnuva_olustur fonksiyonu ile alt tiplere ekleme)
-- ---------------------------------------------------------------------
SELECT turnuva_olustur('Anadolu Valorant Kupası 2026', 1, '2026-09-05', '2026-09-10', 250000, 4::SMALLINT,
                       'O', 'Twitch', 'Avrupa (İstanbul)');
SELECT turnuva_olustur('İstanbul Valorant Masters', 1, '2026-10-15', '2026-10-30', 500000, 6::SMALLINT,
                       'S', NULL, NULL, 1, 350);
SELECT turnuva_olustur('Rocket League Kış Ligi', 4, '2026-11-10', '2026-11-30', 60000, 8::SMALLINT,
                       'O', 'YouTube', 'Avrupa (Frankfurt)');
SELECT turnuva_olustur('Ankara CS2 Bahar Turnuvası', 2, '2027-03-20', '2027-03-22', 150000, 8::SMALLINT,
                       'S', NULL, NULL, 2, 200);

-- Ödüller
INSERT INTO odul (turnuva_id, derece, tutar) VALUES
    (1, 1, 125000), (1, 2, 75000),  (1, 3, 50000),
    (2, 1, 250000), (2, 2, 150000), (2, 3, 100000),
    (3, 1, 35000),  (3, 2, 25000),
    (4, 1, 90000),  (4, 2, 60000);

-- Turnuva kayıtları (tetikleyici: oyun, kontenjan ve kadro kontrolü)
INSERT INTO turnuva_katilim (turnuva_id, takim_id, kayit_tarihi) VALUES
    (1, 1, '2026-08-01'), (1, 2, '2026-08-02'), (1, 3, '2026-08-03'), (1, 4, '2026-08-05'),
    (2, 1, '2026-09-20'), (2, 2, '2026-09-21'), (2, 3, '2026-09-21'),
    (2, 4, '2026-09-25'), (2, 5, '2026-09-26'), (2, 6, '2026-09-28'),
    (3, 7, '2026-10-01'), (3, 8, '2026-10-03'), (3, 9, '2026-10-10');

-- ---------------------------------------------------------------------
--  1. TURNUVA: fikstür, sonuçlar, tamamlama (ödüller tetikleyici ile dağıtılır)
-- ---------------------------------------------------------------------
SELECT fikstur_olustur(1, '2026-09-05 18:00', '1 day');

CALL mac_sonucu_gir(1, 2::SMALLINT, 0::SMALLINT);   -- AKR - BGK
CALL mac_sonucu_gir(2, 2::SMALLINT, 0::SMALLINT);   -- AKR - KPE
CALL mac_sonucu_gir(3, 1::SMALLINT, 2::SMALLINT);   -- AKR - NFR
CALL mac_sonucu_gir(4, 2::SMALLINT, 1::SMALLINT);   -- BGK - KPE
CALL mac_sonucu_gir(5, 0::SMALLINT, 2::SMALLINT);   -- BGK - NFR
CALL mac_sonucu_gir(6, 2::SMALLINT, 1::SMALLINT);   -- KPE - NFR

-- ---------------------------------------------------------------------
--  2. TURNUVA: fikstür ve oynanmış ilk maçlar (turnuva devam ediyor)
-- ---------------------------------------------------------------------
SELECT fikstur_olustur(2, '2026-10-15 13:00', '1 day');

CALL mac_sonucu_gir(7,  2::SMALLINT, 1::SMALLINT);  -- AKR - BGK
CALL mac_sonucu_gir(8,  0::SMALLINT, 2::SMALLINT);  -- AKR - KPE
CALL mac_sonucu_gir(9,  2::SMALLINT, 0::SMALLINT);  -- AKR - NFR
CALL mac_sonucu_gir(10, 2::SMALLINT, 1::SMALLINT);  -- AKR - BPH
CALL mac_sonucu_gir(11, 1::SMALLINT, 2::SMALLINT);  -- AKR - STG
CALL mac_sonucu_gir(12, 2::SMALLINT, 0::SMALLINT);  -- BGK - KPE

-- ---------------------------------------------------------------------
--  OYUNCU MAÇ İSTATİSTİKLERİ (oynanmış maçlarda sahadaki oyuncular için)
--  Değerler örnek olsun diye oyuncu ve maç numarasından türetilmiştir.
-- ---------------------------------------------------------------------
INSERT INTO oyuncu_mac_istatistik (mac_id, oyuncu_id, takim_id, oldurme, olum, asist)
SELECT m.mac_id,
       ko.oyuncu_id,
       ko.takim_id,
       10 + (ko.oyuncu_id * 7 + m.mac_id * 13) % 20 + CASE WHEN ko.takim_id = m.kazanan_id THEN 6 ELSE 0 END,
       12 + (ko.oyuncu_id * 11 + m.mac_id * 5) % 14 - CASE WHEN ko.takim_id = m.kazanan_id THEN 3 ELSE 0 END,
       3  + (ko.oyuncu_id * 3 + m.mac_id * 17) % 12
  FROM mac m
  JOIN takim_oyuncu ko
    ON ko.takim_id IN (m.takim1_id, m.takim2_id)
   AND ko.ayrilma_tarihi IS NULL
   AND ko.rol <> 'Yedek'
 WHERE m.durum = 'Oynandı';

-- Her maçın MVP'si: kazanan takımda en çok öldürme yapan oyuncu
UPDATE oyuncu_mac_istatistik s
   SET mvp = TRUE
 WHERE s.istatistik_id IN (
       SELECT DISTINCT ON (s2.mac_id) s2.istatistik_id
         FROM oyuncu_mac_istatistik s2
         JOIN mac m ON m.mac_id = s2.mac_id AND m.kazanan_id = s2.takim_id
        ORDER BY s2.mac_id, s2.oldurme DESC, s2.asist DESC);

-- 1. turnuvayı tamamla: sıralama ve ödül dağıtımı tetikleyici ile yapılır
UPDATE turnuva SET durum = 'Tamamlandı' WHERE turnuva_id = 1;
