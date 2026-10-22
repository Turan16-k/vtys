"""E-spor Turnuva Yönetim Sistemi - Flask web uygulaması.

Database-First: Veritabanı sql/ klasöründeki betiklerle oluşturulur; uygulama
ORM kullanmaz, tablolara SQL ile, iş mantığına ise veritabanındaki
fonksiyon / saklı yordamlar aracılığıyla erişir.
"""
from datetime import date, datetime

import psycopg
from flask import Flask, flash, g, redirect, render_template, request, url_for
from psycopg import errors
from psycopg.rows import dict_row

from config import DB_AYARLARI

app = Flask(__name__)
app.secret_key = "espor-turnuva-vtys-2026"


# ---------------------------------------------------------------------
#  Veritabanı yardımcıları
# ---------------------------------------------------------------------
def baglanti():
    if "db" not in g:
        g.db = psycopg.connect(**DB_AYARLARI, row_factory=dict_row)
    return g.db


@app.teardown_appcontext
def baglanti_kapat(_hata):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def sorgu(sql, parametreler=None):
    return baglanti().execute(sql, parametreler).fetchall()


def tek(sql, parametreler=None):
    return baglanti().execute(sql, parametreler).fetchone()


def calistir(sql, parametreler=None):
    """Değişiklik yapan bir komutu çalıştırır ve onaylar (commit)."""
    db = baglanti()
    try:
        sonuc = db.execute(sql, parametreler)
        satir = sonuc.fetchone() if sonuc.description else None
        db.commit()
        return satir
    except psycopg.Error:
        db.rollback()
        raise


def hata_mesaji(hata):
    """Veritabanından gelen hatayı kullanıcıya gösterilecek metne çevirir."""
    mesaj = hata.diag.message_primary or str(hata)
    if isinstance(hata, errors.RaiseException):
        return mesaj  # tetikleyici / fonksiyonlardan gelen iş kuralı mesajı
    if isinstance(hata, errors.ForeignKeyViolation):
        return "Bu kayıt başka kayıtlarla ilişkili olduğu için işlem yapılamadı (örneğin maç oynamış bir takım silinemez)."
    if isinstance(hata, errors.UniqueViolation):
        return "Aynı bilgilerle kayıtlı başka bir kayıt var: " + (hata.diag.message_detail or mesaj)
    if isinstance(hata, errors.CheckViolation):
        return f"Girilen değerler kurallara uymuyor ({hata.diag.constraint_name})."
    if isinstance(hata, errors.NotNullViolation):
        return f"Zorunlu alan boş bırakılamaz ({hata.diag.column_name})."
    return mesaj


def donus_adresi(varsayilan):
    """Formdan gelen dönüş adresini yalnızca site içi bir yol ise kullanır."""
    adres = request.form.get("donus") or ""
    return adres if adres.startswith("/") and not adres.startswith("//") else varsayilan


def bos_ise_none(deger):
    deger = (deger or "").strip()
    return deger or None


# ---------------------------------------------------------------------
#  Şablon filtreleri
# ---------------------------------------------------------------------
@app.template_filter("tarih")
def tarih_filtresi(d):
    if isinstance(d, datetime):
        return d.strftime("%d.%m.%Y %H:%M")
    if isinstance(d, date):
        return d.strftime("%d.%m.%Y")
    return d or "-"


@app.template_filter("para")
def para_filtresi(tutar):
    if tutar is None:
        return "-"
    return f"{tutar:,.0f} ₺".replace(",", ".")


@app.template_filter("html_tarih")
def html_tarih_filtresi(d):
    if isinstance(d, datetime):
        return d.strftime("%Y-%m-%dT%H:%M")
    if isinstance(d, date):
        return d.isoformat()
    return d or ""


@app.context_processor
def ortak_degiskenler():
    return {"bugun": date.today()}


