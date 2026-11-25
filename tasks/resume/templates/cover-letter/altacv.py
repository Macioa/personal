# Design source: AltaCV, https://github.com/liantze/AltaCV
"""Render a cover letter md (cover_md.py format) to PDF in the altacv style: serif caps name, gold rules, red accents,
an art-deco sunburst in the corner, a red drop cap, and a sidebar with the date and recipient.
Usage: python altacv.py --input-abs-path <md> --output-abs-path <pdf>"""
import os
import math
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.platypus import BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, HRFlowable
from reportlab.platypus.flowables import Flowable
from cover_md import args, letter, inline, source_note

DARK, RED, GOLD, GRAY = "#1b1b1b", "#8f0d0d", "#e6c96e", "#555555"
PW, PH = A4
M, GAP = 40, 22
st = {
    "name": ParagraphStyle("name", fontName="Times-Bold", fontSize=28, leading=32, textColor=DARK),
    "contact": ParagraphStyle("contact", fontName="Helvetica", fontSize=8, leading=11, textColor=GRAY),
    "sec": ParagraphStyle("sec", fontName="Times-Bold", fontSize=15, leading=18, textColor=DARK, spaceBefore=4),
    "body": ParagraphStyle("body", fontName="Helvetica", fontSize=9.4, leading=13.4, textColor=GRAY, spaceAfter=8),
    "hello": ParagraphStyle("hello", fontName="Times-Bold", fontSize=12.5, leading=16, textColor=DARK, spaceAfter=8),
    "side": ParagraphStyle("side", fontName="Helvetica", fontSize=8.6, leading=12, textColor=DARK),
    "org": ParagraphStyle("org", fontName="Helvetica-Bold", fontSize=8.8, leading=12, textColor=RED),
    "close": ParagraphStyle("close", fontName="Helvetica", fontSize=9.4, leading=13, textColor=GRAY),
    "sign": ParagraphStyle("sign", fontName="Times-BoldItalic", fontSize=20, leading=24, textColor=RED),
    "disc": ParagraphStyle("disc", fontName="Helvetica-Oblique", fontSize=6.8, leading=8.6, textColor=GRAY),
}


def rule():
    return HRFlowable(width="100%", thickness=1.6, color=colors.HexColor(GOLD), spaceBefore=1, spaceAfter=5)


class Diamonds(Flowable):
    """Gold rule broken by three red diamonds."""
    def __init__(self, width):
        super().__init__(); self.w = width

    def wrap(self, *a):
        return self.w, 16

    def draw(self):
        c, mid, y = self.canv, self.w / 2, 8
        c.setStrokeColor(colors.HexColor(GOLD)); c.setLineWidth(0.8)
        c.line(0, y, mid - 30, y); c.line(mid + 30, y, self.w, y)
        for dx, r in ((-16, 3), (0, 5), (16, 3)):
            c.setFillColor(colors.HexColor(RED if dx == 0 else GOLD))
            p = c.beginPath(); p.moveTo(mid + dx, y + r); p.lineTo(mid + dx + r, y); p.lineTo(mid + dx, y - r); p.lineTo(mid + dx - r, y); p.close()
            c.drawPath(p, stroke=0, fill=1)


def sunburst(c, cx, cy, r0, r1, n, start, end):
    """Art-deco fan of alternating gold and red rays."""
    c.saveState()
    for i in range(n):
        a0 = math.radians(start + (end - start) * i / n)
        a1 = math.radians(start + (end - start) * (i + 0.5) / n)
        c.setFillColor(colors.HexColor(GOLD if i % 3 else RED)); c.setFillAlpha(0.9 if i % 3 else 0.75)
        p = c.beginPath()
        p.moveTo(cx + r0 * math.cos(a0), cy + r0 * math.sin(a0)); p.lineTo(cx + r1 * math.cos(a0), cy + r1 * math.sin(a0))
        p.lineTo(cx + r1 * math.cos(a1), cy + r1 * math.sin(a1)); p.lineTo(cx + r0 * math.cos(a1), cy + r0 * math.sin(a1)); p.close()
        c.drawPath(p, stroke=0, fill=1)
    c.setFillAlpha(1); c.setStrokeColor(colors.HexColor(GOLD)); c.setLineWidth(1.2)
    for r in (r0 - 6, r1 + 6):
        c.circle(cx, cy, r, stroke=1, fill=0)
    c.restoreState()


