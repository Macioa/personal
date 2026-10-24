import shutil

from reformat import archive


# Copy src as-is to <dst><suffix>
def copy(src, dst):
    shutil.copy2(src, str(dst) + src.suffix)


BACKUPS = {"windows": archive.compress, "mac": archive.compress, "amr": copy}


# Back up src of type fmt next to transcript
def backup(src, dst, fmt):
    BACKUPS[fmt](src, dst)
