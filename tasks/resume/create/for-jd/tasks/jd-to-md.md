# JD to MD

Do not read the JD or the scripts. Use only the commands below.

Args are absolute paths:
- `<abs jd>`: JD.
- `<abs output>`: `<repo path>/temp/applications/[company-role]/temp/original_jd.md`

1. By JD extension:
   - `.md`: `python -c "import shutil,sys; shutil.copyfile(sys.argv[1], sys.argv[2])" "<abs jd>" "<abs output>"`
   - `.docx`: `python scripts/docx_to_md.py --input-abs-path "<abs jd>" --output-abs-path "<abs output>"` ([docx_to_md.py](../../../../../scripts/docx_to_md.py))
   - `.pdf`: `python scripts/pdf_to_md.py --input-abs-path "<abs jd>" --output-abs-path "<abs output>"` ([pdf_to_md.py](../../../../../scripts/pdf_to_md.py))
