import importlib.util, subprocess, sys

PKGS = {"fastembed": "fastembed", "pg8000": "pg8000"}


# Pip-install missing Python packages
def ensure_deps():
    missing = [p for m, p in PKGS.items() if not importlib.util.find_spec(m)]
    if missing:
        subprocess.check_call([sys.executable, "-m", "pip", "install", *missing])
