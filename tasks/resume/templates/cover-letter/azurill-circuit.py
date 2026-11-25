# Design source: Azurill template from Reactive Resume, https://github.com/reactive-resume/reactive-resume
"""Render a cover letter md (cover_md.py format) to PDF in the azurill-circuit style: the resume's photo header and
circuit traces, a trace bus that taps into each paragraph, and an IC chip footer the bus routes into.
Usage: python azurill-circuit.py --input-abs-path <md> --output-abs-path <pdf>"""
import importlib.util, os
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib import colors
from reportlab.platypus import BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Table, TableStyle, HRFlowable
from reportlab.platypus.flowables import Flowable
from cover_md import args, letter, inline, source_note

_spec = importlib.util.spec_from_file_location("azurill", os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "azurill-circuit.py"))
az = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(az)
TEAL, MINT, CORAL, DARK, GRAY = az.TEAL, az.MINT, az.CORAL, az.DARK, az.GRAY
PW, PH = A4
M, BUS_W = 40, 22
BUS_X = M + 7
CHIP_W, CHIP_H, CHIP_Y, PINS = 96, 30, 34, 6
st = {
    "name": az.st["name"], "contact": az.st["contact"],
    "sec": ParagraphStyle("sec", parent=az.st["sec"], fontSize=15, leading=18, spaceBefore=0, spaceAfter=0),
    "date": ParagraphStyle("date", fontName="Helvetica", fontSize=9, leading=12, textColor=GRAY),
    "to": ParagraphStyle("to", fontName="Helvetica", fontSize=9, leading=12, textColor=DARK, alignment=TA_RIGHT),
    "body": ParagraphStyle("body", fontName="Helvetica", fontSize=9.8, leading=13.6, textColor=DARK, spaceAfter=7),
    "hello": ParagraphStyle("hello", fontName="Helvetica-Bold", fontSize=10.2, leading=14, textColor=TEAL, spaceAfter=6),
    "close": ParagraphStyle("close", fontName="Helvetica", fontSize=9.8, leading=13.6, textColor=DARK),
    "sign": ParagraphStyle("sign", fontName="Helvetica-BoldOblique", fontSize=17, leading=21, textColor=TEAL),
    "disc": az.st["disc"],
}


class Bus:
    """Taps collected during layout; traces drawn when the page ends."""
    def __init__(self):
        self.taps = []

    def draw(self, c, sign):
        if not self.taps:
            return
        c.saveState(); c.setLineCap(1); c.setLineJoin(1)
        top, cy = self.taps[0][1], CHIP_Y + CHIP_H / 2
        c.setStrokeColor(colors.HexColor(TEAL)); c.setLineWidth(1.1)
        p = c.beginPath(); p.moveTo(BUS_X, top); p.lineTo(BUS_X, cy + 14); p.lineTo(BUS_X + 14, cy)
        p.lineTo(PW / 2 - CHIP_W / 2 - 6, cy); c.drawPath(p, stroke=1, fill=0)
        for x, y, big in self.taps:
            c.setStrokeColor(colors.HexColor(MINT)); c.setLineWidth(0.8); c.line(BUS_X, y, x - 5, y)
            node(c, BUS_X, y, False); node(c, x - 5, y, big)
        if sign:
            x, y = sign
            c.setStrokeColor(colors.HexColor(MINT)); c.setLineWidth(0.8)
            p = c.beginPath(); p.moveTo(x, y); p.lineTo(x + 150, y); p.lineTo(x + 164, y - 14); p.lineTo(x + 230, y - 14)
            c.drawPath(p, stroke=1, fill=0); node(c, x + 230, y - 14, True)
        c.restoreState()
        self.taps = []


class Tap(Flowable):
    """Zero-height probe that taps the bus at the next paragraph's first line."""
    def __init__(self, bus, big=False, drop=7):
        super().__init__(); self.bus, self.big, self.drop = bus, big, drop
        self.width = self.height = 0

    def wrap(self, *a):
        return 0, 0

    def draw(self):
        x, y = self.canv.absolutePosition(0, 0)
        self.bus.taps.append((x, y - self.drop, self.big))


class Sign(Flowable):
    """Records where the signature underline starts."""
    def __init__(self, holder):
        super().__init__(); self.holder = holder; self.width = self.height = 0

    def wrap(self, *a):
        return 0, 0

    def draw(self):
        self.holder["at"] = self.canv.absolutePosition(0, -4)


def node(c, x, y, big):
    c.setStrokeColor(colors.HexColor(CORAL if big else TEAL)); c.setLineWidth(0.8)
    c.setFillColor(colors.HexColor(CORAL) if big else colors.white)
    c.circle(x, y, 3.2 if big else 2.2, stroke=1, fill=1)


def draw_vias(c, x0, y0, cols, rows, step=7):
    """Faint PCB via grid that fades toward its far corner."""
    c.saveState()
    for i in range(cols):
        for j in range(rows):
            fade = 1 - (i + j) / (cols + rows)
            c.setFillColor(colors.HexColor(MINT)); c.setFillAlpha(0.45 * fade)
            c.circle(x0 + i * step, y0 + j * step, 1, stroke=0, fill=1)
    c.restoreState()


