"""Rapor.pdf üretici.

Kullanım:
    1) Aşağıdaki OGRENCILER listesini kendi bilgilerinizle doldurun.
    2) Veritabanı kurulu olmalıdır (python kurulum.py).
    3) python rapor/rapor_olustur.py   ->  rapor/Rapor.pdf ve rapor/Rapor.html

PDF çevirimi için:  pip install playwright   (Microsoft Edge veya
`playwright install chromium` ile kurulan Chromium kullanılır.)
"""
import html
import struct
import sys
from datetime import date
from pathlib import Path

import psycopg

KOK = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(KOK))
from config import DB_AYARLARI  # noqa: E402

# ---------------------------------------------------------------------
#  KAPAK BİLGİLERİ  (grup en fazla 3 kişi)
# ---------------------------------------------------------------------
OGRENCILER = [
    {"no": "B251210043", "ad": "Abdurrahman Turan", "soyad": "Ozcan", "eposta": "abdurrahman.ozcan@ogr.sakarya.edu.tr"},
]
UNIVERSITE = "SAKARYA ÜNİVERSİTESİ"
FAKULTE = "Bilgisayar ve Bilişim Bilimleri Fakültesi"
DERS = "BSM 211 Veritabanı Yönetim Sistemleri"
DEPO_ADRESI = "https://github.com/Turan16-k/vtys"

RAPOR = Path(__file__).resolve().parent
GORUNTU = RAPOR / "goruntuler"
SQL = KOK / "sql"

e = html.escape

# ---------------------------------------------------------------------
#  a) TANITIM VE İŞ KURALLARI
# ---------------------------------------------------------------------
TANITIM = """
<p><b>E-spor Turnuva Yönetim Sistemi</b>, e-spor organizasyonlarının oyuncu, takım, turnuva ve maç
süreçlerini yönetmek için geliştirilmiş bir web uygulamasıdır. Sistemde Valorant, Counter-Strike 2,
League of Legends, Rocket League gibi farklı oyunlarda yarışan takımlar ve bu takımların kadroları,
koçları ve sponsorları tutulur. Turnuvalar <i>online</i> (yayın platformu ve sunucu bölgesi ile) veya
<i>salon</i> (fiziksel bir mekanda, biletli) olarak düzenlenebilir.</p>
<p>Turnuvaya kaydolan takımlar için sistem, <b>herkesin herkesle oynadığı lig usulü fikstürü</b> otomatik
oluşturur ve hakemleri maçlara sırayla atar. Maç sonuçları girildikçe <b>puan tablosu tetikleyicilerle
anlık güncellenir</b>; oyuncuların maç başına öldürme / ölüm / asist istatistikleri ve MVP bilgisi tutulur.
Turnuva tamamlandığında final sıralaması hesaplanır ve ödül havuzu dereceye giren takımlara otomatik olarak
dağıtılır. Kişi, takım ve turnuva tablolarındaki tüm değişiklikler denetim amacıyla işlem günlüğüne yazılır.</p>
<p>Uygulama <b>Database-First</b> yaklaşımıyla geliştirilmiştir: veritabanı önce SQL betikleriyle
(tablolar, kısıtlar, fonksiyonlar, saklı yordamlar, tetikleyiciler) PostgreSQL üzerinde oluşturulmuş;
Python / Flask ile yazılan web uygulaması herhangi bir ORM kullanmadan bu veritabanına <i>psycopg</i>
sürücüsüyle bağlanarak tablolara SQL ile, iş mantığına ise veritabanındaki fonksiyon ve saklı yordamlar
aracılığıyla erişir. Uygulamada oyuncu, takım, turnuva, maç, kadro, ödül ve istatistik kayıtları için
<b>arama, ekleme, güncelleme ve silme</b> işlemleri bulunmaktadır.</p>
<p><b>Kullanılan teknolojiler:</b> PostgreSQL (VTYS), PL/pgSQL, Python 3, Flask, Jinja2, HTML/CSS.</p>
"""

