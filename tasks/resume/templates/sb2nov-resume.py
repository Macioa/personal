"""Render a resume md (scripts/resume_final.py format) to PDF in the sb2nov-resume style.
Usage: python sb2nov-resume.py --input-abs-path <md> --output-abs-path <pdf>"""
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_RIGHT
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable, KeepTogether
from resume_md import args, parse, inline, blocks_to_flow, grid

LINK = "#1a0dab"
M = 36
st = {
    "name": ParagraphStyle("name", fontName="Times-Bold", fontSize=20, leading=24),
    "contact": ParagraphStyle("contact", fontName="Times-Roman", fontSize=9.5, leading=12, alignment=TA_RIGHT),
    "sec": ParagraphStyle("sec", fontName="Times-Roman", fontSize=12.5, leading=15, spaceBefore=8),
    "body": ParagraphStyle("body", fontName="Times-Roman", fontSize=9.8, leading=12, spaceBefore=2),
    "bullet": ParagraphStyle("bullet", fontName="Times-Roman", fontSize=9.8, leading=12),
    "h3l": ParagraphStyle("h3l", fontName="Times-Bold", fontSize=10.5, leading=13),
    "h3r": ParagraphStyle("h3r", fontName="Times-Roman", fontSize=10, leading=13, alignment=TA_RIGHT),
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
        t = Table([[Paragraph("• " + inline(b["text"], LINK), st["h3l"]), Paragraph(inline(b["where"], LINK), st["h3r"])],
                   ["", Paragraph(inline(b["dates"], LINK), st["dates"])]], colWidths=[W * 0.72, W * 0.28])
        t.setStyle(TableStyle(pad))
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
        story += blocks_to_flow(s["blocks"], st, LINK, h3, table, s["title"] == "Skills")
    if doc["disclaimer"]:
        story += [Spacer(1, 10), HRFlowable(width="100%", thickness=0.4, color=colors.grey, spaceAfter=4),
                  Paragraph("<br/>".join(inline(l, LINK) for l in doc["disclaimer"]), st["disc"])]
    SimpleDocTemplate(a.output_abs_path, pagesize=letter, leftMargin=M, rightMargin=M, topMargin=M, bottomMargin=M,
                      title=doc["name"], author=doc["name"]).build(story)


if __name__ == "__main__":
    main()
