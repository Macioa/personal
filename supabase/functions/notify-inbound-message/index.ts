// Emails a notification for each new inbound_messages row.
//
// Called by a Database Webhook (Database > Webhooks): table inbound_messages,
// event INSERT, type Supabase Edge Function, plus HTTP header
// x-webhook-secret = WEBHOOK_SECRET. Deploy with --no-verify-jwt.
//
// Secrets (Edge Functions > Secrets):
//   GMAIL_USER      sending Gmail address (from). Required.
//   GMAIL_PASS      16-char Gmail app password. Required.
//   NOTIFY_TO       single notification recipient (to). Required.
//   WEBHOOK_SECRET  must match header x-webhook-secret. Required.
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Constant-time compare for the webhook secret.
function safeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const user = Deno.env.get("GMAIL_USER");
  const pass = Deno.env.get("GMAIL_PASS");
  const to = Deno.env.get("NOTIFY_TO");
  const secret = Deno.env.get("WEBHOOK_SECRET");
  if (!user || !pass || !to || !secret) return json({ error: "not configured" }, 500);

  if (!safeEqual(req.headers.get("x-webhook-secret") ?? "", secret)) {
    return json({ error: "forbidden" }, 403);
  }

  let payload: { type?: string; table?: string; record?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "bad json" }, 400);
  }
  const record = payload.record;
  if (payload.type !== "INSERT" || payload.table !== "inbound_messages" || !record) {
    return json({ error: "unexpected payload" }, 400);
  }

  const from = typeof record.from === "string" && record.from ? record.from : "(anonymous)";
  const client = new SMTPClient({
    connection: {
      hostname: "smtp.gmail.com",
      port: 465,
      tls: true,
      auth: { username: user, password: pass },
    },
  });

  try {
    await client.send({
      from: user,
      to,
      subject: `New chat message from ${from}`,
      content: `From: ${from}\nDate: ${record.date}\n\n${record.message}`,
    });
  } finally {
    await client.close();
  }

  return json({ status: "sent", id: record.id }, 200);
});