IS_KURALLARI = [
    "Sistemdeki her kişi bir ülkeye aittir; bir ülkede sıfır veya daha fazla kişi bulunabilir.",
    "Kişiler <b>oyuncu</b>, <b>koç</b> veya <b>hakem</b> olabilir. Her kişi bu türlerden mutlaka birine ve yalnızca "
    "birine aittir (ayrık ve tam genelleme; ayırt edici nitelik <i>kisi_turu</i>).",
    "Oyuncular en az 16, koçlar ve hakemler en az 18 yaşında olmalıdır.",
    "Her oyuncunun benzersiz bir takma adı ve bir ELO puanı vardır; her hakemin benzersiz bir lisans numarası ve "
    "seviyesi (Ulusal / Uluslararası) vardır. Kişilerin e-posta adresleri benzersizdir.",
    "Her oyun bir oyun türüne aittir; bir oyun türünde birden çok oyun olabilir. Her oyunun sahadaki oyuncu "
    "sayısı (takım boyutu) tanımlıdır.",
    "Her takım yalnızca bir oyunda yarışır ve bir ülkeye bağlıdır; bir oyunda birden çok takım olabilir.",
    "Bir takımı en fazla bir koç çalıştırır, bir koç da en fazla bir takımı çalıştırır (1:1, isteğe bağlı).",
    "Bir oyuncu kariyeri boyunca birden çok takımda oynayabilir ve bir takımda birden çok oyuncu bulunur "
    "(kadro geçmişi tutulur); ancak bir oyuncu aynı anda yalnızca bir takımın aktif kadrosunda olabilir.",
    "Bir takımın aktif kadrosu, oyunun takım boyutunun en fazla 2 fazlası (yedekler) kadar olabilir. Her takımın "
    "en fazla bir kaptanı vardır; yeni kaptan atanınca eskisinin kaptanlığı kalkar.",
    "Bir takımın birden çok sponsoru, bir sponsorun da birden çok takımı olabilir. Sponsorluk; başlangıç, bitiş "
    "tarihi ve yıllık tutar bilgisiyle tutulur.",
    "Turnuvalar <b>online</b> veya <b>salon</b> turnuvası olabilir (ayrık ve tam genelleme; ayırt edici nitelik "
    "<i>turnuva_turu</i>). Online turnuvanın yayın platformu ve sunucu bölgesi, salon turnuvasının mekanı ve bilet "
    "fiyatı vardır. Bir mekanda birden çok salon turnuvası düzenlenebilir.",
    "Her turnuva tek bir oyun için düzenlenir; bir takım yalnızca kendi oyununa ait turnuvalara kaydolabilir.",
    "Turnuvaya kayıt yalnızca turnuva \"Kayıt Açık\" durumundayken yapılabilir; kayıtlı takım sayısı turnuva "
    "kontenjanını aşamaz ve kaydolan takımın aktif kadrosunda en az takım boyutu kadar oyuncu bulunmalıdır.",
    "Fikstür, kayıtlı takımlar arasında her takımın diğer her takımla bir kez karşılaştığı lig usulüyle oluşturulur; "
    "fikstür oluşturulunca turnuva \"Devam Ediyor\" durumuna geçer ve yeni kayıt alınmaz.",
    "Her maç bir turnuvaya ve bir aşamaya (Grup, Çeyrek Final, Yarı Final, Final) aittir; iki farklı takım "
    "arasında oynanır ve bir hakem tarafından yönetilebilir. Maçtaki iki takım da turnuvaya kayıtlı olmalıdır.",
    "E-sporda beraberlik yoktur. Maçı kazanan takım 3 puan alır, kaybeden puan alamaz; skor farkı averaj olarak "
    "tutulur. Sonucu girilmiş bir maçın skoru değiştirilemez.",
    "Maç istatistikleri yalnızca oynanmış maçlar için ve maç tarihinde maçtaki takımlardan birinin kadrosunda "
    "bulunan oyuncular için girilebilir. Bir oyuncunun bir maçta tek istatistik kaydı, her maçın en fazla bir MVP'si olur.",
    "Turnuvanın ödülleri dereceye göre tanımlanır; ödüllerin toplamı turnuvanın ödül havuzunu aşamaz.",
    "Tüm maçları oynanmadan turnuva tamamlanamaz. Turnuva tamamlandığında takımların final sıraları belirlenir ve "
    "ödüller ilgili takımlara atanır. Tamamlanmış bir turnuvanın durumu değiştirilemez.",
    "Devam eden bir turnuva silinemez; maç oynamış bir takım silinemez.",
    "Kişi, takım ve turnuva kayıtları üzerinde yapılan her ekleme, güncelleme ve silme işlemi; tablo adı, işlem "
    "türü, kayıt içeriği, kullanıcı ve zaman bilgisiyle işlem günlüğüne yazılır.",
]

KALITIM_ACIKLAMA = """
<p>Modelde iki genelleme (kalıtım) hiyerarşisi bulunmaktadır:</p>
<ul>
<li><b>kisi → oyuncu, koc, hakem</b>: Ortak nitelikler (ad, soyad, e-posta, doğum tarihi, ülke) üst tipte; türe
özgü nitelikler (takma ad ve ELO / deneyim yılı / lisans no ve seviye) alt tiplerdedir.</li>
<li><b>turnuva → online_turnuva, salon_turnuva</b>: Ortak nitelikler (ad, oyun, tarihler, ödül havuzu, kontenjan,
durum) üst tipte; online turnuvaya özgü yayın platformu ve sunucu bölgesi ile salon turnuvasına özgü mekan ve
bilet fiyatı alt tiplerdedir.</li>
</ul>
<p>Her iki hiyerarşi de <b>ayrık (disjoint, "d")</b> ve <b>tam (total, çift çizgi)</b> genellemedir. Gerçekleme,
alt tip tablolarının birincil anahtarının aynı zamanda üst tipe yabancı anahtar olduğu (<i>paylaşılan birincil
anahtar</i>) yöntemle yapılmıştır; ayırt edici nitelikler <i>kisi_turu</i> ve <i>turnuva_turu</i>dur. Üst tipten
bir kayıt silindiğinde alt tip kaydı <i>ON DELETE CASCADE</i> ile birlikte silinir. Alt tip ile ayırt edici
niteliğin uyumu <i>trg_kisi_alt_tip_kontrol</i> tetikleyicisi ve <i>oyuncu_ekle</i> / <i>turnuva_olustur</i>
fonksiyonlarıyla güvence altına alınmıştır. (PostgreSQL'in <i>INHERITS</i> özelliği, birincil anahtar /
benzersizlik ve yabancı anahtar kısıtlarını alt tablolara aktarmadığı için tercih edilmemiştir.)</p>
"""