# ---------------------------------------------------------------------
#  ANA SAYFA
# ---------------------------------------------------------------------
@app.route("/")
def ana_sayfa():
    sayilar = tek("""
        SELECT (SELECT count(*) FROM oyuncu)                         AS oyuncu,
               (SELECT count(*) FROM takim)                          AS takim,
               (SELECT count(*) FROM turnuva)                        AS turnuva,
               (SELECT count(*) FROM mac WHERE durum = 'Oynandı')    AS mac,
               (SELECT COALESCE(sum(odul_havuzu), 0) FROM turnuva)   AS odul
    """)
    devam_eden = sorgu("""
        SELECT t.turnuva_id, t.turnuva_adi, o.oyun_adi, t.durum, t.bitis_tarihi, t.odul_havuzu
          FROM turnuva t JOIN oyun o ON o.oyun_id = t.oyun_id
         WHERE t.durum <> 'Tamamlandı'
         ORDER BY t.baslangic_tarihi
    """)
    son_maclar = sorgu("""
        SELECT m.mac_id, m.mac_zamani, tr.turnuva_adi, t1.kisa_ad AS t1, t2.kisa_ad AS t2,
               m.takim1_skor, m.takim2_skor, m.kazanan_id, m.takim1_id, m.takim2_id
          FROM mac m
          JOIN turnuva tr ON tr.turnuva_id = m.turnuva_id
          JOIN takim t1 ON t1.takim_id = m.takim1_id
          JOIN takim t2 ON t2.takim_id = m.takim2_id
         WHERE m.durum = 'Oynandı'
         ORDER BY m.mac_zamani DESC LIMIT 5
    """)
    yaklasan = sorgu("""
        SELECT m.mac_id, m.mac_zamani, tr.turnuva_adi, t1.kisa_ad AS t1, t2.kisa_ad AS t2
          FROM mac m
          JOIN turnuva tr ON tr.turnuva_id = m.turnuva_id
          JOIN takim t1 ON t1.takim_id = m.takim1_id
          JOIN takim t2 ON t2.takim_id = m.takim2_id
         WHERE m.durum = 'Planlandı'
         ORDER BY m.mac_zamani LIMIT 5
    """)
    en_iyiler = sorgu("SELECT * FROM oyuncu_ara('') LIMIT 5")
    return render_template("index.html", sayilar=sayilar, devam_eden=devam_eden,
                           son_maclar=son_maclar, yaklasan=yaklasan, en_iyiler=en_iyiler)


# ---------------------------------------------------------------------
#  OYUNCULAR
# ---------------------------------------------------------------------
def ulkeler():
    return sorgu("SELECT ulke_id, ulke_adi FROM ulke ORDER BY ulke_adi")


def oyuncu_form_degerleri(form):
    return (form["ad"].strip(), form["soyad"].strip(), form["eposta"].strip(),
            form["dogum_tarihi"], int(form["ulke_id"]), form["takma_ad"].strip(),
            int(form.get("elo_puani") or 1000))


@app.route("/oyuncular")
def oyuncular():
    aranan = request.args.get("q", "").strip()
    kayitlar = sorgu("SELECT * FROM oyuncu_ara(%s)", (aranan,))
    return render_template("oyuncular.html", kayitlar=kayitlar, aranan=aranan)


@app.route("/oyuncular/yeni", methods=["GET", "POST"])
def oyuncu_ekle():
    takimlar = sorgu("""SELECT t.takim_id, t.takim_adi, o.oyun_adi FROM takim t
                        JOIN oyun o ON o.oyun_id = t.oyun_id ORDER BY t.takim_adi""")
    if request.method == "POST":
        db = baglanti()
        try:
            yeni_id = db.execute(
                "SELECT oyuncu_ekle(%s, %s, %s, %s, %s, %s, %s) AS id",
                oyuncu_form_degerleri(request.form)).fetchone()["id"]
            takim_id = bos_ise_none(request.form.get("takim_id"))
            if takim_id:
                db.execute("CALL oyuncu_transfer(%s, %s, %s)",
                           (yeni_id, int(takim_id), request.form.get("rol") or "Oyuncu"))
            db.commit()
            flash(f"{request.form['takma_ad']} adlı oyuncu eklendi.", "basari")
            return redirect(url_for("oyuncu_detay", oyuncu_id=yeni_id))
        except psycopg.Error as e:
            db.rollback()
            flash(hata_mesaji(e), "hata")
    return render_template("oyuncu_form.html", deger=request.form, ulkeler=ulkeler(),
                           takimlar=takimlar, yeni=True)


