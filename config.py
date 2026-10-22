import os

# PostgreSQL bağlantı bilgileri. Kendi kurulumunuza göre düzenleyin
# ya da aynı isimli ortam değişkenlerini tanımlayın.
DB_AYARLARI = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": int(os.environ.get("PGPORT", "5432")),
    "user": os.environ.get("PGUSER", "postgres"),
    "password": os.environ.get("PGPASSWORD", "postgres"),
    "dbname": os.environ.get("ESPOR_DB", "espor_turnuva"),
}
