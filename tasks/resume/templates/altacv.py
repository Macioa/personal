# Design source: AltaCV, https://github.com/liantze/AltaCV
"""Render a resume md (scripts/resume_final.py format) to PDF in the altacv style (two columns).
Left column: Summary, Work Experience, Projects. Right column: every other section.
Usage: python altacv.py --input-abs-path <md> --output-abs-path <pdf>"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.platypus import BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Table, TableStyle, HRFlowable, KeepTogether
from resume_md import args, parse, inline, source_note, blocks_to_flow
from scripts.employment_timeline import RailStyle, group_positions, keep_count, tint, with_overlap_lines

DARK, RED, GOLD, GRAY = "#1b1b1b", "#8f0d0d", "#e6c96e", "#555555"
LINK = RED
OVERLAP_COLORS = (RED, "#a8841a", DARK, "#b5651d", GRAY)
RAIL = RailStyle(OVERLAP_COLORS, width=3, lane_gap=3, text_gap=7)
M, GAP = 34, 18
LEFT = ("Summary", "Work Experience", "Projects")
st = {
    "name": ParagraphStyle("name", fontName="Times-Bold", fontSize=26, leading=30, textColor=DARK),
    "contact": ParagraphStyle("contact", fontName="Helvetica", fontSize=8, leading=11, textColor=GRAY),
    "sec": ParagraphStyle("sec", fontName="Times-Bold", fontSize=15, leading=18, textColor=DARK, spaceBefore=8),
    "body": ParagraphStyle("body", fontName="Helvetica", fontSize=8.3, leading=10.8, textColor=GRAY, spaceBefore=2),
    "bullet": ParagraphStyle("bullet", fontName="Helvetica", fontSize=8.3, leading=10.8, textColor=GRAY),
    "title": ParagraphStyle("title", fontName="Helvetica", fontSize=10, leading=13, textColor=DARK),
    "org": ParagraphStyle("org", fontName="Helvetica-Bold", fontSize=8.6, leading=11, textColor=RED),
    "meta": ParagraphStyle("meta", fontName="Helvetica", fontSize=7.8, leading=10, textColor=GRAY),
    "skill": ParagraphStyle("skill", fontName="Helvetica", fontSize=8.3, leading=10.5, textColor=DARK),
    "disc": ParagraphStyle("disc", fontName="Helvetica-Oblique", fontSize=6.8, leading=8.6, textColor=GRAY),
}


def section(title, blocks, width, keep=True):
    pad = [("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0),
           ("TOPPADDING", (0, 0), (-1, -1), 1), ("BOTTOMPADDING", (0, 0), (-1, -1), 1)]

    def h3(b):
        if b.get("sub"):
            meta = f'<font color="{GRAY}">{inline(b["text"], LINK)}</font>    {inline(b["dates"], LINK)}'
            return [Spacer(1, 2), Paragraph(tint(meta, b) if "rail_color" in b else meta, st["meta"])]
        title, org = b["text"].rsplit(", ", 1) if ", " in b["text"] else (b["text"], "")
        out = [Spacer(1, 5), Paragraph(f"<b>{inline(title, LINK)}</b>" if b.get("group") else inline(title, LINK), st["title"])]
        if org:
            out.append(Paragraph(tint(inline(org, LINK), b), st["org"]))
        meta = "    ".join(x for x in (b["dates"], b["where"]) if x)
        if meta:
            out.append(Paragraph(inline(meta, LINK), st["meta"]))
        return out

    def table(b):
        t = Table([[Paragraph(inline(r[0], LINK), st["skill"]), Paragraph(inline(r[1], LINK) + " yrs", st["meta"])] for r in b["rows"]],
                  colWidths=[width * 0.78, width * 0.22])
        t.setStyle(TableStyle(pad + [("VALIGN", (0, 0), (-1, -1), "TOP"),
                                     ("LINEBELOW", (0, 0), (-1, -2), 0.3, colors.HexColor("#dddddd"))]))
        return [Spacer(1, 2), t]

    if title == "Work Experience":
        blocks = group_positions(blocks)
    body = with_overlap_lines(title, blocks, RAIL, lambda bs: blocks_to_flow(bs, st, LINK, h3, table, title == "Skills"))
    head = [Paragraph(inline(title.upper(), LINK), st["sec"]),
            HRFlowable(width="100%", thickness=1.6, color=colors.HexColor(GOLD), spaceBefore=1, spaceAfter=3)]
    n = keep_count(body, 2)
    return [KeepTogether(head + body[:n])] + body[n:] if keep else head + body


def main():
    a = args()
    doc = parse(a.input_abs_path)
    PW, PH = A4
    W = PW - 2 * M
    LW = W * 0.62 - GAP / 2
    RW = W - LW - GAP
    header = [Paragraph(inline(doc["name"].upper(), LINK), st["name"])] + \
             [Paragraph(inline(l, LINK), st["contact"]) for l in doc["contact"]]
    HH = sum(p.wrap(W, PH)[1] for p in header) + 14

    left, right = [], []
    for s in doc["sections"]:
        if s["title"] in LEFT:
            left += section(s["title"], s["blocks"], LW)
        else:
            right += section(s["title"], s["blocks"], RW, keep=False)
    if doc["disclaimer"]:
        left += [Spacer(1, 10), HRFlowable(width="100%", thickness=0.4, color=colors.HexColor(GOLD), spaceAfter=3),
                 Paragraph("<br/>".join(inline(l, LINK) for l in doc["disclaimer"]), st["disc"])]

    left += source_note(__file__, LINK)

    def draw_right(c, top):
        if right:
            Frame(M + LW + GAP, M, RW, top - M, leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0).addFromList(right, c)

    def first(c, d):
        y = PH - M
        for p in header:
            h = p.wrap(W, PH)[1]; p.drawOn(c, M, y - h); y -= h
        draw_right(c, PH - M - HH)

    def later(c, d):
        draw_right(c, PH - M)

    fr = dict(leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    d = BaseDocTemplate(a.output_abs_path, pagesize=A4, leftMargin=M, rightMargin=M, topMargin=M, bottomMargin=M,
                        title=doc["name"], author=doc["name"])
    d.addPageTemplates([PageTemplate("first", [Frame(M, M, LW, PH - 2 * M - HH, **fr)], onPage=first, autoNextPageTemplate="later"),
                        PageTemplate("later", [Frame(M, M, LW, PH - 2 * M, **fr)], onPage=later)])
    d.build(left)
    if right:
        raise SystemExit("Right column did not fit beside the left column")


if __name__ == "__main__":
    main()
