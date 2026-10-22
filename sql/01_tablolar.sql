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
