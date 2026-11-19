"""Convert a .docx to Markdown.
Usage: python scripts/docx_to_md.py --input-abs-path <abs .docx> --output-abs-path <abs .md>"""
import argparse
from pathlib import Path

from docx import Document

def runs_md(p):
    out = []
    for r in p.runs:
        t = r.text
        if not t.strip():
            out.append(t)
            continue
        mark = "***" if r.bold and r.italic else "**" if r.bold else "*" if r.italic else ""
        if mark:
            lead, core = t[: len(t) - len(t.lstrip())], t.strip()
            trail = t[len(t.rstrip()):] or " "
            t = f"{lead}{mark}{core}{mark}{trail}"
        out.append(t)
    return "".join(out).strip()


def para_md(p):
    text = runs_md(p)
    if not text:
        return ""
    style = (p.style.name or "").lower()
    if style.startswith("heading"):
        lvl = "".join(c for c in style if c.isdigit()) or "1"
        return "#" * int(lvl) + " " + p.text.strip()
    if style == "title":
        return "# " + p.text.strip()
    numbered = p._p.pPr is not None and p._p.pPr.numPr is not None
    if "list" in style or numbered:
        ilvl = 0
        if numbered and p._p.pPr.numPr.ilvl is not None:
            ilvl = int(p._p.pPr.numPr.ilvl.val)
        mark = "1." if "number" in style else "-"
        return "  " * ilvl + f"{mark} {text}"
    return text


def table_md(t):
    rows = [[c.text.strip().replace("\n", " ").replace("|", "\\|") for c in r.cells] for r in t.rows]
    if not rows:
        return ""
    lines = ["| " + " | ".join(rows[0]) + " |", "|" + "---|" * len(rows[0])]
    lines += ["| " + " | ".join(r) + " |" for r in rows[1:]]
    return "\n".join(lines)


def convert(src: Path) -> str:
    doc = Document(src)
    blocks, prev_list = [], False
    for el in doc.element.body.iterchildren():
        tag = el.tag.rsplit("}", 1)[-1]
        if tag == "p":
            from docx.text.paragraph import Paragraph
            md = para_md(Paragraph(el, doc))
            if not md:
                continue
            is_list = md.lstrip().startswith(("- ", "1. "))
            sep = "\n" if (is_list and prev_list) else "\n\n"
            blocks.append((sep if blocks else "") + md)
            prev_list = is_list
        elif tag == "tbl":
            from docx.table import Table
            blocks.append("\n\n" + table_md(Table(el, doc)))
            prev_list = False
    return "".join(blocks).strip() + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input-abs-path", required=True)
    ap.add_argument("--output-abs-path", required=True)
    a = ap.parse_args()
    src, dst = Path(a.input_abs_path), Path(a.output_abs_path)
    if not (src.is_absolute() and dst.is_absolute()):
        ap.error("paths must be absolute")
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(convert(src), encoding="utf-8")
    print(dst)


if __name__ == "__main__":
    main()
