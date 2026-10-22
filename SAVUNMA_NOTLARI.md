# Savunma Hazırlık Notları

Savunmada sorular grup üyelerinden rastgele birine sorulabilir; herkesin tüm projeye hakim olması gerekir.
Aşağıdaki sorular bu projeye özgü olası sorulardır.

## Genel / Tasarım

**Database-First nedir, projede nasıl uygulandı?**
Önce veritabanı SQL ile tasarlanıp oluşturuldu (tablolar, kısıtlar, fonksiyonlar, tetikleyiciler). Uygulama
ORM ile tablo üretmez; var olan veritabanına psycopg ile bağlanır, SQL sorguları ve `SELECT fonksiyon(...)` /
`CALL yordam(...)` çağrıları kullanır. Code-First'te ise tablolar uygulamadaki sınıflardan üretilir.

**Kaç tablo var?** 21 tablo: ulke, oyun_turu, oyun, kisi, oyuncu, koc, hakem, takim, takim_oyuncu, sponsor,
takim_sponsor, mekan, turnuva, online_turnuva, salon_turnuva, turnuva_katilim, asama, mac,
oyuncu_mac_istatistik, odul, islem_log.

**Kalıtım nerede ve nasıl gerçeklendi?**
`kisi → oyuncu, koc, hakem` ve `turnuva → online_turnuva, salon_turnuva`. Alt tipin birincil anahtarı aynı
zamanda üst tipe yabancı anahtardır (`oyuncu.kisi_id → kisi.kisi_id`, ON DELETE CASCADE). Ayırt edici nitelikler
`kisi_turu` ('O','K','H') ve `turnuva_turu` ('O','S').

**Diyagramdaki "d" ve çift çizgi ne anlama geliyor?**
"d" ayrık (disjoint): bir kişi yalnızca bir alt tipte olabilir. Çift çizgi tam (total) katılım: her kişi mutlaka
bir alt tipe aittir. Ayrık olmasaydı "o" (overlapping) kullanılırdı.

**Neden PostgreSQL'in `INHERITS` özelliğini kullanmadınız?**
INHERITS ile birincil anahtar, UNIQUE ve yabancı anahtar kısıtları alt tablolara aktarılmaz; örneğin başka bir
tablo üst tabloya FK verdiğinde alt tablodaki satırları göremez. Paylaşılan birincil anahtar yöntemi bu sorunları
yaşamaz.

**Çoka çok ilişkiler hangileri ve nasıl çözüldü?**
takım–oyuncu (`takim_oyuncu`, aynı zamanda kadro geçmişi), takım–sponsor (`takim_sponsor`, bileşik PK),
takım–turnuva (`turnuva_katilim`, aynı zamanda puan tablosu), oyuncu–maç (`oyuncu_mac_istatistik`).

**Bire bir ilişki var mı?** Koç–takım: `takim.koc_id` UNIQUE ve NULL olabilir; bir koç tek takımı çalıştırır.

**Bir oyuncunun aynı anda iki takımda olmamasını nasıl sağladınız?**
Kısmi benzersiz indeks: `CREATE UNIQUE INDEX uq_aktif_kadro ON takim_oyuncu (oyuncu_id) WHERE ayrilma_tarihi IS NULL`.

**mac tablosunda takim tablosuna kaç yabancı anahtar var?** Üç: takim1_id, takim2_id, kazanan_id.

**Beraberliği nasıl engellediniz?** `ck_mac_skor` CHECK kısıtı ve `mac_sonucu_gir` yordamındaki kontrol.

## Fonksiyonlar / Saklı Yordamlar (9)

| Ad | Tür | Ne yapar | Uygulamada |
|---|---|---|---|
| oyuncu_ekle | FUNCTION → INT | kisi + oyuncu ekler | Yeni Oyuncu |
| oyuncu_guncelle | PROCEDURE | kisi + oyuncu günceller | Oyuncu Düzenle |
| oyuncu_ara | FUNCTION → TABLE | takma ad/ad/soyad/takım ile arama | Oyuncular arama, ana sayfa |
| turnuva_olustur | FUNCTION → INT | turnuva + alt tip ekler | Yeni Turnuva |
| fikstur_olustur | FUNCTION → INT | lig usulü maçları üretir, hakem atar | Fikstürü Oluştur |
| mac_sonucu_gir | PROCEDURE | skoru yazar, maçı "Oynandı" yapar | Skor girişi |
| puan_tablosu | FUNCTION → TABLE | sıralamayı hesaplar | Puan tablosu |
| oyuncu_istatistik | FUNCTION → TABLE | toplamlar ve KDA | Oyuncu detayı |
| oyuncu_transfer | PROCEDURE | eski kadroyu kapatır, yeni takıma ekler | Transfer, kadro ekle/çıkar |