def draw_chip(c, label):
    """IC package with pins, a notch, and traces fanning out to the right margin."""
    x, y = PW / 2 - CHIP_W / 2, CHIP_Y
    c.saveState(); c.setLineCap(1)
    pitch = CHIP_W / (PINS + 1)
    c.setStrokeColor(colors.HexColor(GRAY)); c.setLineWidth(1.6)
    for i in range(1, PINS + 1):
        px = x + i * pitch
        c.line(px, y + CHIP_H, px, y + CHIP_H + 5); c.line(px, y, px, y - 5)
    c.setFillColor(colors.HexColor(DARK)); c.setStrokeColor(colors.HexColor(TEAL)); c.setLineWidth(1)
    c.roundRect(x, y, CHIP_W, CHIP_H, 2.5, stroke=1, fill=1)
    c.setFillColor(colors.HexColor(TEAL)); c.circle(x + 7, y + CHIP_H - 7, 2, stroke=0, fill=1)
    c.setFillColor(colors.HexColor(MINT)); c.setFont("Helvetica-Bold", 7.4)
    c.drawCentredString(PW / 2, y + CHIP_H / 2 - 2.5, label)
    cy = y + CHIP_H / 2
    c.setStrokeColor(colors.HexColor(TEAL)); c.setLineWidth(1.1)
    c.line(x - 6, cy, x, cy)
    for k, (dy, end, col) in enumerate(((0, PW - M - 60, TEAL), (9, PW - M - 20, MINT), (-9, PW - M - 100, MINT))):
        c.setStrokeColor(colors.HexColor(col)); c.setLineWidth(0.9 if k == 0 else 0.7)
        p = c.beginPath(); p.moveTo(x + CHIP_W, cy + dy); p.lineTo(x + CHIP_W + 30, cy + dy)
        p.lineTo(x + CHIP_W + 30 + abs(dy) * 1.5, cy + dy * 2.5); p.lineTo(end, cy + dy * 2.5)
        c.drawPath(p, stroke=1, fill=0); node(c, end, cy + dy * 2.5, k == 0)
    c.restoreState()


def main():
    a = args()
    L = letter(a.input_abs_path)
    W = PW - 2 * M
    FX, FW = M + BUS_W, W - BUS_W
    image = az.load_photo(L["photo"])
    top = PH - az.HEADER if image else PH - M - 46
    bus, sign = Bus(), {}
    initials = "".join(w[0] for w in L["name"].split()).upper()

    head = Table([[Paragraph(inline(L["date"], TEAL), st["date"]), Paragraph("<br/>".join(inline(l, TEAL) for l in L["to"]), st["to"])]],
                 colWidths=[FW * 0.4, FW * 0.6])
    head.setStyle(TableStyle([("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                              ("VALIGN", (0, 0), (-1, -1), "TOP")]))
    story = [Tap(bus, True, 12), Paragraph("Cover Letter", st["sec"]), Spacer(1, 6), head, Spacer(1, 14),
             Paragraph(inline(L["salutation"], TEAL), st["hello"])]
    for i, para in enumerate(L["body"]):
        story += [Tap(bus, i == 0), Paragraph(inline(para, TEAL), st["body"])]
    story += [Spacer(1, 4), Tap(bus), Paragraph(inline(L["closing"][0], TEAL), st["close"]), Spacer(1, 6)]
    story += [Paragraph(inline(l, TEAL), st["sign"]) for l in L["closing"][1:]] + [Sign(sign)]
    if L["disclaimer"]:
        story += [Spacer(1, 30), HRFlowable(width="100%", thickness=0.4, color=colors.HexColor(MINT), spaceAfter=3),
                  Paragraph("<br/>".join(inline(l, TEAL) for l in L["disclaimer"]), st["disc"])]

    story += source_note(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), os.path.basename(__file__)), TEAL)
    name = Paragraph(inline(L["name"], TEAL), st["name"])
    contact = Paragraph("&nbsp;&nbsp;&nbsp;".join(inline(l, TEAL).replace(" - ", "&nbsp;&nbsp;&nbsp;") for l in L["contact"]), st["contact"])

    def page(c, d):
        draw_vias(c, M - 14, PH - 22, 9, 1); draw_vias(c, PW - M - 50, M - 20, 9, 3)
        y = PH - 112 if image else PH - M
        if image:
            az.draw_circuit(c, PH); az.draw_photo(c, image, L["photo"]["link"], PH)
        for p in (name, contact):
            h = p.wrap(W, PH)[1]; p.drawOn(c, M, y - h); y -= h + 1
        draw_chip(c, f"{initials} · {L['date'][-4:]}")

    def page_end(c, d):
        bus.draw(c, sign.pop("at", None))

    d = BaseDocTemplate(a.output_abs_path, pagesize=A4, leftMargin=M, rightMargin=M, topMargin=M, bottomMargin=M,
                        title=f"{L['name']} - Cover Letter", author=L["name"])
    d.addPageTemplates([PageTemplate("p", [Frame(FX, CHIP_Y + CHIP_H + 22, FW, top - CHIP_Y - CHIP_H - 22 - 10,
                                                 leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)],
                                     onPage=page, onPageEnd=page_end)])
    d.build(story)


if __name__ == "__main__":
    main()
