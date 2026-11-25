"""Colored duration lines for overlapping employments. Jobs without an overlap render untouched.
Lines sit side by side on the left, text sits beside the furthest line, and line lengths are compressed to the text."""
import re
from collections import namedtuple
from datetime import date
from itertools import count
from reportlab.lib import colors
from reportlab.platypus import Indenter, Spacer
from reportlab.platypus.flowables import Flowable

RailStyle = namedtuple("RailStyle", "colors width lane_gap text_gap")
SECTION = "Work Experience"
DATE = re.compile(r"(?:(\d{1,2})/)?(\d{4})")
_forms = count()


def _span(dates):
    """-> (start, end, latest_start, earliest_end) in months. Year-only dates stay conservative for overlap checks."""
    found = DATE.findall(dates or "")
    if not found:
        return None
    (sm, sy), (em, ey) = found[0], found[-1]
    start = int(sy) * 12 + int(sm or 1) - 1
    latest = int(sy) * 12 + int(sm or 12) - 1
    if "present" in dates.lower():
        end = earliest = date.today().year * 12 + date.today().month - 1
    else:
        end = int(ey) * 12 + int(em or 12) - 1
        earliest = int(ey) * 12 + int(em or 1) - 1
    return start, end, latest, earliest


def _overlaps(a, b):
    return bool(a["span"] and b["span"]) and a["span"][2] < b["span"][3] and b["span"][2] < a["span"][3]


def assign_lanes(jobs):
    """Lane per job, left to right in listed order."""
    return list(range(len(jobs)))


class _Rails:
    """Tracks where a job group lands across pages, then draws its lines once the whole group is placed."""

    def __init__(self, jobs, lanes, style):
        self.jobs, self.lanes, self.style = jobs, lanes, style
        self.segments, self.tops, self.current = [], [], None

    def _open(self, top, frame):
        d0 = self.segments[-1]["d1"] if self.segments else 0
        self.current = {"top": top, "d0": d0, "form": f"employmentRail{next(_forms)}"}
        self.x = frame._x1 + frame._leftPadding

    def _close(self, canv, bottom):
        s = self.current
        s["bottom"], s["d1"] = bottom, s["d0"] + s["top"] - bottom
        self.segments.append(s)
        self.current = None
        canv.saveState()
        x, y = canv.absolutePosition(0, 0)
        canv.translate(-x, -y)
        canv.doForm(s["form"])
        canv.restoreState()

    def _hook(self, canv):
        original = canv.showPage

        def show_page():
            frame = canv._doctemplate.frame
            self._close(canv, frame._y1 + frame._bottomPadding)
            original()
            canv.showPage = show_page
            top_frame = canv._doctemplate.frame
            self.current = {"top": None, "d0": self.segments[-1]["d1"], "form": f"employmentRail{next(_forms)}"}
            self.pending = top_frame
        self.original, canv.showPage = original, show_page

    def _resume(self, frame):
        if self.current and self.current["top"] is None:
            self.current["top"] = frame._y1 + frame._height - frame._topPadding

    def mark(self, canv, frame, y):
        if self.current is None:
            self._open(y, frame)
            self._hook(canv)
        self._resume(frame)
        s = self.current
        self.tops.append(s["d0"] + s["top"] - y)

    def finish(self, canv, frame, y):
        self._resume(frame)
        canv.showPage = self.original
        self._close(canv, y)
        total = self.segments[-1]["d1"]
        order = sorted(range(len(self.jobs)), key=lambda i: -self.jobs[i]["span"][1])
        anchors, reach = [], 0
        for i in order:
            reach = max(reach, self.tops[i])
            anchors.append((self.jobs[i]["span"][1], reach))
        anchors.append((min(j["span"][0] for j in self.jobs), total))

        def to_dist(m):
            for (m1, d1), (m2, d2) in zip(anchors, anchors[1:]):
                if m2 <= m <= m1:
                    return d1 if m1 == m2 else d1 + (m1 - m) / (m1 - m2) * (d2 - d1)
            return total

        st = self.style
        for s in self.segments:
            canv.beginForm(s["form"])
            canv.setLineWidth(st.width)
            canv.setLineCap(1)
            for i, job in enumerate(self.jobs):
                a = max(min(self.tops[i], to_dist(job["span"][1])), s["d0"])
                b = min(max(to_dist(job["span"][0]), self.tops[i] + st.width * 3), s["d1"])
                if b <= a:
                    continue
                lane = self.lanes[i]
                x = self.x + lane * (st.width + st.lane_gap) + st.width / 2
                canv.setStrokeColor(colors.HexColor(st.colors[lane % len(st.colors)]))
                canv.line(x, s["top"] - (a - s["d0"]) - st.width / 2, x, s["top"] - (b - s["d0"]) + st.width / 2)
            canv.endForm()


