"""Shared parser for the cover letter template scripts.
Input md: the resume header (# name, optional photo, contact lines), then one `## Cover Letter` section with
blank-line separated paragraphs in this order: date, recipient lines, salutation, body paragraphs, closing lines.
An optional trailing `> ` quote (after a `---` rule) is the disclaimer."""
import os, sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from resume_md import args, parse, inline, source_note  # noqa: E402,F401


def letter(path):
    """-> {name, photo, contact, date, to: [lines], salutation, body: [paragraphs], closing: [lines], disclaimer: [lines]}."""
    doc = parse(path)
    paras = [b["lines"] for s in doc["sections"] for b in s["blocks"] if b["t"] == "p"]
    if len(paras) < 5:
        sys.exit("Cover letter needs: date, recipient, salutation, at least one body paragraph, closing")
    return {"name": doc["name"], "photo": doc["photo"], "contact": doc["contact"],
            "date": " ".join(paras[0]), "to": paras[1], "salutation": " ".join(paras[2]),
            "body": [" ".join(p) for p in paras[3:-1]], "closing": paras[-1], "disclaimer": doc["disclaimer"]}
