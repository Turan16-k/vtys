"""Veritabanını oluşturur ve sql/ klasöründeki betikleri sırayla çalıştırır.

Kullanım:  python kurulum.py
"""
from pathlib import Path

import psycopg
from psycopg import sql

from config import DB_AYARLARI

SQL_KLASORU = Path(__file__).parent / "sql"
BETIKLER = ["01_tablolar.sql", "02_fonksiyonlar.sql", "03_tetikleyiciler.sql", "04_ornek_veriler.sql"]


def veritabani_olustur():
    ayarlar = {**DB_AYARLARI, "dbname": "postgres"}
    with psycopg.connect(**ayarlar, autocommit=True) as conn:
        var_mi = conn.execute(
            "SELECT 1 FROM pg_database WHERE datname = %s", (DB_AYARLARI["dbname"],)
        ).fetchone()
        if not var_mi:
            conn.execute(
                sql.SQL("CREATE DATABASE {} ENCODING 'UTF8' TEMPLATE template0").format(
                    sql.Identifier(DB_AYARLARI["dbname"])
                )
            )
            print(f"'{DB_AYARLARI['dbname']}' veritabanı oluşturuldu.")


def betikleri_calistir():
    with psycopg.connect(**DB_AYARLARI) as conn:
        for ad in BETIKLER:
            conn.execute((SQL_KLASORU / ad).read_text(encoding="utf-8"))
            print(f"{ad} çalıştırıldı.")
        conn.commit()

    # Raporda tek dosya olarak verilebilmesi için tüm betikler birleştirilir.
    birlesik = "\n\n".join((SQL_KLASORU / ad).read_text(encoding="utf-8") for ad in BETIKLER)
    (SQL_KLASORU / "tum_kurulum.sql").write_text(birlesik, encoding="utf-8")


if __name__ == "__main__":
    veritabani_olustur()
    betikleri_calistir()
    print("Kurulum tamamlandı.")