class _Marker(Flowable):
    """Zero-height position probe inside the story."""

    def __init__(self, rails, final=False):
        super().__init__()
        self.rails, self.final = rails, final
        self.width = self.height = 0

    def wrap(self, *a):
        return 0, 0

    def draw(self):
        y = self.canv.absolutePosition(0, 0)[1]
        (self.rails.finish if self.final else self.rails.mark)(self.canv, self._frame, y)


def group_positions(blocks):
    """Consecutive positions at one company: the latest keeps the full heading, earlier ones drop the company name
    and are marked `sub`, and all their Skills lines merge into one listing after the last position."""
    org = lambda b: b["text"].rsplit(", ", 1)[1] if b["t"] == "h3" and ", " in b["text"] else None
    is_skills = lambda b: b["t"] == "p" and len(b["lines"]) == 1 and b["lines"][0].startswith("Skills: ")
    jobs = []
    for b in blocks:
        if b["t"] == "h3" or not jobs:
            jobs.append([b])
        else:
            jobs[-1].append(b)
    out, i = [], 0
    while i < len(jobs):
        j = i + 1
        while j < len(jobs) and org(jobs[i][0]) and org(jobs[j][0]) == org(jobs[i][0]):
            j += 1
        run = jobs[i:j]
        if len(run) > 1:
            skills = []
            for k, job in enumerate(run):
                for b in job:
                    if is_skills(b):
                        skills += [s for s in b["lines"][0][8:].split(", ") if s not in skills]
                body = [b for b in job[1:] if not is_skills(b)]
                head = dict(job[0], group=True) if k == 0 else dict(job[0], text=job[0]["text"].rsplit(", ", 1)[0], sub=True)
                out += [head] + body
            out.append({"t": "p", "lines": ["Skills: " + ", ".join(skills)]})
        else:
            out += run[0]
        i = j
    return out


def tint(markup, block):
    """Color a job heading to match its line."""
    color = block.get("rail_color")
    if not color:
        return markup
    markup = re.sub(r'(<a [^>]*color=")[^"]*', rf"\g<1>{color}", markup)
    return f'<font color="{color}">{markup}</font>'


def keep_count(flow, n):
    """Extend a leading slice of `n` flowables past line control flowables."""
    i = kept = 0
    while i < len(flow) and kept < n:
        kept += not isinstance(flow[i], (_Marker, Indenter))
        i += 1
    return i


def _group(jobs, style, render):
    lanes = assign_lanes(jobs)
    indent = (max(lanes) + 1) * (style.width + style.lane_gap) - style.lane_gap + style.text_gap
    rails = _Rails(jobs, lanes, style)
    out = []
    for i, job in enumerate(jobs):
        head = dict(job["blocks"][0], rail_indent=indent, rail_color=style.colors[lanes[i] % len(style.colors)])
        flow = render([head] + job["blocks"][1:])
        if flow and isinstance(flow[0], Spacer):
            out.append(flow.pop(0))
        out.append(_Marker(rails))
        if i == 0:
            out.append(Indenter(left=indent))
        out += flow
    return out + [Indenter(left=-indent), _Marker(rails, final=True)]


def with_overlap_lines(title, blocks, style, render):
    """Render a section, adding lines to overlapping employments. render(blocks) -> flowables."""
    if title != SECTION:
        return render(blocks)
    prefix, jobs = [], []
    for b in blocks:
        if b["t"] == "h3" and b.get("sub") and jobs:
            # Earlier position at the same company: widen the company's line to cover it.
            jobs[-1]["blocks"].append(b)
            s, t = jobs[-1]["span"], _span(b["dates"])
            if s and t:
                jobs[-1]["span"] = (min(s[0], t[0]), max(s[1], t[1]), min(s[2], t[2]), max(s[3], t[3]))
        elif b["t"] == "h3":
            jobs.append({"blocks": [b], "span": _span(b["dates"])})
        elif jobs:
            jobs[-1]["blocks"].append(b)
        else:
            prefix.append(b)
    runs = []
    for job in jobs:
        if runs and any(_overlaps(job, other) for other in runs[-1]):
            runs[-1].append(job)
        else:
            runs.append([job])
    if all(len(r) == 1 for r in runs):
        return render(blocks)
    out = render(prefix) if prefix else []
    for run in runs:
        out += _group(run, style, render) if len(run) > 1 else render(run[0]["blocks"])
    return out
