# Design source: Awesome-CV, https://github.com/posquit0/Awesome-CV
"""Render a cover letter md (cover_md.py format) to PDF in the awesome-cv style: centered split-weight name, red-led
section head, low-poly red shards in the corners, an oversized quote mark, and the resume's footer.
Usage: python awesome-cv.py --input-abs-path <md> --output-abs-path <pdf>"""
import importlib.util, os, random
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_RIGHT
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
from reportlab.platypus.flowables import Flowable
from cover_md import args, letter, inline, source_note

_spec = importlib.util.spec_from_file_location("awesome", os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "awesome-cv.py"))
aw = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(aw)
RED, DARK, GRAY, LIGHT = aw.RED, aw.DARK, aw.GRAY, aw.LIGHT
PW, PH = A4
M = 46
st = {
    "first": aw.st["first"], "contact": aw.st["contact"], "disc": aw.st["disc"],
    "org": aw.st["org"], "where": aw.st["where"],
    "date": ParagraphStyle("date", parent=aw.st["dates"], fontSize=9),
    "body": ParagraphStyle("body", fontName="Helvetica", fontSize=9.8, leading=14, textColor=GRAY, spaceAfter=8),
    "hello": ParagraphStyle("hello", fontName="Helvetica-Bold", fontSize=10.5, leading=14, textColor=DARK, spaceAfter=8),
    "close": ParagraphStyle("close", fontName="Helvetica", fontSize=9.8, leading=14, textColor=GRAY),
    "sign": ParagraphStyle("sign", fontName="Helvetica-Bold", fontSize=16, leading=20, textColor=DARK),
}


class Quote(Flowable):
    """Oversized red open-quote that hangs behind the first paragraph."""
    def wrap(self, *a):
        return 0, 0

    def draw(self):
        c = self.canv
        c.saveState(); c.setFillColor(colors.HexColor(RED)); c.setFillAlpha(0.12); c.setFont("Times-Bold", 120)
        c.drawString(-14, -70, "“"); c.restoreState()


class SignRule(Flowable):
    """Short red bar under the signature, like the section-head accent."""
    def wrap(self, *a):
        return 60, 8

    def draw(self):
        c = self.canv
        c.setFillColor(colors.HexColor(RED)); c.rect(0, 3, 26, 2.4, stroke=0, fill=1)
        c.setFillColor(colors.HexColor(DARK)); c.rect(28, 3, 34, 0.8, stroke=0, fill=1)


def shards(c, x0, y0, sx, sy, seed):
    """Low-poly triangle cluster anchored at a page corner; sx, sy point the cluster into the page."""
    rnd = random.Random(seed)
    pts = [(0, 0), (150, 0), (0, 110), (70, 0), (0, 55), (60, 40), (110, 20), (25, 85), (35, 25)]
    tris = [(0, 3, 8), (3, 6, 8), (3, 1, 6), (0, 8, 4), (4, 8, 7), (8, 5, 7), (8, 6, 5), (4, 7, 2)]
    shades = (RED, "#e8604f", "#f08a5d", DARK, "#b52a1b", LIGHT)
    c.saveState()
    for i, t in enumerate(tris):
        c.setFillColor(colors.HexColor(shades[rnd.randrange(len(shades))])); c.setFillAlpha(0.55 + 0.4 * rnd.random())
        p = c.beginPath()
        for k, idx in enumerate(t):
            x, y = pts[idx]
            (p.moveTo if k == 0 else p.lineTo)(x0 + sx * x, y0 + sy * y)
        p.close(); c.drawPath(p, stroke=0, fill=1)
    c.restoreState()


def main():
    a = args()
    L = letter(a.input_abs_path)
    W = PW - 2 * M
    pad = [("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0),
           ("TOPPADDING", (0, 0), (-1, -1), 0), ("BOTTOMPADDING", (0, 0), (-1, -1), 0)]
    first, _, last = L["name"].rpartition(" ")
    story = [Spacer(1, 18), Paragraph(f'{inline(first, RED)} <font name="Helvetica-Bold" color="{DARK}">{inline(last, RED)}</font>', st["first"]),
             Spacer(1, 4)]
    story += [Paragraph(inline(l, RED).replace(" - ", "  |  "), st["contact"]) for l in L["contact"]]
    story += [Spacer(1, 22), aw.SectionHead("Cover Letter", W), Spacer(1, 4)]
    org, *rest = L["to"]
    rows = [[Paragraph(inline(org, RED), st["org"]), Paragraph(inline(L["date"], RED), st["date"])]]
    rows += [[Paragraph(inline(l, RED), st["where"].clone("w", alignment=0)), ""] for l in rest]
    t = Table(rows, colWidths=[W * 0.7, W * 0.3]); t.setStyle(TableStyle(pad))
    story += [t, Spacer(1, 16), Paragraph(inline(L["salutation"], RED), st["hello"]), Quote()]
    story += [Paragraph(inline(p, RED), st["body"]) for p in L["body"]]
    story += [Spacer(1, 2), Paragraph(inline(L["closing"][0], RED), st["close"]), Spacer(1, 6)]
    story += [Paragraph(inline(l, RED), st["sign"]) for l in L["closing"][1:]] + [SignRule()]
    if L["disclaimer"]:
        story += [Spacer(1, 14), HRFlowable(width="100%", thickness=0.4, color=colors.HexColor(LIGHT), spaceAfter=3),
                  Paragraph("<br/>".join(inline(l, RED) for l in L["disclaimer"]), st["disc"])]

    story += source_note(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), os.path.basename(__file__)), RED)
    def page(c, d):
        shards(c, 0, PH, 1, -1, 3)
        shards(c, PW, 0, -1, 1, 7)
        c.saveState(); c.setFont("Helvetica", 7); c.setFillColor(colors.HexColor(LIGHT))
        c.drawCentredString(PW / 2, 22, f"{L['name'].upper()}  ·  COVER LETTER"); c.restoreState()

    SimpleDocTemplate(a.output_abs_path, pagesize=A4, leftMargin=M, rightMargin=M, topMargin=M, bottomMargin=M,
                      title=f"{L['name']} - Cover Letter", author=L["name"]).build(story, onFirstPage=page, onLaterPages=page)


if __name__ == "__main__":
    main()
