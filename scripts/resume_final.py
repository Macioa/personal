import argparse, json, re, sys
from pathlib import Path

DISCLAIMER = ("> This resume was created from a database of hand-written personal resume info selected for this role "
    "through a highly-tuned human-in-the-loop AI system and manually reviewed before sending. Details of the generation tool are available from "
    "[github.com/Macioa/resume-and-application-toolkit](https://github.com/Macioa/resume-and-application-toolkit). "
    "Data can be explored from the chat utility at [ryanwademontgomery.com](https://ryanwademontgomery.com).")
EDU = ("bachelors", "masters", "phd")
TRAIN = ("training", "training_certificate")
CERT = ("certificate", "clearance")

def body(p):
    t = p.read_text(encoding="utf-8")
    return re.sub(r"\ATokens: \d+\n\n", "", t).strip()

def link(text, url):
    if not url:
        return text
    return f"[{text}]({url if '://' in url else 'https://' + url})"

def tel_link(raw):
    d = re.sub(r"\D", "", raw)
    if len(d) == 11 and d[0] == "1":
        d = d[1:]
    if len(d) != 10:
        sys.exit(f"Unsupported phone number: {raw}")
    return f"[+1 ({d[:3]}) {d[3:6]}-{d[6:]}](tel:+1{d})"

def load(p):
    return json.loads(body(p))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--output-abs-path", required=True)
    d = Path(ap.parse_args().output_abs_path)
    intro = load(d / "resume-view-intro.md")[0]
    out = [f"# {intro['name']}", ""]
    photo_file = d / "resume-view-profile_photo.md"
    photos = load(photo_file) if photo_file.exists() else []
    if photos:
        image = f"![Profile photo]({photos[0]['photo_url']})"
        out += [f"[{image}]({photos[0]['desc_url']})" if photos[0].get("desc_url") else image, ""]
    emails = [f"[Email](mailto:{e})" for e in intro.get("email", [])]
    phones = [tel_link(p) for p in intro.get("phone", [])]
    out.append(" - ".join(intro.get("location", []) + phones + emails))
    out += [""]
    out.append(" - ".join(f"[{l['name']}]({l['url']})" for l in intro.get("links", [])))
    out += ["", "## Summary", "", body(d / "resume_summary.md"), "", "## Skills", ""]
    for line in body(d / "selected_skills.md").splitlines():
        if not line.strip():
            continue
        if " -> " not in line:
            sys.exit(f"Unparsed skill line: {line}")
        out.append("- " + line.split(" -> ", 1)[1])
    out += ["", "## Work Experience"]
    for e in load(d / "selected_employment.md"):
        loc = e.get("location", "")
        where = (f"{loc} (remote)" if loc else "Remote") if e.get("remote") else loc
        emp = link(e["name"], e.get("website"))
        out += ["", f"### {e['last_title']}, {emp}", f"{e['dates']} | {where}"]
        if e.get("resume_desc"):
            out += ["", e["resume_desc"]]
        if e.get("bullets"):
            links = e.get("bullet_links", {})
            out += [""] + [f"- [{b}]({links[b]})" if b in links else f"- {b}" for b in e["bullets"]]
        if e.get("skills"):
            out += ["", "Skills: " + ", ".join(e["skills"])]
    projects = load(d / "selected_projects.md")
    if projects:
        out += ["", "## Projects"]
        for p in projects:
            dates = f" ({p['dates']})" if p.get("dates") else ""
            out += ["", f"{link(p['name'], p.get('homepage_url'))}{dates} - {p['desc']}"]
            if p.get("tools_used"):
                out += ["", ", ".join(p["tools_used"])]
    ed = load(d / "resume-view-education.md")
    for title, keys, area in (("Training", TRAIN, False), ("Certifications & Clearances", CERT, False), ("Education", EDU, True)):
        rows = [r for k in keys for r in ed.get(k, [])]
        if rows:
            out += ["", f"## {title}", ""]
            out += [f"- **{r['name']}**, {r['dates']}" + (" (expired)" if keys is CERT and "expired" in (r.get("desc_short") or "").lower() else "") + (f", {r['desc_short']}" if area and r.get("desc_short") else "") for r in rows]
    out += ["", "---", "", DISCLAIMER, ""]
    (d / "final.md").write_text("\n".join(out), encoding="utf-8")

if __name__ == "__main__":
    main()