**Fonksiyon ile saklı yordam farkı?** Fonksiyon değer döndürür ve `SELECT` içinde çağrılır; yordam
(PROCEDURE) değer döndürmez, `CALL` ile çağrılır ve içinde işlem (transaction) kontrolü yapılabilir.

**RETURNS TABLE ne işe yarar?** Fonksiyonun bir tablo gibi satırlar döndürmesini sağlar:
`SELECT * FROM puan_tablosu(2)`.

**fikstur_olustur kaç maç üretir?** n takım için n·(n−1)/2 maç (6 takım → 15 maç).

## Tetikleyiciler (14)

| Tetikleyici | Zaman / Olay | Görev |
|---|---|---|
| trg_oyuncu_alt_tip, trg_koc_alt_tip, trg_hakem_alt_tip | BEFORE INSERT | kisi_turu uyumu, yaş sınırı (16 / 18) |
| trg_kadro_kontrol | BEFORE INSERT/UPDATE takim_oyuncu | kadro sınırı, tek kaptan |
| trg_katilim_kontrol | BEFORE INSERT turnuva_katilim | kayıt açık mı, oyun uyumu, kontenjan, kadro |
| trg_mac_kontrol | BEFORE INSERT/UPDATE mac | takımlar kayıtlı mı, oynanmış maç kilidi, kazananı atar |
| trg_mac_puan_guncelle | AFTER UPDATE OF durum mac | puan tablosunu günceller |
| trg_istatistik_kontrol | BEFORE INSERT/UPDATE istatistik | oyuncu maçta mı, takımını bulur, tek MVP |
| trg_turnuva_durum | AFTER UPDATE OF durum turnuva | geri dönüş yasağı, sıralama + ödül dağıtımı |
| trg_turnuva_silme_kontrol | BEFORE DELETE turnuva | devam eden turnuva silinemez |
| trg_odul_kontrol | BEFORE INSERT/UPDATE odul | ödül toplamı ≤ ödül havuzu |
| trg_kisi_log, trg_takim_log, trg_turnuva_log | AFTER INSERT/UPDATE/DELETE | islem_log'a JSON kayıt |

**BEFORE ve AFTER tetikleyici farkı?** BEFORE, satır yazılmadan önce çalışır; `NEW` değerini değiştirebilir
(ör. kazanan_id atanması) veya `RAISE EXCEPTION` ile işlemi durdurabilir. AFTER, satır yazıldıktan sonra çalışır;
başka tabloları güncellemek için kullanılır (ör. puan tablosu, log).

**NEW ve OLD nedir?** NEW eklenen/güncellenen satırın yeni hali, OLD güncellenen/silinen satırın eski halidir.
INSERT'te yalnızca NEW, DELETE'te yalnızca OLD vardır.

**FOR EACH ROW ne demek?** Tetikleyici etkilenen her satır için ayrı çalışır (FOR EACH STATEMENT: komut başına bir kez).

**`WHEN (OLD.durum <> 'Oynandı' AND NEW.durum = 'Oynandı')` neden var?** Puanın yalnızca maç ilk kez oynandı
yapıldığında, bir kez eklenmesi için.

**Tetikleyicide hata olursa ne olur?** `RAISE EXCEPTION` tüm işlemi geri alır (rollback); uygulama hata
mesajını kullanıcıya gösterir.

## Gösterilebilecek Senaryolar (canlı demo)

1. 16 yaşından küçük oyuncu ekle → tetikleyici engeller.
2. Rocket League takımını Valorant turnuvasına kaydet → "takım bu turnuvanın oyununda yarışmıyor".
3. Kayıt açık turnuvaya takım kaydet → Fikstürü Oluştur → maç sonucu gir → puan tablosu değişir.
4. Tüm maçlar oynanmadan "Turnuvayı Tamamla" → engellenir; hepsi oynanınca sıralama ve ödüller atanır.
5. Maç oynamış takımı sil → yabancı anahtar engeller. Devam eden turnuvayı sil → tetikleyici engeller.
6. Bir oyuncuyu kaptan yap → eski kaptanın kaptanlığı kalkar.
7. Herhangi bir değişiklikten sonra İşlem Günlüğü sayfasını göster.

Demodan önce `python kurulum.py` ile veritabanını örnek verilere döndürmeyi unutmayın.
