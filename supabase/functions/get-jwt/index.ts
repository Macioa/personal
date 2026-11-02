// Hands out 1-hour PostgREST JWTs for the chat and resume_reader roles, so the
// browser never holds a permanent key.
//
// POST { "role": "chat" | "resume_reader" } -> { token, expires_at }
//
// Secrets (Edge Functions > Secrets):
//   LLM_JWT_SECRET    project's legacy JWT secret (Settings > JWT). Required.
//   RESUME_READER_KEY resume_reader tokens need header x-token-key = this.
//                     Unset = resume_reader tokens disabled.
//   ALLOWED_ORIGINS   comma list of allowed Origin values. Unset = any origin.
import { SignJWT } from "npm:jose@5.9.6";

const TTL_SECONDS = 60 * 60;
const ROLES = new Set(["chat", "resume_reader"]);

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",").map((o) => o.trim()).filter(Boolean);

function cors(origin: string | null): Record<string, string> {
  const allow = allowedOrigins.length === 0 ? "*" : origin ?? "";
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Headers": "content-type, x-token-key, apikey, authorization",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function json(body: unknown, status: number, headers: Record<string, string>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}

// Constant-time compare for the resume_reader key.
function safeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const headers = cors(origin);

  if (allowedOrigins.length > 0 && (!origin || !allowedOrigins.includes(origin))) {
    return json({ error: "origin not allowed" }, 403, headers);
  }
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return json({ error: "POST only" }, 405, headers);

  const secret = Deno.env.get("LLM_JWT_SECRET");
  if (!secret) return json({ error: "not configured" }, 500, headers);

  let role: unknown;
  try {
    ({ role } = await req.json());
  } catch {
    return json({ error: "bad json" }, 400, headers);
  }
  if (typeof role !== "string" || !ROLES.has(role)) {
    return json({ error: "role must be chat or resume_reader" }, 400, headers);
  }

  if (role === "resume_reader") {
    const key = Deno.env.get("RESUME_READER_KEY");
    const given = req.headers.get("x-token-key") ?? "";
    if (!key || !safeEqual(given, key)) {
      return json({ error: "forbidden" }, 403, headers);
    }
  }

  const now = Math.floor(Date.now() / 1000);
  const exp = now + TTL_SECONDS;
  const token = await new SignJWT({ role })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setIssuedAt(now)
    .setExpirationTime(exp)
    .sign(new TextEncoder().encode(secret));

  return json({ token, expires_at: exp }, 200, headers);
});
