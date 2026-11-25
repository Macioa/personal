# Design source: sb2nov/resume, https://github.com/sb2nov/resume
"""Render a cover letter md (cover_md.py format) to PDF in the sb2nov-resume style: classic Times letterhead with the
name left and contact right, a black rule, an engraved double-line border with corner flourishes, and a fleuron.
Usage: python sb2nov-resume.py --input-abs-path <md> --output-abs-path <pdf>"""
import os
from reportlab.lib.pagesizes import letter as LETTER
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_RIGHT, TA_JUSTIFY
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
from reportlab.platypus.flowables import Flowable
from cover_md import args, letter, inline, source_note

LINK, INK = "#1a0dab", "#000000"
PW, PH = LETTER
M, FRAME = 54, 22
st = {
    "name": ParagraphStyle("name", fontName="Times-Bold", fontSize=22, leading=26),
    "contact": ParagraphStyle("contact", fontName="Times-Roman", fontSize=9.5, leading=12, alignment=TA_RIGHT),
    "sec": ParagraphStyle("sec", fontName="Times-Roman", fontSize=12.5, leading=15),
    "date": ParagraphStyle("date", fontName="Times-Italic", fontSize=10.5, leading=13, alignment=TA_RIGHT),
    "to": ParagraphStyle("to", fontName="Times-Roman", fontSize=10.5, leading=13),
    "body": ParagraphStyle("body", fontName="Times-Roman", fontSize=11, leading=14.6, spaceAfter=8, alignment=TA_JUSTIFY),
    "hello": ParagraphStyle("hello", fontName="Times-Roman", fontSize=11, leading=14.6, spaceAfter=8),
    "sign": ParagraphStyle("sign", fontName="Times-BoldItalic", fontSize=15, leading=19),
    "disc": ParagraphStyle("disc", fontName="Times-Italic", fontSize=7.5, leading=9.5, textColor=colors.HexColor("#555555")),
}


def leaf(c, x, y, s, flip):
    """One curled leaf of the fleuron, drawn with beziers."""
    f = -1 if flip else 1
    p = c.beginPath(); p.moveTo(x, y)
    p.curveTo(x + f * 10 * s, y + 10 * s, x + f * 26 * s, y + 8 * s, x + f * 30 * s, y)
    p.curveTo(x + f * 24 * s, y - 2 * s, x + f * 12 * s, y - 4 * s, x, y)
    c.drawPath(p, stroke=0, fill=1)
    p = c.beginPath(); p.moveTo(x + f * 30 * s, y)
    p.curveTo(x + f * 38 * s, y - 2 * s, x + f * 40 * s, y - 9 * s, x + f * 34 * s, y - 10 * s)
    c.drawPath(p, stroke=1, fill=0)


class Fleuron(Flowable):
    """Centered printer's ornament: two curled leaves around a lozenge, with hairlines to each side."""
    def __init__(self, width):
        super().__init__(); self.w = width

    def wrap(self, *a):
        return self.w, 20

    def draw(self):
        c, mid, y = self.canv, self.w / 2, 10
        c.setFillColor(colors.black); c.setStrokeColor(colors.black); c.setLineWidth(0.6)
        leaf(c, mid - 5, y, 0.8, True); leaf(c, mid + 5, y, 0.8, False)
        p = c.beginPath(); p.moveTo(mid, y + 4); p.lineTo(mid + 4, y); p.lineTo(mid, y - 4); p.lineTo(mid - 4, y); p.close()
        c.drawPath(p, stroke=0, fill=1)
        c.setLineWidth(0.4); c.line(mid - 120, y, mid - 42, y); c.line(mid + 42, y, mid + 120, y)


def border(c):
    """Engraved double frame with quarter-circle corner flourishes."""
    c.saveState(); c.setStrokeColor(colors.black)
    c.setLineWidth(1.4); c.rect(FRAME, FRAME, PW - 2 * FRAME, PH - 2 * FRAME)
    c.setLineWidth(0.4); c.rect(FRAME + 4, FRAME + 4, PW - 2 * FRAME - 8, PH - 2 * FRAME - 8)
    for x, y, sx, sy in ((FRAME, FRAME, 1, 1), (PW - FRAME, FRAME, -1, 1), (FRAME, PH - FRAME, 1, -1), (PW - FRAME, PH - FRAME, -1, -1)):
        c.setLineWidth(0.5)
        for r in (12, 18):
            p = c.beginPath(); p.arc(x + sx * 4 - r, y + sy * 4 - r, x + sx * 4 + r, y + sy * 4 + r,
                                     startAng={(1, 1): 0, (-1, 1): 90, (1, -1): 270, (-1, -1): 180}[(sx, sy)], extent=90)
            c.drawPath(p, stroke=1, fill=0)
        c.circle(x + sx * 14, y + sy * 14, 1.6, stroke=0, fill=1)
    c.restoreState()


def main():
    a = args()
    L = letter(a.input_abs_path)
    W = PW - 2 * M
    pad = [("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0),
           ("TOPPADDING", (0, 0), (-1, -1), 0), ("BOTTOMPADDING", (0, 0), (-1, -1), 0), ("VALIGN", (0, 0), (-1, -1), "BOTTOM")]
    head = Table([[Paragraph(inline(L["name"], LINK), st["name"]),
                   Paragraph("<br/>".join(inline(l, LINK) for l in L["contact"]), st["contact"])]], colWidths=[W * 0.4, W * 0.6])
    head.setStyle(TableStyle(pad))
    to = Table([[Paragraph("<br/>".join(f"<b>{inline(l, LINK)}</b>" if i == 0 else inline(l, LINK) for i, l in enumerate(L["to"])), st["to"]),
                 Paragraph(inline(L["date"], LINK), st["date"])]], colWidths=[W * 0.65, W * 0.35])
    to.setStyle(TableStyle(pad + [("VALIGN", (0, 0), (-1, -1), "TOP")]))
    story = [head, Spacer(1, 6), Paragraph("COVER LETTER", st["sec"]),
             HRFlowable(width="100%", thickness=0.6, color=colors.black, spaceBefore=1, spaceAfter=12),
             to, Spacer(1, 18), Paragraph(inline(L["salutation"], LINK), st["hello"])]
    story += [Paragraph(inline(p, LINK), st["body"]) for p in L["body"]]
    story += [Fleuron(W), Spacer(1, 8), Paragraph(inline(L["closing"][0], LINK), st["hello"])]
    story += [Paragraph(inline(l, LINK), st["sign"]) for l in L["closing"][1:]]
    if L["disclaimer"]:
        story += [Spacer(1, 14), HRFlowable(width="100%", thickness=0.4, color=colors.HexColor("#888888"), spaceAfter=3),
                  Paragraph("<br/>".join(inline(l, LINK) for l in L["disclaimer"]), st["disc"])]
    story += source_note(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), os.path.basename(__file__)), LINK)
    SimpleDocTemplate(a.output_abs_path, pagesize=LETTER, leftMargin=M, rightMargin=M, topMargin=M - 8, bottomMargin=M,
                      title=f"{L['name']} - Cover Letter", author=L["name"]).build(story, onFirstPage=lambda c, d: border(c),
                                                                                    onLaterPages=lambda c, d: border(c))


if __name__ == "__main__":
    main()