def drop_cap(text):
    """Red serif initial, three lines tall, set as an inline oversized letter."""
    return f'<font name="Times-Bold" size="30" color="{RED}">{text[0]}</font>{inline(text[1:], RED)}'


def main():
    a = args()
    L = letter(a.input_abs_path)
    W = PW - 2 * M
    LW = W * 0.68 - GAP / 2
    RW = W - LW - GAP
    header = [Paragraph(inline(L["name"].upper(), RED), st["name"])] + [Paragraph(inline(l, RED), st["contact"]) for l in L["contact"]]
    HH = sum(p.wrap(W * 0.7, PH)[1] for p in header) + 22

    body = [Paragraph("COVER LETTER", st["sec"]), rule(), Spacer(1, 4), Paragraph(inline(L["salutation"], RED), st["hello"])]
    for i, para in enumerate(L["body"]):
        body += [Paragraph(drop_cap(para), st["body"].clone("lead", autoLeading="max")), Spacer(1, 10)] if i == 0 else [Paragraph(inline(para, RED), st["body"])]
    body += [Diamonds(LW), Spacer(1, 4), Paragraph(inline(L["closing"][0], RED), st["close"]), Spacer(1, 4)]
    body += [Paragraph(inline(l, RED), st["sign"]) for l in L["closing"][1:]]
    if L["disclaimer"]:
        body += [Spacer(1, 14), HRFlowable(width="100%", thickness=0.4, color=colors.HexColor(GOLD), spaceAfter=3),
                  Paragraph("<br/>".join(inline(l, RED) for l in L["disclaimer"]), st["disc"])]

    body += source_note(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), os.path.basename(__file__)), RED)
    side = [Paragraph("DATE", st["sec"]), rule(), Paragraph(inline(L["date"], RED), st["side"]), Spacer(1, 10),
            Paragraph("TO", st["sec"]), rule(), Paragraph(inline(L["to"][0], RED), st["org"])]
    side += [Paragraph(inline(l, RED), st["side"]) for l in L["to"][1:]]

    def page(c, d):
        sunburst(c, PW, PH, 46, 112, 18, 180, 270)
        y = PH - M
        for p in header:
            h = p.wrap(W * 0.7, PH)[1]; p.drawOn(c, M, y - h); y -= h
        c.setStrokeColor(colors.HexColor(GOLD)); c.setLineWidth(1.6); c.line(M, y - 8, M + W * 0.7, y - 8)
        Frame(M + LW + GAP, M + 60, RW, PH - 2 * M - HH - 60, leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0).addFromList(side, c)
        c.setStrokeColor(colors.HexColor(GOLD)); c.setLineWidth(0.5)
        c.line(M + LW + GAP / 2, M + 40, M + LW + GAP / 2, PH - M - HH)
        sunburst(c, 0, 0, 22, 60, 9, 0, 90)
        c.setFillColor(colors.HexColor(GRAY)); c.setFont("Times-Italic", 8)
        c.drawRightString(PW - M, M - 16, f"{L['name']}  •  Cover Letter")

    fr = dict(leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    d = BaseDocTemplate(a.output_abs_path, pagesize=A4, leftMargin=M, rightMargin=M, topMargin=M, bottomMargin=M,
                        title=f"{L['name']} - Cover Letter", author=L["name"])
    d.addPageTemplates([PageTemplate("p", [Frame(M, M, LW, PH - 2 * M - HH, **fr)], onPage=page)])
    d.build(body)


if __name__ == "__main__":
    main()
