import shutil, subprocess, sys

INSTALL_FFMPEG = {"windows": ["winget", "install", "-e", "Gyan.FFmpeg"], "mac": ["brew", "install", "ffmpeg"]}


# Install ffmpeg for host os if missing
def ensure_ffmpeg(os):
    if not shutil.which("ffmpeg"):
        subprocess.call(INSTALL_FFMPEG[os])
        sys.exit("ffmpeg installed; open a new terminal and rerun")
