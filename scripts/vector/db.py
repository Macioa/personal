import os, sys
from pathlib import Path

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


# Connection as the transcriber role
def connect():
    import psycopg
    url = env(ENV)
    if not url:
        sys.exit(f"{ENV} not set in environment or local.env (transcriber role connection string)")
    return psycopg.connect(url)
