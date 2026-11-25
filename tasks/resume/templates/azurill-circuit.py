# Design source: Azurill template from Reactive Resume, https://github.com/reactive-resume/reactive-resume
"""Render a resume md (scripts/resume_final.py format) to PDF in the azurill-circuit style (photo header, two columns).
Left column: every other section. Right column: Summary, Work Experience, Projects.
Usage: python azurill-circuit.py --input-abs-path <md> --output-abs-path <pdf>"""
import io, math, re, urllib.request
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib.utils import ImageReader
from reportlab.lib import colors
from reportlab.platypus import BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Table, TableStyle, HRFlowable, Indenter, KeepTogether
from reportlab.platypus.flowables import Flowable
from resume_md import args, parse, inline, source_note, blocks_to_flow, lead_bold
from scripts.employment_timeline import RailStyle, group_positions, keep_count, tint, with_overlap_lines

TEAL, MINT, CORAL, DARK, GRAY = "#0f6e56", "#5dcaa5", "#f0997b", "#1f2328", "#4b5158"
LINK = TEAL
OVERLAP_COLORS = (TEAL, CORAL, MINT, DARK, GRAY)
RAIL = RailStyle(OVERLAP_COLORS, width=2, lane_gap=3, text_gap=6)
M, GAP, SPINE_X, SPINE_W = 28, 16, 7.5, 18
HEADER = 176
PHOTO_X, PHOTO_Y, PHOTO_R, RING = A4[0] / 2, 60, 42, 47
MAIN = ("Summary", "Work Experience", "Projects")
PROJECT = re.compile(r"^(\[[^\]]+\]\([^)]+\)|.+?)(?: \(([^()]*)\))? - (.+)$")
# start y, first bend dx, end y, end dx, optional branch (dx on the end run, branch y, branch end dx)
ROUTES = ((30, 60, 16, 235, (150, 30, 195)),
          (48, 85, 40, 270, None),
          (68, 95, 76, 250, (170, 62, 222)),
          (86, 72, 114, 190, (130, 128, 168)))
st = {
    "name": ParagraphStyle("name", fontName="Helvetica", fontSize=20, leading=24, alignment=TA_CENTER, textColor=DARK),
    "contact": ParagraphStyle("contact", fontName="Helvetica", fontSize=8.6, leading=12, alignment=TA_CENTER, textColor=DARK),
    "sec": ParagraphStyle("sec", fontName="Helvetica", fontSize=13, leading=16, textColor=TEAL, spaceBefore=9, spaceAfter=2),
    "body": ParagraphStyle("body", fontName="Helvetica", fontSize=8.8, leading=11.4, textColor=DARK, spaceBefore=2),
    "bullet": ParagraphStyle("bullet", fontName="Helvetica", fontSize=8.8, leading=11.4, textColor=DARK),
    "side": ParagraphStyle("side", fontName="Helvetica", fontSize=8.4, leading=10.8, textColor=DARK, spaceAfter=4),
    "org": ParagraphStyle("org", fontName="Helvetica-Bold", fontSize=9.4, leading=12, textColor=DARK),
    "title": ParagraphStyle("title", fontName="Helvetica", fontSize=8.8, leading=11.4, textColor=DARK),
    "lead": ParagraphStyle("lead", fontName="Helvetica-Bold", fontSize=9.2, leading=11.8, textColor=TEAL),
    "sub": ParagraphStyle("sub", fontName="Helvetica", fontSize=8, leading=10.4, textColor=GRAY),
    "subr": ParagraphStyle("subr", fontName="Helvetica", fontSize=7.8, leading=10.4, textColor=GRAY, alignment=TA_RIGHT),
    "right": ParagraphStyle("right", fontName="Helvetica", fontSize=8.6, leading=11.4, textColor=DARK, alignment=TA_RIGHT),
    "disc": ParagraphStyle("disc", fontName="Helvetica-Oblique", fontSize=6.8, leading=8.6, textColor=GRAY),
}


class Spine:
    """Timeline line and hollow dots for one section, split across pages."""

    def __init__(self, x):
        self.x, self.top, self.dots = x, None, []

    def dot(self, y):
        self.top = y if self.top is None else self.top
        self.dots.append(y)

    def resume(self, top):
        if self.top is not None:
            self.top = top

    def close(self, c, bottom):
        if self.top is None:
            return
        c.saveState()
        c.setStrokeColor(colors.HexColor(TEAL)); c.setFillColor(colors.white); c.setLineWidth(0.9)
        c.line(self.x, self.top, self.x, bottom)
        for y in self.dots:
            c.circle(self.x, y, 3.8, fill=1)
        c.restoreState()
        self.dots = []