# ---------------------------------------------------------------------
#  d) FONKSİYONLAR / SAKLI YORDAMLAR VE TETİKLEYİCİLER
# ---------------------------------------------------------------------
FONKSIYONLAR = [
    ("oyuncu_ekle(ad, soyad, eposta, dogum, ulke_id, takma_ad, elo) → INT", "Fonksiyon",
     "Kalıtım hiyerarşisine uygun olarak önce üst tip <i>kisi</i> tablosuna (kisi_turu = 'O'), ardından alt tip "
     "<i>oyuncu</i> tablosuna kayıt ekler ve yeni kişinin numarasını döndürür. İki ekleme tek işlemde yapılır.",
     "Oyuncular → Yeni Oyuncu formu"),
    ("oyuncu_guncelle(kisi_id, ad, soyad, eposta, dogum, ulke_id, takma_ad, elo)", "Saklı yordam (PROCEDURE)",
     "Oyuncunun üst tip (kisi) ve alt tip (oyuncu) tablolarındaki bilgilerini birlikte günceller; oyuncu "
     "bulunamazsa hata verir.",
     "Oyuncular → Düzenle formu"),
    ("oyuncu_ara(aranan) → TABLE", "Fonksiyon",
     "Takma ad, ad, soyad veya takım adına göre büyük/küçük harf duyarsız arama yapar. Oyuncunun ülkesini, yaşını, "
     "aktif takımını ve oyununu ELO puanına göre sıralı döndürür. Boş metin tüm oyuncuları getirir.",
     "Oyuncular → Arama; Ana sayfa → En yüksek ELO listesi"),
    ("turnuva_olustur(adi, oyun_id, baslangic, bitis, odul, max_takim, tur, platform, bolge, mekan_id, bilet) → INT",
     "Fonksiyon",
     "Turnuvayı üst tip <i>turnuva</i> tablosuna ekler; türüne göre <i>online_turnuva</i> veya <i>salon_turnuva</i> "
     "alt tablosuna da kayıt açar. Türe göre zorunlu bilgiler eksikse hata verir.",
     "Turnuvalar → Yeni Turnuva formu"),
    ("fikstur_olustur(turnuva_id, ilk_mac, aralik) → INT", "Fonksiyon",
     "Turnuvaya kayıtlı takımlar için herkesin herkesle oynadığı lig usulü maçları oluşturur, hakemleri sırayla "
     "atar, maç zamanlarını verilen aralıkla planlar ve turnuvayı \"Devam Ediyor\" durumuna getirir. Oluşan maç "
     "sayısını döndürür.",
     "Turnuva detayı → Fikstürü Oluştur"),
    ("mac_sonucu_gir(mac_id, skor1, skor2)", "Saklı yordam (PROCEDURE)",
     "Maç skorunu kaydeder ve maçı \"Oynandı\" yapar; beraberlik skorunu reddeder. Kazananın belirlenmesi ve puan "
     "tablosunun güncellenmesi bu güncellemeyle tetiklenen tetikleyicilerce yapılır.",
     "Turnuva detayı ve Maç detayı → Skor girişi"),
    ("puan_tablosu(turnuva_id) → TABLE", "Fonksiyon",
     "Turnuvanın sıralamasını puan, skor farkı, galibiyet ve takım adına göre hesaplayarak sıra numarasıyla "
     "döndürür. Turnuva tamamlanırken ödül dağıtan tetikleyici de bu fonksiyonu kullanır.",
     "Turnuva detayı → Puan Tablosu"),
    ("oyuncu_istatistik(oyuncu_id) → TABLE", "Fonksiyon",
     "Oyuncunun oynadığı maç sayısını, toplam öldürme / ölüm / asist değerlerini, KDA oranını "
     "((öldürme + asist) / ölüm) ve MVP sayısını hesaplar.",
     "Oyuncu detayı → İstatistik kartları"),
    ("oyuncu_transfer(oyuncu_id, yeni_takim_id, rol)", "Saklı yordam (PROCEDURE)",
     "Oyuncunun aktif kadro kaydını bugünün tarihiyle kapatır (geçmiş korunur) ve yeni takım verilmişse o takımın "
     "kadrosuna ekler; yeni takım boşsa oyuncu serbest kalır.",
     "Oyuncu detayı → Transfer; Takım detayı → Kadroya ekle / Kadrodan çıkar; Yeni Oyuncu formu (takım seçimi)"),
]

