"""Convert a legacy .doc to Markdown (Word saves a temp .docx, then docx_to_md converts it).
Requires Microsoft Word (Windows).
Usage: python scripts/doc_to_md.py --input-abs-path <abs .doc> --output-abs-path <abs .md>"""
import argparse, subprocess, tempfile
from pathlib import Path

from docx_to_md import convert

PS = """$w = New-Object -ComObject Word.Application
$w.Visible = $false
try {{ $d = $w.Documents.Open('{src}', $false, $true); $d.SaveAs2('{dst}', 16); $d.Close($false) }}
finally {{ $w.Quit() }}"""


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input-abs-path", required=True)
    ap.add_argument("--output-abs-path", required=True)
    a = ap.parse_args()
    src, dst = Path(a.input_abs_path), Path(a.output_abs_path)
    if not (src.is_absolute() and dst.is_absolute()):
        ap.error("paths must be absolute")
    dst.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "tmp.docx"
        q = lambda p: str(p).replace("'", "''")
        subprocess.run(["powershell", "-NoProfile", "-Command", PS.format(src=q(src), dst=q(tmp))], check=True)
        dst.write_text(convert(tmp), encoding="utf-8")
    print(dst)


if __name__ == "__main__":
    main()