@app.route("/oyuncular/<int:oyuncu_id>")
def oyuncu_detay(oyuncu_id):
    oyuncu = tek("""
        SELECT k.*, o.takma_ad, o.elo_puani, u.ulke_adi,
               date_part('year', age(k.dogum_tarihi))::INT AS yas
          FROM oyuncu o JOIN kisi k ON k.kisi_id = o.kisi_id
          JOIN ulke u ON u.ulke_id = k.ulke_id
         WHERE o.kisi_id = %s""", (oyuncu_id,))
    if not oyuncu:
        flash("Oyuncu bulunamadı.", "hata")
        return redirect(url_for("oyuncular"))
    istatistik = tek("SELECT * FROM oyuncu_istatistik(%s)", (oyuncu_id,))
    kadro = sorgu("""
        SELECT ko.*, t.takim_adi FROM takim_oyuncu ko JOIN takim t ON t.takim_id = ko.takim_id
         WHERE ko.oyuncu_id = %s ORDER BY ko.katilma_tarihi DESC""", (oyuncu_id,))
    maclar = sorgu("""
        SELECT s.*, m.mac_zamani, m.kazanan_id, tr.turnuva_adi,
               t1.kisa_ad AS t1, t2.kisa_ad AS t2, m.takim1_skor, m.takim2_skor
          FROM oyuncu_mac_istatistik s
          JOIN mac m ON m.mac_id = s.mac_id
          JOIN turnuva tr ON tr.turnuva_id = m.turnuva_id
          JOIN takim t1 ON t1.takim_id = m.takim1_id
          JOIN takim t2 ON t2.takim_id = m.takim2_id
         WHERE s.oyuncu_id = %s ORDER BY m.mac_zamani DESC""", (oyuncu_id,))
    takimlar = sorgu("""SELECT t.takim_id, t.takim_adi, o.oyun_adi FROM takim t
                        JOIN oyun o ON o.oyun_id = t.oyun_id ORDER BY t.takim_adi""")
    return render_template("oyuncu_detay.html", oyuncu=oyuncu, istatistik=istatistik,
                           kadro=kadro, maclar=maclar, takimlar=takimlar)


@app.route("/oyuncular/<int:oyuncu_id>/duzenle", methods=["GET", "POST"])
def oyuncu_duzenle(oyuncu_id):
    if request.method == "POST":
        try:
            calistir("CALL oyuncu_guncelle(%s, %s, %s, %s, %s, %s, %s, %s)",
                     (oyuncu_id, *oyuncu_form_degerleri(request.form)))
            flash("Oyuncu bilgileri güncellendi.", "basari")
            return redirect(url_for("oyuncu_detay", oyuncu_id=oyuncu_id))
        except psycopg.Error as e:
            flash(hata_mesaji(e), "hata")
        deger = request.form
    else:
        deger = tek("""SELECT k.*, o.takma_ad, o.elo_puani FROM oyuncu o
                       JOIN kisi k ON k.kisi_id = o.kisi_id WHERE o.kisi_id = %s""", (oyuncu_id,))
        if not deger:
            flash("Oyuncu bulunamadı.", "hata")
            return redirect(url_for("oyuncular"))
        deger = {**deger, "dogum_tarihi": deger["dogum_tarihi"].isoformat()}
    return render_template("oyuncu_form.html", deger=deger, ulkeler=ulkeler(),
                           oyuncu_id=oyuncu_id, yeni=False)


@app.route("/oyuncular/<int:oyuncu_id>/sil", methods=["POST"])
def oyuncu_sil(oyuncu_id):
    try:
        silinen = calistir("""DELETE FROM kisi WHERE kisi_id = %s AND kisi_turu = 'O'
                              RETURNING ad || ' ' || soyad AS ad""", (oyuncu_id,))
        if silinen:
            flash(f"{silinen['ad']} silindi.", "basari")
        else:
            flash("Silinecek oyuncu bulunamadı.", "hata")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("oyuncular"))