TETIKLEYICILER = [
    ("trg_oyuncu_alt_tip, trg_koc_alt_tip, trg_hakem_alt_tip", "BEFORE INSERT — oyuncu, koc, hakem",
     "trg_kisi_alt_tip_kontrol()",
     "Alt tip tablosuna eklenen kişinin <i>kisi_turu</i> değerinin tabloyla uyumlu olduğunu denetler (kalıtım "
     "tutarlılığı). Oyuncuların en az 16, koç ve hakemlerin en az 18 yaşında olmasını zorunlu kılar."),
    ("trg_kadro_kontrol", "BEFORE INSERT OR UPDATE — takim_oyuncu", "trg_kadro_kontrol()",
     "Takımın aktif kadrosunun takım boyutu + 2 sınırını aşmasını engeller. Bir oyuncu kaptan yapıldığında "
     "takımdaki diğer oyuncuların kaptanlığını otomatik kaldırır; kadrodan ayrılan oyuncunun kaptanlığını siler."),
    ("trg_katilim_kontrol", "BEFORE INSERT — turnuva_katilim", "trg_katilim_kontrol()",
     "Turnuva kaydında; kaydın açık olmasını, takımın turnuvanın oyununda yarışmasını, kontenjanın dolmamış "
     "olmasını ve takımın aktif kadrosunun yeterli olmasını denetler."),
    ("trg_mac_kontrol", "BEFORE INSERT OR UPDATE — mac", "trg_mac_kontrol()",
     "Maçtaki iki takımın da turnuvaya kayıtlı olmasını, sonucun yalnızca devam eden turnuvada girilmesini "
     "denetler; sonucu girilmiş maçın değiştirilmesini engeller ve skora göre <i>kazanan_id</i> alanını otomatik doldurur."),
    ("trg_mac_puan_guncelle", "AFTER UPDATE OF durum — mac (durum 'Oynandı' olduğunda)", "trg_mac_puan_guncelle()",
     "Maç oynandığında puan tablosunu (turnuva_katilim) günceller: kazanana galibiyet ve 3 puan, kaybedene "
     "mağlubiyet yazar; iki takımın skor farkını (averaj) günceller."),
    ("trg_istatistik_kontrol", "BEFORE INSERT OR UPDATE — oyuncu_mac_istatistik", "trg_istatistik_kontrol()",
     "İstatistiğin yalnızca oynanmış maç için ve maç tarihinde maçtaki takımlardan birinin kadrosunda olan oyuncu "
     "için girilmesini sağlar; oyuncunun takımını otomatik bulur. MVP seçildiğinde aynı maçtaki diğer MVP'yi kaldırır."),
    ("trg_turnuva_durum", "AFTER UPDATE OF durum — turnuva", "trg_turnuva_durum()",
     "Tamamlanmış turnuvanın yeniden açılmasını ve oynanmamış maç varken turnuvanın bitirilmesini engeller. "
     "Turnuva \"Tamamlandı\" olduğunda <i>puan_tablosu</i> fonksiyonuyla final sıralarını yazar ve ödülleri "
     "dereceye giren takımlara atar."),
    ("trg_turnuva_silme_kontrol", "BEFORE DELETE — turnuva", "trg_turnuva_silme_kontrol()",
     "Devam eden bir turnuvanın silinmesini engeller."),
    ("trg_odul_kontrol", "BEFORE INSERT OR UPDATE OF tutar — odul", "trg_odul_kontrol()",
     "Bir turnuvanın ödülleri toplamının turnuvanın ödül havuzunu aşmasını engeller."),
    ("trg_kisi_log, trg_takim_log, trg_turnuva_log", "AFTER INSERT OR UPDATE OR DELETE — kisi, takim, turnuva",
     "trg_islem_log()",
     "Yapılan her değişikliği tablo adı, işlem türü, kaydın JSON içeriği, veritabanı kullanıcısı ve zaman "
     "bilgisiyle <i>islem_log</i> tablosuna yazar (denetim kaydı)."),
]

