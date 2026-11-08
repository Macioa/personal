// Embeds skills/skill_groups (gte-small, 384) and serves search_skills.
// POST {table, id}        -> embed one row (called by trigger; service role writes)
// POST {table, all: true} -> backfill rows with null embedding
// POST {query: string[], mode?} + Authorization -> search_skills as the caller (RLS applies)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const session = new Supabase.ai.Session("gte-small");
const url = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const TABLES = new Set(["skills", "skill_groups"]);

const embed = async (text: string) =>
  JSON.stringify(await session.run(text, { mean_pool: true, normalize: true }));

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

async function embedRows(table: string, ids?: string[]) {
  let q = admin.from(table).select('id, name, "desc"');
  q = ids ? q.in("id", ids) : q.is("embedding", null);
  const { data, error } = await q;
  if (error) throw error;
  for (const r of data ?? []) {
    const text = [r.name, r.desc].filter(Boolean).join(". ");
    const { error: e } = await admin.from(table).update({ embedding: await embed(text) }).eq("id", r.id);
    if (e) throw e;
  }
  return data?.length ?? 0;
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    if (Array.isArray(body.query)) {
      const auth = req.headers.get("Authorization");
      if (!auth) return json({ error: "Authorization required" }, 401);
      const user = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
        global: { headers: { Authorization: auth } },
      });
      const embeddings = await Promise.all(body.query.map((t: string) => embed(t)));
      const { data, error } = await user.rpc("search_skills", {
        p_skills: body.query,
        p_embeddings: embeddings,
        p_mode: body.mode ?? "start_to_end",
      });
      if (error) return json({ error: error.message }, 400);
      return json(data);
    }
    if (!TABLES.has(body.table)) return json({ error: "bad table" }, 400);
    const n = await embedRows(body.table, body.all ? undefined : [body.id]);
    return json({ embedded: n });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