@app.route("/oyuncular/<int:oyuncu_id>/transfer", methods=["POST"])
def oyuncu_transfer(oyuncu_id):
    takim_id = bos_ise_none(request.form.get("takim_id"))
    try:
        calistir("CALL oyuncu_transfer(%s, %s, %s)",
                 (oyuncu_id, int(takim_id) if takim_id else None, request.form.get("rol") or "Oyuncu"))
        flash("Transfer işlemi tamamlandı." if takim_id else "Oyuncu serbest bırakıldı.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(donus_adresi(url_for("oyuncu_detay", oyuncu_id=oyuncu_id)))


# ---------------------------------------------------------------------
#  TAKIMLAR
# ---------------------------------------------------------------------
def takim_form_secenekleri(takim_id=None):
    return {
        "oyunlar": sorgu("SELECT oyun_id, oyun_adi FROM oyun ORDER BY oyun_adi"),
        "ulkeler": ulkeler(),
        # takımı olmayan koçlar (+ düzenlenen takımın mevcut koçu)
        "koclar": sorgu("""
            SELECT k.kisi_id, ki.ad || ' ' || ki.soyad AS ad, k.deneyim_yili
              FROM koc k JOIN kisi ki ON ki.kisi_id = k.kisi_id
             WHERE NOT EXISTS (SELECT 1 FROM takim t WHERE t.koc_id = k.kisi_id
                                                       AND t.takim_id IS DISTINCT FROM %s)
             ORDER BY ad""", (takim_id,)),
    }


def takim_form_degerleri(form):
    koc = bos_ise_none(form.get("koc_id"))
    return (form["takim_adi"].strip(), form["kisa_ad"].strip().upper(), int(form["oyun_id"]),
            int(form["ulke_id"]), int(koc) if koc else None, form["kurulus_tarihi"])


@app.route("/takimlar")
def takimlar():
    aranan = request.args.get("q", "").strip()
    oyun_id = bos_ise_none(request.args.get("oyun_id"))
    kayitlar = sorgu("""
        SELECT t.takim_id, t.takim_adi, t.kisa_ad, o.oyun_adi, u.ulke_adi,
               ki.ad || ' ' || ki.soyad AS koc,
               (SELECT count(*) FROM takim_oyuncu ko
                 WHERE ko.takim_id = t.takim_id AND ko.ayrilma_tarihi IS NULL) AS oyuncu_sayisi,
               (SELECT count(*) FROM odul od WHERE od.takim_id = t.takim_id) AS odul_sayisi
          FROM takim t
          JOIN oyun o ON o.oyun_id = t.oyun_id
          JOIN ulke u ON u.ulke_id = t.ulke_id
          LEFT JOIN kisi ki ON ki.kisi_id = t.koc_id
         WHERE (t.takim_adi ILIKE %(q)s OR t.kisa_ad ILIKE %(q)s)
           AND (%(oyun)s::INT IS NULL OR t.oyun_id = %(oyun)s::INT)
         ORDER BY t.takim_adi""", {"q": f"%{aranan}%", "oyun": oyun_id})
    oyunlar = sorgu("SELECT oyun_id, oyun_adi FROM oyun ORDER BY oyun_adi")
    return render_template("takimlar.html", kayitlar=kayitlar, aranan=aranan,
                           oyunlar=oyunlar, secili_oyun=oyun_id)


@app.route("/takimlar/yeni", methods=["GET", "POST"])
def takim_ekle():
    if request.method == "POST":
        try:
            yeni = calistir("""INSERT INTO takim (takim_adi, kisa_ad, oyun_id, ulke_id, koc_id, kurulus_tarihi)
                               VALUES (%s, %s, %s, %s, %s, %s) RETURNING takim_id""",
                            takim_form_degerleri(request.form))
            flash("Takım eklendi.", "basari")
            return redirect(url_for("takim_detay", takim_id=yeni["takim_id"]))
        except psycopg.Error as e:
            flash(hata_mesaji(e), "hata")
    return render_template("takim_form.html", deger=request.form, yeni=True, **takim_form_secenekleri())


@app.route("/takimlar/<int:takim_id>")
def takim_detay(takim_id):
    takim = tek("""
        SELECT t.*, o.oyun_adi, o.takim_boyutu, u.ulke_adi, ki.ad || ' ' || ki.soyad AS koc,
               k.deneyim_yili
          FROM takim t JOIN oyun o ON o.oyun_id = t.oyun_id
          JOIN ulke u ON u.ulke_id = t.ulke_id
          LEFT JOIN koc k ON k.kisi_id = t.koc_id
          LEFT JOIN kisi ki ON ki.kisi_id = t.koc_id
         WHERE t.takim_id = %s""", (takim_id,))
    if not takim:
        flash("Takım bulunamadı.", "hata")
        return redirect(url_for("takimlar"))
    kadro = sorgu("""
        SELECT ko.*, o.takma_ad, ki.ad || ' ' || ki.soyad AS ad_soyad, o.elo_puani
          FROM takim_oyuncu ko JOIN oyuncu o ON o.kisi_id = ko.oyuncu_id
          JOIN kisi ki ON ki.kisi_id = ko.oyuncu_id
         WHERE ko.takim_id = %s
         ORDER BY ko.ayrilma_tarihi NULLS FIRST, ko.kaptan DESC, ko.katilma_tarihi""", (takim_id,))
    sponsorlar = sorgu("""
        SELECT s.sponsor_adi, s.sektor, ts.baslangic, ts.bitis, ts.yillik_tutar
          FROM takim_sponsor ts JOIN sponsor s ON s.sponsor_id = ts.sponsor_id
         WHERE ts.takim_id = %s ORDER BY ts.yillik_tutar DESC""", (takim_id,))
    turnuvalar = sorgu("""
        SELECT tr.turnuva_id, tr.turnuva_adi, tr.durum, tk.galibiyet, tk.maglubiyet, tk.puan, tk.sira,
               od.tutar AS odul
          FROM turnuva_katilim tk JOIN turnuva tr ON tr.turnuva_id = tk.turnuva_id
          LEFT JOIN odul od ON od.turnuva_id = tk.turnuva_id AND od.takim_id = tk.takim_id
         WHERE tk.takim_id = %s ORDER BY tr.baslangic_tarihi DESC""", (takim_id,))
    serbest_oyuncular = sorgu("""
        SELECT o.kisi_id, o.takma_ad FROM oyuncu o
         WHERE NOT EXISTS (SELECT 1 FROM takim_oyuncu ko
                            WHERE ko.oyuncu_id = o.kisi_id AND ko.ayrilma_tarihi IS NULL)
         ORDER BY o.takma_ad""")
    return render_template("takim_detay.html", takim=takim, kadro=kadro, sponsorlar=sponsorlar,
                           turnuvalar=turnuvalar, serbest_oyuncular=serbest_oyuncular)


@app.route("/takimlar/<int:takim_id>/duzenle", methods=["GET", "POST"])
def takim_duzenle(takim_id):
    if request.method == "POST":
        try:
            calistir("""UPDATE takim SET takim_adi = %s, kisa_ad = %s, oyun_id = %s, ulke_id = %s,
                               koc_id = %s, kurulus_tarihi = %s
                         WHERE takim_id = %s""", (*takim_form_degerleri(request.form), takim_id))
            flash("Takım bilgileri güncellendi.", "basari")
            return redirect(url_for("takim_detay", takim_id=takim_id))
        except psycopg.Error as e:
            flash(hata_mesaji(e), "hata")
        deger = request.form
    else:
        deger = tek("SELECT * FROM takim WHERE takim_id = %s", (takim_id,))
        if not deger:
            return redirect(url_for("takimlar"))
        deger = {**deger, "kurulus_tarihi": deger["kurulus_tarihi"].isoformat()}
    return render_template("takim_form.html", deger=deger, yeni=False, takim_id=takim_id,
                           **takim_form_secenekleri(takim_id))


@app.route("/takimlar/<int:takim_id>/sil", methods=["POST"])
def takim_sil(takim_id):
    try:
        silinen = calistir("DELETE FROM takim WHERE takim_id = %s RETURNING takim_adi", (takim_id,))
        if silinen:
            flash(f"{silinen['takim_adi']} silindi.", "basari")
            return redirect(url_for("takimlar"))
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("takim_detay", takim_id=takim_id))