# ---------------------------------------------------------------------
#  e) EKRAN GÖRÜNTÜLERİ
# ---------------------------------------------------------------------
GORUNTULER = [
    ("Arama İşlemleri", [
        ("02_arama_oyuncu", "Oyuncu arama: \"kart\" metniyle <i>oyuncu_ara()</i> fonksiyonu takma ad, ad, soyad ve takım adında arar."),
        ("03_arama_takim", "Takım arama: ad filtresi ve oyun seçimi (Rocket League) ile arama."),
        ("04_arama_turnuva", "Turnuva arama: durum filtresi (Tamamlandı) ile arama."),
    ]),
    ("Ekleme İşlemleri", [
        ("05_ekleme_form", "Yeni oyuncu formu: kişi (üst tip) ve oyuncu (alt tip) bilgileri ile takım seçimi."),
        ("06_ekleme_sonuc", "Oyuncu <i>oyuncu_ekle()</i> fonksiyonuyla eklendi ve <i>oyuncu_transfer</i> yordamıyla takıma katıldı."),
        ("07_ekleme_hata_tetikleyici", "16 yaşından küçük oyuncu eklenmek istendiğinde <i>trg_oyuncu_alt_tip</i> tetikleyicisi işlemi engelledi."),
        ("08_ekleme_turnuva_form", "Yeni salon turnuvası formu (türe göre online / salon alanları değişir)."),
        ("09_ekleme_turnuva_sonuc", "Turnuva <i>turnuva_olustur()</i> fonksiyonuyla turnuva ve salon_turnuva tablolarına eklendi."),
        ("10_ekleme_katilim", "Turnuvaya takım kaydı eklendi (<i>trg_katilim_kontrol</i> denetiminden geçerek)."),
    ]),
    ("Güncelleme İşlemleri", [
        ("11_guncelleme_form", "Oyuncu düzenleme formu (ELO ve e-posta değiştiriliyor)."),
        ("12_guncelleme_sonuc", "Oyuncu <i>oyuncu_guncelle</i> saklı yordamıyla güncellendi."),
        ("13_guncelleme_takim_form", "Takım düzenleme formu (takım adı değiştiriliyor)."),
        ("14_guncelleme_takim_sonuc", "Takım bilgileri güncellendi."),
        ("15_guncelleme_mac_sonucu", "Maç sonucu <i>mac_sonucu_gir</i> yordamıyla girildi; kazanan ve puan tablosu tetikleyicilerle güncellendi."),
    ]),
    ("Silme İşlemleri", [
        ("16_silme_oncesi", "Silinecek oyuncu (Anka) listede; Sil butonu onay sorduktan sonra kaydı siler."),
        ("17_silme_sonuc", "Oyuncu silindi (kisi kaydı silinince oyuncu alt tip kaydı ON DELETE CASCADE ile silinir)."),
        ("18_silme_hata_takim", "Maç oynamış bir takım silinmek istendiğinde yabancı anahtar kısıtı işlemi engelledi."),
        ("19_silme_hata_turnuva", "Devam eden turnuva silinmek istendiğinde <i>trg_turnuva_silme_kontrol</i> tetikleyicisi işlemi engelledi."),
        ("20_silme_turnuva_sonuc", "Kayıt açık durumdaki turnuva silindi."),
    ]),
    ("Diğer Ekranlar", [
        ("01_ana_sayfa", "Ana sayfa (kontrol paneli)."),
        ("21_turnuva_tamamlandi", "Tamamlanmış turnuva: final sıralaması ve ödüller <i>trg_turnuva_durum</i> tetikleyicisi ile atandı."),
        ("22_oyuncu_detay", "Oyuncu detayı: <i>oyuncu_istatistik()</i> ile hesaplanan istatistikler, kadro geçmişi ve maçlar."),
        ("23_islem_gunlugu", "İşlem günlüğü: <i>trg_islem_log</i> tetikleyicisinin tuttuğu denetim kayıtları."),
    ]),
]

KAYNAK_DOSYALAR = ["config.py", "kurulum.py", "app.py", "templates/base.html", "templates/_makrolar.html",
                   "templates/index.html", "templates/oyuncular.html", "templates/oyuncu_form.html",
                   "templates/oyuncu_detay.html", "templates/takimlar.html", "templates/takim_form.html",
                   "templates/takim_detay.html", "templates/turnuvalar.html", "templates/turnuva_form.html",
                   "templates/turnuva_detay.html", "templates/mac_detay.html", "templates/islem_gunlugu.html",
                   "static/style.css"]

TABLO_SIRASI = ["ulke", "oyun_turu", "oyun", "kisi", "oyuncu", "koc", "hakem", "takim", "takim_oyuncu",
                "sponsor", "takim_sponsor", "mekan", "turnuva", "online_turnuva", "salon_turnuva",
                "turnuva_katilim", "asama", "mac", "oyuncu_mac_istatistik", "odul", "islem_log"]


