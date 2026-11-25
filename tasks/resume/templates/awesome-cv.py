# Design source: Awesome-CV, https://github.com/posquit0/Awesome-CV
"""Render a resume md (scripts/resume_final.py format) to PDF in the awesome-cv style.
Usage: python awesome-cv.py --input-abs-path <md> --output-abs-path <pdf>"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_RIGHT, TA_CENTER
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether
from reportlab.platypus.flowables import Flowable
from resume_md import args, parse, inline, source_note, blocks_to_flow, grid
from scripts.employment_timeline import RailStyle, group_positions, tint, with_overlap_lines

RED, DARK, GRAY, LIGHT = "#dc3522", "#333333", "#5d5d5d", "#999999"
LINK = RED
OVERLAP_COLORS = (RED, DARK, LIGHT, "#f08a5d", GRAY)
RAIL = RailStyle(OVERLAP_COLORS, width=2.5, lane_gap=3, text_gap=7)
M = 40
st = {
    "first": ParagraphStyle("first", fontName="Helvetica", fontSize=30, leading=34, alignment=TA_CENTER, textColor=GRAY),
    "contact": ParagraphStyle("contact", fontName="Helvetica", fontSize=8.5, leading=12, alignment=TA_CENTER, textColor=DARK),
    "sec": ParagraphStyle("sec", fontName="Helvetica-Bold", fontSize=15, leading=18, textColor=DARK),
    "body": ParagraphStyle("body", fontName="Helvetica", fontSize=8.8, leading=11.2, textColor=GRAY, spaceBefore=2),
    "bullet": ParagraphStyle("bullet", fontName="Helvetica", fontSize=8.8, leading=11.2, textColor=GRAY),
    "org": ParagraphStyle("org", fontName="Helvetica-Bold", fontSize=10, leading=13, textColor=DARK),
    "where": ParagraphStyle("where", fontName="Helvetica-Oblique", fontSize=9, leading=13, textColor=RED, alignment=TA_RIGHT),
    "title": ParagraphStyle("title", fontName="Helvetica", fontSize=7.8, leading=11, textColor=GRAY),
    "lead": ParagraphStyle("lead", fontName="Helvetica-Bold", fontSize=8.4, leading=11, textColor=RED),
    "sub": ParagraphStyle("sub", fontName="Helvetica", fontSize=7.2, leading=10, textColor=LIGHT),
    "dates": ParagraphStyle("dates", fontName="Helvetica-Oblique", fontSize=8, leading=11, textColor=LIGHT, alignment=TA_RIGHT),
    "disc": ParagraphStyle("disc", fontName="Helvetica-Oblique", fontSize=7, leading=9, textColor=LIGHT),
}


class SectionHead(Flowable):
    """Title with first 3 letters red, rest dark, then a rule to the right edge."""
    def __init__(self, title, width):
        super().__init__(); self.t, self.w = title, width
    def wrap(self, *a):
        return self.w, 24
    def draw(self):
        c = self.canv
        c.setFont("Helvetica-Bold", 15)
        head, rest = self.t[:3], self.t[3:]
        c.setFillColor(colors.HexColor(RED)); c.drawString(0, 6, head)
        x = c.stringWidth(head, "Helvetica-Bold", 15)
        c.setFillColor(colors.HexColor(DARK)); c.drawString(x, 6, rest)
        x += c.stringWidth(rest, "Helvetica-Bold", 15) + 6
        c.setStrokeColor(colors.HexColor(DARK)); c.setLineWidth(0.8); c.line(x, 9, self.w, 9)


def main():
    a = args()
    doc = parse(a.input_abs_path)
    W = A4[0] - 2 * M
    pad = [("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0),
           ("TOPPADDING", (0, 0), (-1, -1), 0), ("BOTTOMPADDING", (0, 0), (-1, -1), 0)]

    def h3(b):
        w = W - b["rail_indent"] - 6 if "rail_indent" in b else W  # 6 = frame padding the table overhangs
        if b.get("sub"):
            t = Table([[Paragraph(inline(b["text"].upper(), LINK), st["sub"]), Paragraph(inline(b["dates"], LINK), st["dates"])]],
                      colWidths=[w * 0.7, w * 0.3])
            t.setStyle(TableStyle(pad))
            t.hAlign = "LEFT"
            return [Spacer(1, 2), t]
        title, org = b["text"].rsplit(", ", 1) if ", " in b["text"] else ("", b["text"])
        t = Table([[Paragraph(tint(inline(org, LINK), b), st["org"]), Paragraph(inline(b["where"], LINK), st["where"])],
                   [Paragraph(inline(title.upper(), LINK), st["lead" if b.get("group") else "title"]), Paragraph(inline(b["dates"], LINK), st["dates"])]],
                  colWidths=[w * 0.7, w * 0.3])
        t.setStyle(TableStyle(pad))
        if "rail_indent" in b:
            t.hAlign = "LEFT"
        return [Spacer(1, 6), t]

    def table(b):
        cells = [Paragraph(f'<font color="{DARK}"><b>{inline(r[0], LINK)}</b></font>  {inline(r[1], LINK)} yrs', st["body"]) for r in b["rows"]]
        return [grid(cells, 3, W)]

    first, _, last = doc["name"].rpartition(" ")
    story = [Paragraph(f'{inline(first, LINK)} <font name="Helvetica-Bold" color="{DARK}">{inline(last, LINK)}</font>', st["first"]),
             Spacer(1, 4)]
    story += [Paragraph(inline(l, LINK).replace(" - ", "  |  "), st["contact"]) for l in doc["contact"]]
    for s in doc["sections"]:
        story.append(Spacer(1, 8))
        blocks = group_positions(s["blocks"]) if s["title"] == "Work Experience" else s["blocks"]
        body = with_overlap_lines(s["title"], blocks, RAIL,
                                  lambda bs: blocks_to_flow(bs, st, LINK, h3, table, s["title"] == "Skills"))
        story.append(KeepTogether([SectionHead(s["title"], W)] + body[:1]))
        story += body[1:]
    if doc["disclaimer"]:
        story += [Spacer(1, 12), Paragraph("<br/>".join(inline(l, LINK) for l in doc["disclaimer"]), st["disc"])]

    story += source_note(__file__, LINK)

    def footer(c, d):
        c.saveState(); c.setFont("Helvetica", 7); c.setFillColor(colors.HexColor(LIGHT))
        c.drawCentredString(A4[0] / 2, 22, f"{doc['name'].upper()}  ·  RÉSUMÉ")
        c.drawRightString(A4[0] - M, 22, str(d.page)); c.restoreState()

    SimpleDocTemplate(a.output_abs_path, pagesize=A4, leftMargin=M, rightMargin=M, topMargin=M, bottomMargin=M,
                      title=doc["name"], author=doc["name"]).build(story, onFirstPage=footer, onLaterPages=footer)


if __name__ == "__main__":
    main()
