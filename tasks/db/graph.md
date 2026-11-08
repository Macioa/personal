# DB graph

> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

SVG ER diagram of the schema from local `supabase/migrations/*.sql`. Output: `supabase/migrations/schema.svg` (replaced each run). Intermediates go in scratch, not the repo.

1. Write `<scratch>/filter.py` (keeps enums, tables, FK alters from migrations in numeric order; drops functions, policies, triggers, grants, indexes, extensions), then `python -I <scratch>/filter.py > <scratch>/schema.sql` from repo root:
   ```python
   import re,glob,os
   fs=sorted(glob.glob("supabase/migrations/*.sql"),key=lambda f:int(re.match(r"\d+",os.path.basename(f)).group()))
   s="\n".join(open(f,encoding="utf-8").read() for f in fs)
   s=re.sub(r"\$(\w*)\$.*?\$\1\$","",s,flags=re.S)
   s=re.sub(r"--[^\n]*","",s)
   keep=re.compile(r"\s*(create\s+type\s+\S+\s+as\s+enum|create\s+table|alter\s+table\s+.*foreign\s+key)",re.I|re.S)
   print("create table auth.users (id uuid primary key);\n\n"+";\n\n".join(x.strip() for x in s.split(";") if keep.match(x) and not re.search(r"drop\s+constraint",x,re.I))+";")
   ```
2. From `<scratch>`: `npx -y -p @dbml/cli sql2dbml --postgres schema.sql -o schema.dbml` (run there so `dbml-error.log` stays out of the repo).
3. If step 2 fails on a statement: remove it from `schema.sql`, retry, report what was dropped.
4. Clean DBML for the renderer (drops `Checks` blocks, schema prefixes on column types like `extensions.vector`, optional `?` on refs):
   `python -I -c "import re,sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();s=re.sub(r'\n\s*Checks \{.*?\n\s*\}','',s,flags=re.S);s=re.sub(r'(?m)^(\s+\"\w+\" )(?:\w+\.)+(\w+)',r'\1\2',s);s=re.sub(r'(?m)^Ref:.*$',lambda m:m.group(0).replace('?',''),s);open(p,'w',encoding='utf-8').write(s)" <scratch>/schema.dbml`
5. `npx -y @softwaretechnik/dbml-renderer -i <scratch>/schema.dbml -o supabase/migrations/schema.svg`
6. Audit all of `supabase/migrations/*.sql` (full files, not the filtered SQL). Status per check: `pass` (✓) no issues, `warn` (⚠) minor/debatable, `fail` (✗) real defect. Note = short reason naming the worst offenders.
   - **3rd normal form**: repeating groups, non-key columns depending on other non-key columns, duplicated data across tables. Intentional denormalization (caches, snapshots, embeddings) is `warn` at most.
   - **Appropriate indexing**: every FK column (or the leading column of a composite PK/unique) has an index; columns used in RLS policies, `where` in functions, and unique lookups are indexed; no duplicate/redundant indexes.
   - **Key constraints**: every table has a PK; every `*_id` reference has an FK with deliberate `on delete`; natural keys have unique constraints; required columns are `not null`; checks on bounded values.
   - **Least privilege**: RLS enabled on every public table; policies scoped to `auth.uid()`/roles, no `using (true)` for writes; no broad grants to `anon`/`public`; `security definer` functions set `search_path` and are not executable by `anon` unless needed.
   Write `<scratch>/audit.json`: `[{"label":"3rd normal form","status":"pass|warn|fail","note":"..."}, ...]` in the order above. Show the user the table of results.
7. Write `<scratch>/badges.py` and run `python -I <scratch>/badges.py <scratch>/audit.json supabase/migrations/schema.svg` (adds a header band above the diagram; rerunning on a fresh render replaces it):
   ```python
   import json,re,sys,html
   items=json.load(open(sys.argv[1],encoding="utf-8")); p=sys.argv[2]; s=open(p,encoding="utf-8").read()
   m=re.search(r'viewBox="([\d.\-]+) ([\d.\-]+) ([\d.]+) ([\d.]+)"',s); x,y,w,h=map(float,m.groups())
   if 'id="audit"' in s: s=re.sub(r'\n<g id="audit".*?</g><!--/audit-->','',s,flags=re.S); h+=y; y=0.0
   H=120+70*len(items); y0=y-H
   s=s.replace(m.group(0),f'viewBox="{x} {y0} {w} {h+H}"',1)
   s=re.sub(r'<svg width="[\d.]+pt" height="[\d.]+pt"',f'<svg width="{w:.0f}pt" height="{h+H:.0f}pt"',s,count=1)
   sym={"pass":("✓","#1a7f37"),"warn":("⚠","#9a6700"),"fail":("✗","#cf222e")}
   g=[f'\n<g id="audit" font-family="Helvetica,Arial,sans-serif"><rect x="{x}" y="{y0}" width="{w}" height="{H}" fill="white"/>',
      f'<text x="{x+40}" y="{y0+70}" font-size="48" font-weight="bold">Schema audit</text>']
   for i,it in enumerate(items):
       c,col=sym[it["status"]]; ty=y0+140+70*i
       g.append(f'<rect x="{x+40}" y="{ty-40}" width="50" height="50" rx="6" fill="white" stroke="{col}" stroke-width="4"/>'
                f'<text x="{x+65}" y="{ty}" font-size="40" text-anchor="middle" fill="{col}">{c}</text>'
                f'<text x="{x+110}" y="{ty}" font-size="36"><tspan font-weight="bold">{html.escape(it["label"])}</tspan> — {html.escape(it["note"])}</text>')
   s=s.replace("</svg>","".join(g)+"</g><!--/audit-->\n</svg>")
   open(p,"w",encoding="utf-8").write(s)
   ```
8. Open `supabase/migrations/schema.svg`; check every table and FK edge appears.
