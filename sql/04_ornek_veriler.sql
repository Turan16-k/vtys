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
