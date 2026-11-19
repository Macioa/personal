"""Convert a .pdf to Markdown (text per page).
Usage: python scripts/pdf_to_md.py --input-abs-path <abs .pdf> --output-abs-path <abs .md>"""
import argparse
from pathlib import Path

from pypdf import PdfReader


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input-abs-path", required=True)
    ap.add_argument("--output-abs-path", required=True)
    a = ap.parse_args()
    src, dst = Path(a.input_abs_path), Path(a.output_abs_path)
    if not (src.is_absolute() and dst.is_absolute()):
        ap.error("paths must be absolute")
    dst.parent.mkdir(parents=True, exist_ok=True)
    pages = [(p.extract_text() or "").strip() for p in PdfReader(src).pages]
    dst.write_text("\n\n".join(p for p in pages if p) + "\n", encoding="utf-8")
    print(dst)


if __name__ == "__main__":
    main()
