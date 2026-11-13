"""Insert one row into public.alive so Supabase sees DB activity and doesn't pause the
free project. The table keeps its newest 5 rows (trigger). Env or local.env:
KEEPALIVE_URL (https://<ref>.supabase.co/rest/v1/alive), KEEPALIVE_KEY (publishable key)."""
import os
import sys
import urllib.request
from pathlib import Path

LOCAL_ENV = Path(__file__).resolve().parents[1] / "local.env"


def env(key):
    if os.environ.get(key):
        return os.environ[key]
    if LOCAL_ENV.exists():
        for line in LOCAL_ENV.read_text(encoding="utf-8").splitlines():
            k, sep, v = line.partition("=")
            if sep and k.strip() == key:
                return v.strip()
    return None


url, key = env("KEEPALIVE_URL"), env("KEEPALIVE_KEY")
if not url or not key:
    sys.exit("KEEPALIVE_URL / KEEPALIVE_KEY not set in environment or local.env")
req = urllib.request.Request(
    url, data=b"{}", method="POST",
    headers={"apikey": key, "Content-Type": "application/json", "Prefer": "return=minimal"},
)
with urllib.request.urlopen(req, timeout=60) as r:
    print(r.status, url)
