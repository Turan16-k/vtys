# E-spor Turnuva Yönetim Sistemi

BSM 211 Veritabanı Yönetim Sistemleri proje çalışması. PostgreSQL veritabanı (Database-First) ve
Python / Flask web uygulaması.

- 21 tablo, 2 kalıtım hiyerarşisi (`kisi → oyuncu / koc / hakem`, `turnuva → online_turnuva / salon_turnuva`)
- 9 fonksiyon / saklı yordam (hepsi uygulamada kullanılıyor), 14 tetikleyici
- Oyuncu, takım, turnuva, maç, kadro, ödül ve istatistik için arama / ekleme / güncelleme / silme

## Klasörler

| Yol | İçerik |
|---|---|
| `sql/01_tablolar.sql` | Tablolar ve kısıtlar |
| `sql/02_fonksiyonlar.sql` | Fonksiyonlar ve saklı yordamlar |
| `sql/03_tetikleyiciler.sql` | Tetikleyiciler |
| `sql/04_ornek_veriler.sql` | Örnek veriler |
| `sql/tum_kurulum.sql` | Dört betiğin birleşimi (kurulum.py üretir) |
| `diyagram/er_diyagrami.drawio` | Crow's Foot ER diyagramı (draw.io ile açılır) |
| `rapor/Rapor.pdf` | SABİS'e yüklenecek rapor |
| `app.py`, `templates/`, `static/` | Web uygulaması |

## Kurulum

1. PostgreSQL'i kurun (https://www.postgresql.org/download/). Kurulumda verdiğiniz `postgres` kullanıcı
   şifresini `config.py` dosyasındaki `PGPASSWORD` varsayılanına yazın (ya da ortam değişkeni olarak tanımlayın).
2. Python paketlerini kurun:
   ```
   pip install -r requirements.txt
   ```
3. Veritabanını oluşturun (`espor_turnuva` veritabanını açar ve dört SQL betiğini sırayla çalıştırır):
   ```
   python kurulum.py
   ```
   Alternatif olarak pgAdmin / psql ile `espor_turnuva` adında bir veritabanı oluşturup
   `sql/tum_kurulum.sql` dosyasını çalıştırabilirsiniz.
4. Uygulamayı başlatın ve tarayıcıda http://127.0.0.1:5000 adresini açın:
   ```
   python app.py
   ```

`kurulum.py` her çalıştırıldığında tabloları silip yeniden oluşturur; veritabanını örnek verilere
döndürmek için de kullanılabilir.

## Raporu yeniden üretme

1. `rapor/rapor_olustur.py` dosyasının başındaki `OGRENCILER` listesine öğrenci numarası, ad, soyad ve
   e-posta bilgilerini yazın (grupta en fazla 3 kişi).
2. Veritabanı kurulu durumdayken çalıştırın:
   ```
   python rapor/rapor_olustur.py
   ```
   PDF, Microsoft Edge ile üretilir. Edge yoksa önce `playwright install chromium` çalıştırın.