def iliskisel_sema():
    """Metinsel ilişkisel şemayı veritabanı kataloğundan üretir."""
    with psycopg.connect(**DB_AYARLARI) as conn:
        kolonlar = conn.execute("""
            SELECT table_name, column_name FROM information_schema.columns
             WHERE table_schema = 'public' ORDER BY table_name, ordinal_position""").fetchall()
        pk = set(conn.execute("""
            SELECT kcu.table_name, kcu.column_name
              FROM information_schema.table_constraints tc
              JOIN information_schema.key_column_usage kcu
                ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
             WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_schema = 'public'""").fetchall())
        fk = conn.execute("""
            SELECT c.conrelid::regclass::text, a.attname, c.confrelid::regclass::text, af.attname
              FROM pg_constraint c
              CROSS JOIN LATERAL unnest(c.conkey, c.confkey) AS k(kol, ref)
              JOIN pg_attribute a  ON a.attrelid  = c.conrelid  AND a.attnum  = k.kol
              JOIN pg_attribute af ON af.attrelid = c.confrelid AND af.attnum = k.ref
             WHERE c.contype = 'f' AND c.connamespace = 'public'::regnamespace""").fetchall()
        sayilar = conn.execute("""
            SELECT (SELECT count(*) FROM information_schema.tables
                     WHERE table_schema = 'public' AND table_type = 'BASE TABLE'),
                   (SELECT count(*) FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
                       AND p.prorettype <> 'trigger'::regtype),
                   (SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
                     WHERE c.relnamespace = 'public'::regnamespace AND NOT t.tgisinternal)""").fetchone()

    fk_harita = {}
    for tablo, kolon, ref_tablo, ref_kolon in fk:
        fk_harita.setdefault(tablo, {})[kolon] = f"{ref_tablo}({ref_kolon})"

    satirlar = []
    for tablo in TABLO_SIRASI:
        parcalar = []
        for t, k in kolonlar:
            if t != tablo:
                continue
            ad = e(k)
            if (t, k) in pk:
                ad = f"<u><b>{ad}</b></u>"
            if k in fk_harita.get(t, {}):
                ad = f"<i>{ad}</i><sup>FK</sup>"
            parcalar.append(ad)
        referanslar = "; ".join(f"{k} → {r}" for k, r in fk_harita.get(tablo, {}).items())
        satirlar.append(
            f"<div class='sema'><b>{tablo}</b> ( {', '.join(parcalar)} )"
            + (f"<div class='ref'>Yabancı anahtar: {e(referanslar)}</div>" if referanslar else "")
            + "</div>")
    return "\n".join(satirlar), sayilar


def png_oran(yol):
    """PNG dosyasının yükseklik / genişlik oranı (dosya başlığından okunur)."""
    with open(yol, "rb") as f:
        baslik = f.read(24)
    genislik, yukseklik = struct.unpack(">II", baslik[16:24])
    return yukseklik / genislik


def kod_blogu(metin):
    return f"<pre class='kod'>{e(metin)}</pre>"


def kapak():
    ogrenciler = "".join(
        f"<tr><td>{e(o['no'])}</td><td>{e(o['ad'])}</td><td>{e(o['soyad'])}</td><td>{e(o['eposta'])}</td></tr>"
        for o in OGRENCILER)
    return f"""
<section class="kapak">
  <div class="kurum">{e(UNIVERSITE)}<br><span>{e(FAKULTE)}</span></div>
  <div class="ders">{e(DERS)}<br>PROJE ÇALIŞMASI</div>
  <h1>E-SPOR TURNUVA<br>YÖNETİM SİSTEMİ</h1>
  <p class="altyazi">PostgreSQL · PL/pgSQL · Python / Flask Web Uygulaması</p>
  <table class="ogrenci">
    <thead><tr><th>Öğrenci Numarası</th><th>Adı</th><th>Soyadı</th><th>E-posta</th></tr></thead>
    <tbody>{ogrenciler}</tbody>
  </table>
  <p class="tarih">{date.today().strftime('%d.%m.%Y')}</p>
</section>"""


def icindekiler():
    return """
<section class="icindekiler">
<h2>İçindekiler</h2>
<ol type="a">
  <li>Uygulamanın Kısa Tanıtımı ve İş Kuralları</li>
  <li>Varlık Bağıntı Modeli (Crow's Foot, Kalıtım) ve İlişkisel Şema</li>
  <li>Veritabanını Verilerle Birlikte Oluşturan SQL İfadeleri</li>
  <li>Saklı Yordamlar / Fonksiyonlar ve Tetikleyiciler</li>
  <li>Arama, Ekleme, Silme ve Güncelleme Ekran Görüntüleri</li>
  <li>Uygulamanın Kaynak Kodları</li>
</ol>
</section>"""


