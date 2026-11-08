// Embeds skills/skill_groups (gte-small, 384) and serves search_skills.
// POST {table, id}        -> embed one row (called by trigger; service role writes)
// POST {table, all: true} -> backfill rows with null embedding
// POST {query: string[], skillMode?, groupMode?} + Authorization -> search_skills as the caller (RLS applies)
//   skillMode defaults to precise, groupMode to start_to_end (search_skills defaults).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const session = new Supabase.ai.Session("gte-small");
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const EMBED_TABLES: ReadonlySet<string> = new Set(["skills", "skill_groups"]);

type EmbedSkillBody = {
  query?: string[];
  skillMode?: string;
  groupMode?: string;
  table?: string;
  id?: string;
  all?: boolean;
};
type Route = "search" | "embedOne" | "backfill" | "invalid";

const embedText = async (text: string) =>
  JSON.stringify(await session.run(text, { mean_pool: true, normalize: true }));

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

function route({ query, table, id, all }: EmbedSkillBody): Route {
  if (Array.isArray(query)) return "search";
  if (!table || !EMBED_TABLES.has(table)) return "invalid";
  if (all) return "backfill";
  return id ? "embedOne" : "invalid";
}

// Embed rows one at a time (CPU-bound; parallel exhausts the worker), then save in parallel.
// Not upsert: touching name would re-fire the embed trigger, and inserts need NOT NULL columns.
async function embedRows(table: string, ids?: string[]) {
  const base = serviceClient.from(table).select('id, name, "desc"');
  const { data: rows, error } = await (ids ? base.in("id", ids) : base.is("embedding", null));
  if (error) throw error;
  const updates: { id: string; embedding: string }[] = [];
  for (const { id, name, desc } of rows ?? []) {
    updates.push({ id, embedding: await embedText([name, desc].filter(Boolean).join(". ")) });
  }
  const results = await Promise.all(
    updates.map(({ id, embedding }) => serviceClient.from(table).update({ embedding }).eq("id", id)),
  );
  const failed = results.find(({ error }) => error);
  if (failed) throw failed.error;
  return updates.length;
}

// search_skills as the caller, so their role's RLS applies.
async function handleSearch(req: Request, { query = [], skillMode, groupMode }: EmbedSkillBody) {
  const authorization = req.headers.get("Authorization");
  if (!authorization) return json({ error: "Authorization required" }, 401);
  const callerClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
  });
  const embeddings = await Promise.all(query.map(embedText));
  const { data, error } = await callerClient.rpc("search_skills", {
    p_skills: query,
    p_embeddings: embeddings,
    ...(skillMode && { p_skill_mode: skillMode }),
    ...(groupMode && { p_group_mode: groupMode }),
  });
  return error ? json({ error: error.message }, 400) : json(data);
}

async function handleEmbed({ table, id, all }: EmbedSkillBody) {
  const embeddedCount = await embedRows(table!, all ? undefined : [id!]);
  return json({ embedded: embeddedCount });
}

Deno.serve(async (req) => {
  try {
    const body: EmbedSkillBody = await req.json();
    switch (route(body)) {
      case "search":
        return await handleSearch(req, body);
      case "embedOne":
      case "backfill":
        return await handleEmbed(body);
      default:
        return json({ error: "expected {query: string[]} or {table, id | all}" }, 400);
    }
  } catch (err) {
    console.error(err);
    return json({ error: "internal error" }, 500);
  }
});