class SpineMark(Flowable):
    """Zero-height timeline probe: a dot, or the end of the section."""

    def __init__(self, spine, end=False):
        super().__init__()
        self.spine, self.end = spine, end
        self.width = self.height = 0

    def wrap(self, *a):
        return 0, 0

    def draw(self):
        c = self.canv
        y = c.absolutePosition(0, 0)[1]
        if not self.end:
            self.spine.dot(y - 6)
            return
        x0, y0 = c.absolutePosition(0, 0)
        c.saveState(); c.translate(-x0, -y0)
        self.spine.close(c, y)
        c.restoreState()
        self.spine.top = None


def load_photo(photo):
    if not photo:
        return None
    req = urllib.request.Request(photo["url"], headers={"User-Agent": "resume-template"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return ImageReader(io.BytesIO(r.read()))


def draw_circuit(c, PH):
    """Traces branching from the photo ring. y values are measured from the page top."""
    def line(points, color, width):
        c.setStrokeColor(colors.HexColor(color)); c.setLineWidth(width)
        p = c.beginPath(); p.moveTo(points[0][0], PH - points[0][1])
        for x, y in points[1:]:
            p.lineTo(x, PH - y)
        c.drawPath(p, stroke=1, fill=0)

    def node(p, big):
        c.setStrokeColor(colors.HexColor(CORAL if big else TEAL)); c.setLineWidth(0.8)
        c.setFillColor(colors.HexColor(CORAL) if big else colors.white)
        c.circle(p[0], PH - p[1], 3.6 if big else 2.4, stroke=1, fill=1)

    c.saveState(); c.setLineCap(1); c.setLineJoin(1)
    for side in (-1, 1):
        for i, (y0, bend, y1, end, branch) in enumerate(ROUTES):
            x0 = math.sqrt(RING ** 2 - (y0 - PHOTO_Y) ** 2)
            run = abs(y1 - y0)
            pts = [(PHOTO_X + side * x0, y0), (PHOTO_X + side * bend, y0), (PHOTO_X + side * (bend + run), y1), (PHOTO_X + side * end, y1)]
            line(pts, MINT if i % 2 else TEAL, 0.9)
            node(pts[-1], i % 3 == 0)
            if branch:
                at, by, bend_end = branch
                b = [(PHOTO_X + side * at, y1), (PHOTO_X + side * (at + abs(by - y1)), by), (PHOTO_X + side * bend_end, by)]
                line(b, MINT, 0.7)
                node(b[-1], False)
    c.setStrokeColor(colors.HexColor(TEAL)); c.setLineWidth(1.3)
    c.circle(PHOTO_X, PH - PHOTO_Y, RING, stroke=1, fill=0)
    c.restoreState()


def draw_photo(c, image, link, PH):
    x, y, r = PHOTO_X, PH - PHOTO_Y, PHOTO_R
    c.saveState()
    p = c.beginPath(); p.circle(x, y, r)
    c.clipPath(p, stroke=0, fill=0)
    c.drawImage(image, x - r, y - r, 2 * r, 2 * r, preserveAspectRatio=True, anchor="c", mask="auto")
    c.restoreState()
    if link:
        c.linkURL(link, (x - r, y - r, x + r, y + r), relative=0, thickness=0)


def project_blocks(blocks):
    """Turn final.md project paragraphs into headed entries."""
    out = []
    for b in blocks:
        m = PROJECT.match(b["lines"][0]) if b["t"] == "p" and len(b["lines"]) == 1 else None
        if m:
            out += [{"t": "h3", "text": m[1], "dates": m[2] or "", "where": "", "project": True},
                    {"t": "p", "lines": [m[3]]}]
        else:
            out.append(b)
    return out


def main_section(title, blocks, width, spine):
    def h3(b):
        if b.get("sub"):
            w = width - b.get("rail_indent", 0)
            t = Table([[Paragraph(tint(inline(b["text"], LINK), b), st["sub"]), Paragraph(inline(b["dates"], LINK), st["subr"])]],
                      colWidths=[w * 0.68, w * 0.32])
            t.setStyle(TableStyle([("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                                   ("TOPPADDING", (0, 0), (-1, -1), 0), ("BOTTOMPADDING", (0, 0), (-1, -1), 0)]))
            t.hAlign = "LEFT"
            t.keepWithNext = True
            return [Spacer(1, 4), t]
        if b.get("project"):
            head, sub = b["text"], ""
        else:
            sub, head = b["text"].rsplit(", ", 1) if ", " in b["text"] else ("", b["text"])
        w = width - b.get("rail_indent", 0)
        rows = [[Paragraph(tint(inline(head, LINK), b), st["org"]), Paragraph(inline(b["where"] if sub else b["dates"], LINK), st["right"])]]
        if sub:
            rows.append([Paragraph(inline(sub, LINK), st["lead" if b.get("group") else "title"]), Paragraph(inline(b["dates"], LINK), st["right"])])
        t = Table(rows, colWidths=[w * 0.68, w * 0.32])
        t.setStyle(TableStyle([("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                               ("TOPPADDING", (0, 0), (-1, -1), 0), ("BOTTOMPADDING", (0, 0), (-1, -1), 0)]))
        t.hAlign = "LEFT"
        t.keepWithNext = True
        mark = SpineMark(spine)
        mark.keepWithNext = True
        return [Spacer(1, 5), mark, t]

    if title == "Projects":
        blocks = project_blocks(blocks)
    if title == "Work Experience":
        blocks = group_positions(blocks)
    body = with_overlap_lines(title, blocks, RAIL, lambda bs: blocks_to_flow(bs, st, LINK, h3, lambda b: [], False))
    if title == "Summary":
        body = [SpineMark(spine)] + body
    head = [Indenter(left=-SPINE_W), Paragraph(inline(title, LINK), st["sec"]), Indenter(left=SPINE_W)]
    n = keep_count(body, 2)
    return [KeepTogether(head + body[:n])] + body[n:] + [SpineMark(spine, end=True)]


def side_section(title, blocks, width):
    out = [Paragraph(inline(title, LINK), st["sec"])]
    for b in blocks:
        if b["t"] == "ul":
            out += [Paragraph(lead_bold(i, LINK) if title == "Skills" else inline(i, LINK), st["side"]) for i in b["items"]]
        elif b["t"] == "p":
            out.append(Paragraph("<br/>".join(inline(l, LINK) for l in b["lines"]), st["side"]))
    # A table, because the side column is placed with Frame.addFromList, which cannot place KeepTogether.
    lead = Table([[f] for f in out[:2]], colWidths=[width])
    lead.setStyle(TableStyle([("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                              ("TOPPADDING", (0, 0), (-1, -1), 0), ("BOTTOMPADDING", (0, 0), (-1, -1), 2)]))
    return [Spacer(1, 7), lead] + out[2:]


def main():
    a = args()
    doc = parse(a.input_abs_path)
    PW, PH = A4
    W = PW - 2 * M
    SW = W * 0.31
    MX = M + SW + GAP + SPINE_W
    MW = PW - M - MX
    image = load_photo(doc["photo"])
    top = PH - HEADER if image else PH - M - 46
    spine = Spine(MX - SPINE_W + SPINE_X)
    name = Paragraph(inline(doc["name"], LINK), st["name"])
    contact = Paragraph("&nbsp;&nbsp;&nbsp;".join(inline(l, LINK).replace(" - ", "&nbsp;&nbsp;&nbsp;") for l in doc["contact"]), st["contact"])

    main_flow, side = [], []
    for s in doc["sections"]:
        if s["title"] in MAIN:
            main_flow += main_section(s["title"], s["blocks"], MW, spine)
        else:
            side += side_section(s["title"], s["blocks"], SW)
    if doc["disclaimer"]:
        main_flow += [Spacer(1, 10), Indenter(left=-SPINE_W), HRFlowable(width="100%", thickness=0.4, color=colors.HexColor(MINT), spaceAfter=3),
                      Paragraph("<br/>".join(inline(l, LINK) for l in doc["disclaimer"]), st["disc"]), Indenter(left=SPINE_W)]

    main_flow += source_note(__file__, LINK)

    def draw_side(c, y):
        if side:
            Frame(M, M, SW, y - M, leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0).addFromList(side, c)

    def first(c, d):
        y = PH - 112 if image else PH - M
        if image:
            draw_circuit(c, PH)
            draw_photo(c, image, doc["photo"]["link"], PH)
        for p in (name, contact):
            h = p.wrap(W, PH)[1]; p.drawOn(c, M, y - h); y -= h + 1
        draw_side(c, top)

    def later(c, d):
        spine.resume(PH - M)
        draw_side(c, PH - M)

    def page_end(c, d):
        spine.close(c, M)

    fr = dict(leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    d = BaseDocTemplate(a.output_abs_path, pagesize=A4, leftMargin=M, rightMargin=M, topMargin=M, bottomMargin=M,
                        title=doc["name"], author=doc["name"])
    d.addPageTemplates([PageTemplate("first", [Frame(MX, M, MW, top - M, **fr)], onPage=first, onPageEnd=page_end, autoNextPageTemplate="later"),
                        PageTemplate("later", [Frame(MX, M, MW, PH - 2 * M, **fr)], onPage=later, onPageEnd=page_end)])
    d.build(main_flow)
    if side:
        raise SystemExit("Left column did not fit beside the right column")


if __name__ == "__main__":
    main()