def rapor_html():
    sema, (tablo_sayisi, fonksiyon_sayisi, tetikleyici_sayisi) = iliskisel_sema()
    er_svg = (KOK / "diyagram" / "er_diyagrami.svg").read_text(encoding="utf-8")
    sql_dosyalari = ["01_tablolar.sql", "02_fonksiyonlar.sql", "03_tetikleyiciler.sql", "04_ornek_veriler.sql"]

    b = [kapak(), icindekiler()]

    b.append("<section><h2>a) Uygulamanın Kısa Tanıtımı ve İş Kuralları</h2>")
    b.append("<h3>Uygulamanın Tanıtımı</h3>" + TANITIM)
    b.append(f"""<div class="ozet"><div><b>{tablo_sayisi}</b><span>tablo</span></div>
        <div><b>2</b><span>kalıtım hiyerarşisi</span></div>
        <div><b>{fonksiyon_sayisi}</b><span>fonksiyon / saklı yordam</span></div>
        <div><b>{tetikleyici_sayisi}</b><span>tetikleyici</span></div></div>""")
    b.append("<h3>İş Kuralları</h3><ol class='kurallar'>" + "".join(f"<li>{k}</li>" for k in IS_KURALLARI) + "</ol></section>")

    b.append("<section><h2>b) Varlık Bağıntı Modeli ve İlişkisel Şema</h2>")
    b.append("<h3>Varlık Bağıntı Diyagramı (Crow's Foot)</h3>")
    b.append("<p class='not'>Diyagram draw.io ile düzenlenebilir biçimde <i>diyagram/er_diyagrami.drawio</i> dosyasında yer almaktadır.</p>")
    b.append(f"<div class='diyagram'>{er_svg}</div>")
    b.append("<h3>Genelleme / Kalıtım</h3>" + KALITIM_ACIKLAMA)
    b.append("<h3>İlişkisel Şema (Metinsel Gösterim)</h3>")
    b.append("<p class='not'>Birincil anahtarlar <u><b>altı çizili</b></u>, yabancı anahtarlar <i>eğik</i> ve <sup>FK</sup> ile gösterilmiştir.</p>")
    b.append(sema + "</section>")

    b.append("<section><h2>c) Veritabanını Verilerle Birlikte Oluşturan SQL İfadeleri</h2>")
    b.append("<p>Betikler sırasıyla çalıştırıldığında tablolar, kısıtlar, fonksiyonlar, saklı yordamlar, tetikleyiciler "
             "ve örnek veriler oluşturulur (<i>python kurulum.py</i> veya psql ile). Örnek veri betiği; turnuvaları "
             "<i>turnuva_olustur</i>, fikstürleri <i>fikstur_olustur</i>, maç sonuçlarını <i>mac_sonucu_gir</i> ile "
             "girerek fonksiyon ve tetikleyicileri de çalıştırır.</p>")
    for ad in sql_dosyalari:
        b.append(f"<h3>{ad}</h3>" + kod_blogu((SQL / ad).read_text(encoding="utf-8")))
    b.append("</section>")

    b.append("<section><h2>d) Saklı Yordamlar / Fonksiyonlar ve Tetikleyiciler</h2>")
    b.append(f"<h3>Fonksiyonlar ve Saklı Yordamlar ({len(FONKSIYONLAR)} adet)</h3>")
    b.append("<p class='not'>Tetikleyiciler için tanımlanan fonksiyonlar bu listeye dahil değildir. Listedeki tüm "
             "fonksiyon ve yordamlar web uygulamasında kullanılmaktadır.</p><ol class='liste'>")
    for imza, tur, aciklama, yer in FONKSIYONLAR:
        b.append(f"<li><div class='imza'>{e(imza)}</div><div class='tur'>{tur}</div>"
                 f"<p>{aciklama}</p><p class='yer'><b>Uygulamada:</b> {e(yer)}</p></li>")
    b.append("</ol>")
    b.append(f"<h3>Tetikleyiciler ({len(TETIKLEYICILER)} grup, {tetikleyici_sayisi} tetikleyici)</h3><ol class='liste'>")
    for ad, olay, fonk, aciklama in TETIKLEYICILER:
        b.append(f"<li><div class='imza'>{e(ad)}</div><div class='tur'>{e(olay)} · Fonksiyon: {e(fonk)}</div>"
                 f"<p>{aciklama}</p></li>")
    b.append("</ol></section>")

    b.append("<section><h2>e) Ekran Görüntüleri</h2>")
    no = 1
    for baslik, liste in GORUNTULER:
        b.append(f"<h3>{baslik}</h3>")
        for dosya, aciklama in liste:
            png = GORUNTU / f"{dosya}.png"
            sinif = "uzun" if png_oran(png) > 0.75 else "kisa"
            b.append(f"<figure class='{sinif}'><img src='{png.as_uri()}'><figcaption><b>Şekil {no}.</b> {aciklama}</figcaption></figure>")
            no += 1
    b.append("</section>")

    b.append("<section><h2>f) Uygulamanın Kaynak Kodları</h2>")
    if DEPO_ADRESI:
        b.append(f"<p>Kaynak kodlarının tamamı şu depoda yer almaktadır: <a href='{e(DEPO_ADRESI)}'>{e(DEPO_ADRESI)}</a></p>")
    b.append("<p>Proje klasör yapısı:</p>" + kod_blogu(
        "espor-turnuva/\n"
        "├── app.py                 Flask web uygulaması (rotalar, veritabanı erişimi)\n"
        "├── config.py              PostgreSQL bağlantı ayarları\n"
        "├── kurulum.py             Veritabanını oluşturan ve SQL betiklerini çalıştıran betik\n"
        "├── requirements.txt\n"
        "├── sql/                   01_tablolar, 02_fonksiyonlar, 03_tetikleyiciler, 04_ornek_veriler\n"
        "├── templates/             Jinja2 HTML şablonları\n"
        "├── static/style.css\n"
        "├── diyagram/              er_diyagrami.drawio, er_diyagrami.svg\n"
        "└── rapor/                 rapor_olustur.py, Rapor.pdf, goruntuler/"))
    for ad in KAYNAK_DOSYALAR:
        b.append(f"<h3>{ad}</h3>" + kod_blogu((KOK / ad).read_text(encoding="utf-8")))
    b.append("</section>")

    return f"""<!doctype html><html lang="tr"><head><meta charset="utf-8"><title>Rapor</title>
<style>{CSS}</style></head><body>{''.join(b)}</body></html>"""


