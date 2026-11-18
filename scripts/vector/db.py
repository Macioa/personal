import contextlib, os, sys
from pathlib import Path
from urllib.parse import urlparse, unquote

ENV = "TRANSCRIBER_DB_URL"  # postgresql://transcriber.<project_ref>:<password>@<pooler-host>:5432/postgres
LOCAL_ENV = Path(__file__).resolve().parents[2] / "local.env"


# Value of key from the environment, else from repo-root local.env
def env(key):
    if os.environ.get(key):
        return os.environ[key]
    if LOCAL_ENV.exists():
        for line in LOCAL_ENV.read_text(encoding="utf-8").splitlines():
            k, sep, v = line.partition("=")
            if sep and k.strip() == key:
                return v.strip()
    return None


# Minimal psycopg-style wrapper over pg8000 (pure Python; no libpq DLL)
class Conn:
    def __init__(self, raw):
        self.raw = raw
    def execute(self, sql, params=()):
        cur = self.raw.cursor()
        cur.execute(sql, params)
        return cur
    def cursor(self):
        return contextlib.closing(self.raw.cursor())
    @contextlib.contextmanager
    def transaction(self):
        try:
            yield
            self.raw.commit()
        except Exception:
            self.raw.rollback()
            raise
    def __enter__(self):
        return self
    def __exit__(self, exc, *_):
        (self.raw.rollback if exc else self.raw.commit)()
        self.raw.close()


# pg8000 connection from a postgresql:// URL (SSL without cert check, like libpq sslmode=require)
def pg_connect(url):
    import pg8000.dbapi, ssl
    u = urlparse(url)
    ctx = ssl.create_default_context()
    ctx.check_hostname, ctx.verify_mode = False, ssl.CERT_NONE
    return Conn(pg8000.dbapi.connect(user=unquote(u.username), password=unquote(u.password or ""),
                                     host=u.hostname, port=u.port or 5432,
                                     database=u.path.lstrip("/") or "postgres", ssl_context=ctx))


# Connection as the transcriber role
def connect():
    url = env(ENV)
    if not url:
        sys.exit(f"{ENV} not set in environment or local.env (transcriber role connection string)")
    return pg_connect(url)