@app.route("/takimlar/<int:takim_id>/kadro", methods=["POST"])
def kadro_ekle(takim_id):
    try:
        calistir("CALL oyuncu_transfer(%s, %s, %s)",
                 (int(request.form["oyuncu_id"]), takim_id, request.form.get("rol") or "Oyuncu"))
        flash("Oyuncu kadroya eklendi.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("takim_detay", takim_id=takim_id))


@app.route("/takimlar/<int:takim_id>/kaptan/<int:kadro_id>", methods=["POST"])
def kaptan_yap(takim_id, kadro_id):
    try:
        calistir("UPDATE takim_oyuncu SET kaptan = TRUE WHERE kadro_id = %s AND takim_id = %s",
                 (kadro_id, takim_id))
        flash("Kaptan değiştirildi.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("takim_detay", takim_id=takim_id))


# ---------------------------------------------------------------------
#  TURNUVALAR
# ---------------------------------------------------------------------
TURNUVA_DETAY_SQL = """
    SELECT t.*, o.oyun_adi, o.takim_boyutu,
           ot.yayin_platformu, ot.sunucu_bolgesi,
           st.mekan_id, st.bilet_fiyati, m.mekan_adi, m.sehir, m.kapasite,
           (SELECT count(*) FROM turnuva_katilim tk WHERE tk.turnuva_id = t.turnuva_id) AS takim_sayisi
      FROM turnuva t
      JOIN oyun o ON o.oyun_id = t.oyun_id
      LEFT JOIN online_turnuva ot ON ot.turnuva_id = t.turnuva_id
      LEFT JOIN salon_turnuva  st ON st.turnuva_id = t.turnuva_id
      LEFT JOIN mekan m           ON m.mekan_id   = st.mekan_id
"""


def turnuva_form_secenekleri():
    return {
        "oyunlar": sorgu("SELECT oyun_id, oyun_adi FROM oyun ORDER BY oyun_adi"),
        "mekanlar": sorgu("SELECT mekan_id, mekan_adi, sehir, kapasite FROM mekan ORDER BY mekan_adi"),
    }


@app.route("/turnuvalar")
def turnuvalar():
    aranan = request.args.get("q", "").strip()
    durum = bos_ise_none(request.args.get("durum"))
    kayitlar = sorgu(TURNUVA_DETAY_SQL + """
         WHERE t.turnuva_adi ILIKE %(q)s
           AND (%(durum)s::VARCHAR IS NULL OR t.durum = %(durum)s::VARCHAR)
         ORDER BY t.baslangic_tarihi DESC""", {"q": f"%{aranan}%", "durum": durum})
    return render_template("turnuvalar.html", kayitlar=kayitlar, aranan=aranan, secili_durum=durum)


@app.route("/turnuvalar/yeni", methods=["GET", "POST"])
def turnuva_ekle():
    if request.method == "POST":
        f = request.form
        try:
            mekan = bos_ise_none(f.get("mekan_id"))
            yeni = calistir(
                "SELECT turnuva_olustur(%s, %s, %s, %s, %s, %s::SMALLINT, %s, %s, %s, %s, %s) AS id",
                (f["turnuva_adi"].strip(), int(f["oyun_id"]), f["baslangic_tarihi"], f["bitis_tarihi"],
                 f["odul_havuzu"] or 0, int(f["max_takim"]), f["turnuva_turu"],
                 bos_ise_none(f.get("yayin_platformu")), bos_ise_none(f.get("sunucu_bolgesi")),
                 int(mekan) if mekan else None, f.get("bilet_fiyati") or 0))
            flash("Turnuva oluşturuldu.", "basari")
            return redirect(url_for("turnuva_detay", turnuva_id=yeni["id"]))
        except psycopg.Error as e:
            flash(hata_mesaji(e), "hata")
    return render_template("turnuva_form.html", deger=request.form, yeni=True, **turnuva_form_secenekleri())


@app.route("/turnuvalar/<int:turnuva_id>")
def turnuva_detay(turnuva_id):
    turnuva = tek(TURNUVA_DETAY_SQL + " WHERE t.turnuva_id = %s", (turnuva_id,))
    if not turnuva:
        flash("Turnuva bulunamadı.", "hata")
        return redirect(url_for("turnuvalar"))
    puan_tablosu = sorgu("SELECT * FROM puan_tablosu(%s)", (turnuva_id,))
    maclar = sorgu("""
        SELECT m.*, a.asama_adi, t1.takim_adi AS t1_adi, t2.takim_adi AS t2_adi,
               ki.ad || ' ' || ki.soyad AS hakem
          FROM mac m JOIN asama a ON a.asama_id = m.asama_id
          JOIN takim t1 ON t1.takim_id = m.takim1_id
          JOIN takim t2 ON t2.takim_id = m.takim2_id
          LEFT JOIN kisi ki ON ki.kisi_id = m.hakem_id
         WHERE m.turnuva_id = %s ORDER BY m.mac_zamani""", (turnuva_id,))
    oduller = sorgu("""
        SELECT od.*, t.takim_adi FROM odul od LEFT JOIN takim t ON t.takim_id = od.takim_id
         WHERE od.turnuva_id = %s ORDER BY od.derece""", (turnuva_id,))
    kayit_olabilir = sorgu("""
        SELECT t.takim_id, t.takim_adi FROM takim t
         WHERE t.oyun_id = %s
           AND NOT EXISTS (SELECT 1 FROM turnuva_katilim tk
                            WHERE tk.turnuva_id = %s AND tk.takim_id = t.takim_id)
         ORDER BY t.takim_adi""", (turnuva["oyun_id"], turnuva_id))
    return render_template("turnuva_detay.html", turnuva=turnuva, puan_tablosu=puan_tablosu,
                           maclar=maclar, oduller=oduller, kayit_olabilir=kayit_olabilir)


@app.route("/turnuvalar/<int:turnuva_id>/duzenle", methods=["GET", "POST"])
def turnuva_duzenle(turnuva_id):
    turnuva = tek(TURNUVA_DETAY_SQL + " WHERE t.turnuva_id = %s", (turnuva_id,))
    if not turnuva:
        return redirect(url_for("turnuvalar"))
    if request.method == "POST":
        f = request.form
        db = baglanti()
        try:
            db.execute("""UPDATE turnuva SET turnuva_adi = %s, baslangic_tarihi = %s, bitis_tarihi = %s,
                                 odul_havuzu = %s, max_takim = %s
                           WHERE turnuva_id = %s""",
                       (f["turnuva_adi"].strip(), f["baslangic_tarihi"], f["bitis_tarihi"],
                        f["odul_havuzu"] or 0, int(f["max_takim"]), turnuva_id))
            if turnuva["turnuva_turu"] == "O":
                db.execute("""UPDATE online_turnuva SET yayin_platformu = %s, sunucu_bolgesi = %s
                               WHERE turnuva_id = %s""",
                           (f["yayin_platformu"].strip(), f["sunucu_bolgesi"].strip(), turnuva_id))
            else:
                db.execute("""UPDATE salon_turnuva SET mekan_id = %s, bilet_fiyati = %s
                               WHERE turnuva_id = %s""",
                           (int(f["mekan_id"]), f.get("bilet_fiyati") or 0, turnuva_id))
            db.commit()
            flash("Turnuva güncellendi.", "basari")
            return redirect(url_for("turnuva_detay", turnuva_id=turnuva_id))
        except psycopg.Error as e:
            db.rollback()
            flash(hata_mesaji(e), "hata")
        deger = {**turnuva, **f.to_dict()}
    else:
        deger = {**turnuva,
                 "baslangic_tarihi": turnuva["baslangic_tarihi"].isoformat(),
                 "bitis_tarihi": turnuva["bitis_tarihi"].isoformat()}
    return render_template("turnuva_form.html", deger=deger, yeni=False, turnuva_id=turnuva_id,
                           **turnuva_form_secenekleri())


@app.route("/turnuvalar/<int:turnuva_id>/sil", methods=["POST"])
def turnuva_sil(turnuva_id):
    try:
        silinen = calistir("DELETE FROM turnuva WHERE turnuva_id = %s RETURNING turnuva_adi", (turnuva_id,))
        if silinen:
            flash(f"{silinen['turnuva_adi']} silindi.", "basari")
            return redirect(url_for("turnuvalar"))
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("turnuva_detay", turnuva_id=turnuva_id))


@app.route("/turnuvalar/<int:turnuva_id>/katilim", methods=["POST"])
def katilim_ekle(turnuva_id):
    try:
        calistir("INSERT INTO turnuva_katilim (turnuva_id, takim_id) VALUES (%s, %s)",
                 (turnuva_id, int(request.form["takim_id"])))
        flash("Takım turnuvaya kaydedildi.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("turnuva_detay", turnuva_id=turnuva_id))


@app.route("/turnuvalar/<int:turnuva_id>/katilim/<int:takim_id>/sil", methods=["POST"])
def katilim_sil(turnuva_id, takim_id):
    try:
        durum = tek("SELECT durum FROM turnuva WHERE turnuva_id = %s", (turnuva_id,))
        if durum and durum["durum"] != "Kayıt Açık":
            flash("Kayıt dönemi bittiği için takım turnuvadan çıkarılamaz.", "hata")
        else:
            calistir("DELETE FROM turnuva_katilim WHERE turnuva_id = %s AND takim_id = %s",
                     (turnuva_id, takim_id))
            flash("Takımın turnuva kaydı silindi.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("turnuva_detay", turnuva_id=turnuva_id))


@app.route("/turnuvalar/<int:turnuva_id>/fikstur", methods=["POST"])
def fikstur(turnuva_id):
    try:
        sonuc = calistir("SELECT fikstur_olustur(%s, %s, %s::INTERVAL) AS adet",
                         (turnuva_id, request.form["ilk_mac"], request.form.get("aralik") or "1 day"))
        flash(f"Fikstür oluşturuldu: {sonuc['adet']} maç planlandı. Turnuva başladı.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("turnuva_detay", turnuva_id=turnuva_id))


@app.route("/turnuvalar/<int:turnuva_id>/tamamla", methods=["POST"])
def turnuva_tamamla(turnuva_id):
    try:
        calistir("UPDATE turnuva SET durum = 'Tamamlandı' WHERE turnuva_id = %s", (turnuva_id,))
        flash("Turnuva tamamlandı; sıralama ve ödüller belirlendi.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("turnuva_detay", turnuva_id=turnuva_id))


@app.route("/turnuvalar/<int:turnuva_id>/odul", methods=["POST"])
def odul_ekle(turnuva_id):
    try:
        calistir("INSERT INTO odul (turnuva_id, derece, tutar) VALUES (%s, %s, %s)",
                 (turnuva_id, int(request.form["derece"]), request.form["tutar"]))
        flash("Ödül eklendi.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("turnuva_detay", turnuva_id=turnuva_id))


@app.route("/turnuvalar/<int:turnuva_id>/odul/<int:odul_id>/sil", methods=["POST"])
def odul_sil(turnuva_id, odul_id):
    try:
        calistir("DELETE FROM odul WHERE odul_id = %s AND turnuva_id = %s", (odul_id, turnuva_id))
        flash("Ödül silindi.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("turnuva_detay", turnuva_id=turnuva_id))


# ---------------------------------------------------------------------
#  MAÇLAR
# ---------------------------------------------------------------------
@app.route("/maclar/<int:mac_id>")
def mac_detay(mac_id):
    mac = tek("""
        SELECT m.*, a.asama_adi, tr.turnuva_adi, t1.takim_adi AS t1_adi, t2.takim_adi AS t2_adi,
               ki.ad || ' ' || ki.soyad AS hakem
          FROM mac m JOIN asama a ON a.asama_id = m.asama_id
          JOIN turnuva tr ON tr.turnuva_id = m.turnuva_id
          JOIN takim t1 ON t1.takim_id = m.takim1_id
          JOIN takim t2 ON t2.takim_id = m.takim2_id
          LEFT JOIN kisi ki ON ki.kisi_id = m.hakem_id
         WHERE m.mac_id = %s""", (mac_id,))
    if not mac:
        flash("Maç bulunamadı.", "hata")
        return redirect(url_for("turnuvalar"))
    istatistikler = sorgu("""
        SELECT s.*, o.takma_ad, t.kisa_ad,
               round((s.oldurme + s.asist)::NUMERIC / GREATEST(s.olum, 1), 2) AS kda
          FROM oyuncu_mac_istatistik s
          JOIN oyuncu o ON o.kisi_id = s.oyuncu_id
          JOIN takim t ON t.takim_id = s.takim_id
         WHERE s.mac_id = %s
         ORDER BY s.takim_id = %s DESC, s.oldurme DESC""", (mac_id, mac["takim1_id"]))
    oyuncular = sorgu("""
        SELECT o.kisi_id, o.takma_ad, t.kisa_ad FROM takim_oyuncu ko
          JOIN oyuncu o ON o.kisi_id = ko.oyuncu_id
          JOIN takim t ON t.takim_id = ko.takim_id
         WHERE ko.takim_id IN (%s, %s) AND ko.ayrilma_tarihi IS NULL
           AND NOT EXISTS (SELECT 1 FROM oyuncu_mac_istatistik s
                            WHERE s.mac_id = %s AND s.oyuncu_id = o.kisi_id)
         ORDER BY t.kisa_ad, o.takma_ad""", (mac["takim1_id"], mac["takim2_id"], mac_id))
    return render_template("mac_detay.html", mac=mac, istatistikler=istatistikler, oyuncular=oyuncular)


@app.route("/maclar/<int:mac_id>/sonuc", methods=["POST"])
def mac_sonuc(mac_id):
    try:
        calistir("CALL mac_sonucu_gir(%s, %s::SMALLINT, %s::SMALLINT)",
                 (mac_id, int(request.form["skor1"]), int(request.form["skor2"])))
        flash("Maç sonucu kaydedildi; puan tablosu güncellendi.", "basari")
    except (psycopg.Error, ValueError) as e:
        flash(hata_mesaji(e) if isinstance(e, psycopg.Error) else "Skorlar sayı olmalıdır.", "hata")
    return redirect(donus_adresi(url_for("mac_detay", mac_id=mac_id)))


@app.route("/maclar/<int:mac_id>/istatistik", methods=["POST"])
def istatistik_ekle(mac_id):
    f = request.form
    try:
        calistir("""INSERT INTO oyuncu_mac_istatistik (mac_id, oyuncu_id, oldurme, olum, asist, mvp)
                    VALUES (%s, %s, %s, %s, %s, %s)""",
                 (mac_id, int(f["oyuncu_id"]), int(f["oldurme"]), int(f["olum"]), int(f["asist"]),
                  "mvp" in f))
        flash("Oyuncu istatistiği eklendi.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("mac_detay", mac_id=mac_id))


@app.route("/maclar/<int:mac_id>/istatistik/<int:istatistik_id>/sil", methods=["POST"])
def istatistik_sil(mac_id, istatistik_id):
    try:
        calistir("DELETE FROM oyuncu_mac_istatistik WHERE istatistik_id = %s AND mac_id = %s",
                 (istatistik_id, mac_id))
        flash("İstatistik silindi.", "basari")
    except psycopg.Error as e:
        flash(hata_mesaji(e), "hata")
    return redirect(url_for("mac_detay", mac_id=mac_id))


# ---------------------------------------------------------------------
#  İŞLEM GÜNLÜĞÜ
# ---------------------------------------------------------------------
@app.route("/islem-gunlugu")
def islem_gunlugu():
    tablo = bos_ise_none(request.args.get("tablo"))
    kayitlar = sorgu("""
        SELECT * FROM islem_log
         WHERE %(tablo)s::VARCHAR IS NULL OR tablo_adi = %(tablo)s::VARCHAR
         ORDER BY log_id DESC LIMIT 100""", {"tablo": tablo})
    return render_template("islem_gunlugu.html", kayitlar=kayitlar, secili_tablo=tablo)


if __name__ == "__main__":
    app.run(debug=True)
