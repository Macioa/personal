"""Shared parser and flowables for the resume template scripts. Input is the md written by scripts/resume_final.py."""
import argparse, os, re, sys
from xml.sax.saxutils import escape
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph, ListFlowable, ListItem, Table, TableStyle, Spacer

LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")
META = re.compile(r"^(.+?) \|(?: (.*))?$")
PHOTO = re.compile(r"^(?:\[)?!\[[^\]]*\]\(([^)\s]+)\)(?:\]\(([^)\s]+)\))?$")


def args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input-abs-path", required=True)
    ap.add_argument("--output-abs-path", required=True)
    a = ap.parse_args()
    for p in (a.input_abs_path, a.output_abs_path):
        if not os.path.isabs(p):
            sys.exit(f"Path must be absolute: {p}")
    return a


def inline(s, link_color):
    s = escape(s)
    s = LINK.sub(lambda m: f'<a href="{m[2]}" color="{link_color}">{m[1]}</a>', s)
    return re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)


def parse(path):
    """-> {name, photo: {url, link} | None, contact: [lines], sections: [{title, blocks}], disclaimer: [lines]}.
    Blocks: h3 {text, dates, where} | p {lines} | ul {items} | table {rows} ."""
    lines = open(path, encoding="utf-8").read().splitlines()
    if lines and lines[0].startswith("Tokens:"):
        lines = lines[1:]
    doc = {"name": "", "photo": None, "contact": [], "sections": [], "disclaimer": []}
    buf, meta_ok = [], False

    def target():
        return doc["sections"][-1]["blocks"] if doc["sections"] else None

    def flush():
        if not buf:
            return
        if all(l.startswith("> ") for l in buf):
            doc["disclaimer"] += [l[2:] for l in buf]
        elif target() is None:
            doc["contact"] += buf
        elif all(l.startswith("- ") for l in buf):
            target().append({"t": "ul", "items": [l[2:] for l in buf]})
        elif all(l.startswith("|") for l in buf):
            rows = [[c.strip() for c in l.strip("|").split("|")] for l in buf]
            rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
            target().append({"t": "table", "head": rows[0], "rows": rows[1:]})
        else:
            target().append({"t": "p", "lines": list(buf)})
        buf.clear()

    for line in lines:
        s = line.rstrip()
        photo = PHOTO.match(s) if not doc["sections"] else None
        if photo:
            flush(); doc["photo"] = {"url": photo[1], "link": photo[2]}; continue
        if s.startswith("# "):
            flush(); doc["name"] = s[2:]; continue
        if s.startswith("## "):
            flush(); doc["sections"].append({"title": s[3:], "blocks": []}); meta_ok = False; continue
        if s.startswith("### "):
            flush(); target().append({"t": "h3", "text": s[4:], "dates": "", "where": ""}); meta_ok = True; continue
        if not s.strip():
            flush(); continue
        if s.strip() == "---":
            flush(); meta_ok = False; continue
        m = META.match(s)
        if meta_ok and not buf and m:
            h = target()[-1]
            h["dates"], h["where"] = m[1], m[2] or ""
        else:
            buf.append(s)
        meta_ok = False
    flush()
    return doc


YEARS = re.compile(r"((?:total )?\d+(?:\.\d+)? yrs)")


def lead_bold(s, link):
    """Bold everything before the first number (and its opening paren), and every `N yrs` / `total N yrs`."""
    m = re.match(r"^(\D*?)(\s*\(?\d.*)$", s)
    head, rest = (m[1], m[2]) if m and m[1] else ("", s)
    rest = YEARS.sub(r"<b>\1</b>", inline(rest, link))
    return f"<b>{inline(head, link)}</b>{rest}" if head else rest


def blocks_to_flow(blocks, st, link, h3, table, bold_lead=False):
    """Generic block renderer. st: body, bullet styles. h3/table: template callbacks returning flowables."""
    out = []
    for b in blocks:
        if b["t"] == "h3":
            out += h3(b)
        elif b["t"] == "p":
            out.append(Paragraph("<br/>".join(inline(l, link) for l in b["lines"]), st["body"]))
        elif b["t"] == "ul":
            out.append(ListFlowable([ListItem(Paragraph(lead_bold(i, link) if bold_lead else inline(i, link), st["bullet"]), leftIndent=10)
                                     for i in b["items"]], bulletType="bullet", start="•",
                                    leftIndent=10, bulletFontSize=st["bullet"].fontSize))
        elif b["t"] == "table":
            out += table(b)
    return out


def grid(cells, cols, width, style_cmds=()):
    """Lay flowable cells out in `cols` columns."""
    rows = [cells[i:i + cols] + [""] * (cols - len(cells[i:i + cols])) for i in range(0, len(cells), cols)]
    t = Table(rows, colWidths=[width / cols] * cols)
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0),
                           ("TOPPADDING", (0, 0), (-1, -1), 1), ("BOTTOMPADDING", (0, 0), (-1, -1), 1)] + list(style_cmds)))
    return t


def source_note(script, link, color="#888888"):
    """Tiny fine print naming the design source from the script's `# Design source: Name, URL` first line."""
    head = open(script, encoding="utf-8").readline().strip()
    name, url = head[len("# Design source: "):].rsplit(", ", 1)
    style = ParagraphStyle("source", fontName="Helvetica", fontSize=5.5, leading=7, textColor=color)
    return [Spacer(1, 6), Paragraph(f'Resume style template source: <a href="{url}" color="{link}">{escape(name)}</a>', style)]
