# Design source: sb2nov/resume, https://github.com/sb2nov/resume
"""Render a resume md (scripts/resume_final.py format) to PDF in the sb2nov-resume style.
Usage: python sb2nov-resume.py --input-abs-path <md> --output-abs-path <pdf>"""
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_RIGHT
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable, KeepTogether
from resume_md import args, parse, inline, source_note, blocks_to_flow, grid
from scripts.employment_timeline import RailStyle, group_positions, tint, with_overlap_lines

LINK = "#1a0dab"
OVERLAP_COLORS = (LINK, "#000000", "#7a7a7a", "#2e6f5e", "#8a5a2b")
RAIL = RailStyle(OVERLAP_COLORS, width=1.5, lane_gap=3, text_gap=6)
M = 36
st = {
    "name": ParagraphStyle("name", fontName="Times-Bold", fontSize=20, leading=24),
    "contact": ParagraphStyle("contact", fontName="Times-Roman", fontSize=9.5, leading=12, alignment=TA_RIGHT),
    "sec": ParagraphStyle("sec", fontName="Times-Roman", fontSize=12.5, leading=15, spaceBefore=8),
    "body": ParagraphStyle("body", fontName="Times-Roman", fontSize=9.8, leading=12, spaceBefore=2),
    "bullet": ParagraphStyle("bullet", fontName="Times-Roman", fontSize=9.8, leading=12),
    "h3l": ParagraphStyle("h3l", fontName="Times-Bold", fontSize=10.5, leading=13),
    "h3r": ParagraphStyle("h3r", fontName="Times-Roman", fontSize=10, leading=13, alignment=TA_RIGHT),
    "sub": ParagraphStyle("sub", fontName="Times-Italic", fontSize=9.8, leading=12, textColor=colors.HexColor("#444444")),
    "dates": ParagraphStyle("dates", fontName="Times-Italic", fontSize=9.5, leading=12, alignment=TA_RIGHT),
    "disc": ParagraphStyle("disc", fontName="Times-Italic", fontSize=7.5, leading=9.5, textColor=colors.HexColor("#555555")),
}


def main():
    a = args()
    doc = parse(a.input_abs_path)
    W = letter[0] - 2 * M
    pad = [("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0),
           ("TOPPADDING", (0, 0), (-1, -1), 0), ("BOTTOMPADDING", (0, 0), (-1, -1), 0), ("VALIGN", (0, 0), (-1, -1), "BOTTOM")]

    def h3(b):
        w = W - b["rail_indent"] - 6 if "rail_indent" in b else W  # 6 = frame padding the table overhangs
        if b.get("sub"):
            t = Table([[Paragraph("&nbsp;&nbsp;&nbsp;– " + inline(b["text"], LINK), st["sub"]), Paragraph(inline(b["dates"], LINK), st["dates"])]],
                      colWidths=[w * 0.72, w * 0.28])
            t.setStyle(TableStyle(pad))
            t.hAlign = "LEFT"
            return [Spacer(1, 1), t]
        t = Table([[Paragraph("• " + tint(inline(b["text"], LINK), b), st["h3l"]), Paragraph(inline(b["where"], LINK), st["h3r"])],
                   ["", Paragraph(inline(b["dates"], LINK), st["dates"])]], colWidths=[w * 0.72, w * 0.28])
        t.setStyle(TableStyle(pad))
        if "rail_indent" in b:
            t.hAlign = "LEFT"
        return [Spacer(1, 5), t]

    def table(b):
        cells = [Paragraph(f"<b>{inline(r[0], LINK)}</b>: {inline(r[1], LINK)} yrs", st["body"]) for r in b["rows"]]
        return [Spacer(1, 2), grid(cells, 3, W)]

    story = []
    head = Table([[Paragraph(inline(doc["name"], LINK), st["name"]),
                   Paragraph("<br/>".join(inline(l, LINK) for l in doc["contact"]), st["contact"])]], colWidths=[W * 0.4, W * 0.6])
    head.setStyle(TableStyle(pad))
    story.append(head)
    for s in doc["sections"]:
        story.append(KeepTogether([Paragraph(inline(s["title"].upper(), LINK), st["sec"]),
                                   HRFlowable(width="100%", thickness=0.6, color=colors.black, spaceBefore=1, spaceAfter=3)]))
        blocks = group_positions(s["blocks"]) if s["title"] == "Work Experience" else s["blocks"]
        story += with_overlap_lines(s["title"], blocks, RAIL,
                                    lambda bs: blocks_to_flow(bs, st, LINK, h3, table, s["title"] == "Skills"))
    if doc["disclaimer"]:
        story += [Spacer(1, 10), HRFlowable(width="100%", thickness=0.4, color=colors.grey, spaceAfter=4),
                  Paragraph("<br/>".join(inline(l, LINK) for l in doc["disclaimer"]), st["disc"])]
    story += source_note(__file__, LINK)
    SimpleDocTemplate(a.output_abs_path, pagesize=letter, leftMargin=M, rightMargin=M, topMargin=M, bottomMargin=M,
                      title=doc["name"], author=doc["name"]).build(story)


if __name__ == "__main__":
    main()