CSS = """
@page { size: A4; margin: 16mm 15mm 18mm 15mm; }
* { box-sizing: border-box; }
body { font-family: "Segoe UI", Calibri, Arial, sans-serif; font-size: 10.5pt; color: #111827; line-height: 1.45; margin: 0; }
h2 { font-size: 16pt; color: #312e81; border-bottom: 2px solid #6366f1; padding-bottom: 4px; margin: 0 0 12px; }
h3 { font-size: 12pt; color: #1e3a8a; margin: 18px 0 8px; break-after: avoid; }
section { break-before: page; }
p { margin: 0 0 8px; text-align: justify; }
.not { color: #4b5563; font-size: 9.5pt; }
.kapak { break-before: auto; text-align: center; padding-top: 30mm; height: 255mm; position: relative; }
.kapak .kurum { font-size: 15pt; font-weight: 700; letter-spacing: 1px; }
.kapak .kurum span { font-size: 11.5pt; font-weight: 500; letter-spacing: 0; color: #374151; }
.kapak .ders { margin-top: 22mm; font-size: 13pt; font-weight: 600; color: #374151; }
.kapak h1 { margin: 22mm 0 6mm; font-size: 30pt; color: #312e81; line-height: 1.15; }
.kapak .altyazi { text-align: center; color: #4b5563; }
.kapak table.ogrenci { margin: 30mm auto 0; border-collapse: collapse; font-size: 11pt; min-width: 150mm; }
.kapak table.ogrenci th, .kapak table.ogrenci td { border: 1px solid #9ca3af; padding: 7px 10px; }
.kapak table.ogrenci th { background: #eef2ff; }
.kapak .tarih { position: absolute; bottom: 0; width: 100%; text-align: center; color: #4b5563; }
.icindekiler ol { font-size: 12pt; line-height: 2; }
.ozet { display: flex; gap: 10px; margin: 12px 0; }
.ozet div { flex: 1; border: 1px solid #c7d2fe; background: #eef2ff; border-radius: 6px; padding: 8px; text-align: center; }
.ozet b { display: block; font-size: 18pt; color: #312e81; }
.ozet span { font-size: 9pt; color: #374151; }
.kurallar li { margin-bottom: 5px; text-align: justify; }
.diyagram svg { width: 100%; height: auto; max-height: 232mm; display: block; margin: 0 auto; border: 1px solid #e5e7eb; }
.sema { font-family: Consolas, "Courier New", monospace; font-size: 9.2pt; margin: 0 0 7px; padding: 6px 8px; background: #f9fafb; border-left: 3px solid #6366f1; break-inside: avoid; }
.sema sup { font-size: 6.5pt; color: #2563eb; }
.sema .ref { color: #4b5563; font-size: 8.4pt; margin-top: 2px; }
pre.kod { font-family: Consolas, "Courier New", monospace; font-size: 7.4pt; line-height: 1.3; background: #f8fafc; border: 1px solid #e5e7eb; padding: 8px; white-space: pre-wrap; word-break: break-word; margin: 0 0 10px; }
ol.liste > li { margin-bottom: 10px; break-inside: avoid; }
.imza { font-family: Consolas, monospace; font-weight: 700; color: #1e3a8a; font-size: 9.5pt; }
.tur { font-size: 9pt; color: #6b7280; margin-bottom: 3px; }
.yer { font-size: 9.5pt; color: #065f46; }
figure { margin: 0 0 14px; break-inside: avoid; text-align: center; }
figure img { max-width: 100%; border: 1px solid #d1d5db; }
figure.kisa img { max-height: 108mm; }
figure.uzun img { max-height: 215mm; }
figcaption { font-size: 9.2pt; color: #374151; margin-top: 4px; }
"""


def pdf_olustur(html_yolu, pdf_yolu):
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        try:
            tarayici = p.chromium.launch(channel="msedge")
        except Exception:
            tarayici = p.chromium.launch()
        sayfa = tarayici.new_page()
        sayfa.goto(html_yolu.as_uri())
        sayfa.wait_for_load_state("networkidle")
        sayfa.pdf(path=str(pdf_yolu), format="A4", print_background=True,
                  display_header_footer=True,
                  header_template="<span></span>",
                  footer_template="<div style='width:100%;font-size:8px;color:#6b7280;text-align:center'>"
                                  "E-spor Turnuva Yönetim Sistemi · <span class='pageNumber'></span> / "
                                  "<span class='totalPages'></span></div>",
                  margin={"top": "16mm", "bottom": "18mm", "left": "15mm", "right": "15mm"})
        tarayici.close()


if __name__ == "__main__":
    html_yolu = RAPOR / "Rapor.html"
    html_yolu.write_text(rapor_html(), encoding="utf-8")
    print("HTML oluşturuldu:", html_yolu)
    pdf_olustur(html_yolu, RAPOR / "Rapor.pdf")
    print("PDF oluşturuldu:", RAPOR / "Rapor.pdf")
