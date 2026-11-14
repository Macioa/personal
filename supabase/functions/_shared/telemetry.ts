// Edge function telemetry, no dependencies: errors and cron check-ins to Sentry (envelope API), one log record
// per call to Grafana Cloud (OTLP/HTTP JSON, Loki). Each backend is off when its secret is unset:
//   SENTRY_DSN                    Sentry project DSN
//   OTEL_EXPORTER_OTLP_ENDPOINT   Grafana stack OTLP URL (…/otlp)
//   OTEL_EXPORTER_OTLP_HEADERS    "Authorization=Basic%20<base64 instanceId:token>"
// Soft fail: sends run after the response (EdgeRuntime.waitUntil), and any telemetry error is swallowed, so a
// broken Sentry or Grafana never changes or delays what a function returns.

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void } | undefined;

export type Attrs = Record<string, string | number | boolean | null | undefined>;
// Per-call details a handler adds; logged with the call and attached to any error.
export type Note = Attrs;
type Handler = (req: Request, note: Note) => Promise<Response>;

const SERVICE = "personal-supabase";

function safely<T>(fn: () => T): T | undefined {
  try {
    return fn();
  } catch (err) {
    console.warn("telemetry failed", err);
  }
}

const sentry = safely(() => {
  const dsn = Deno.env.get("SENTRY_DSN");
  if (!dsn) return;
  const { protocol, host, username, pathname } = new URL(dsn);
  return { url: `${protocol}//${host}/api${pathname}/envelope/`, key: username, dsn };
});

const grafana = safely(() => {
  const endpoint = Deno.env.get("OTEL_EXPORTER_OTLP_ENDPOINT");
  if (!endpoint) return;
  const headers = Object.fromEntries((Deno.env.get("OTEL_EXPORTER_OTLP_HEADERS") ?? "").split(",").filter(Boolean)
    .map((pair) => {
      // Split at the first "=" only: base64 credentials end in "=" padding.
      const at = pair.indexOf("=");
      return [pair.slice(0, at), pair.slice(at + 1)].map(decodeURIComponent).map((s) => s.trim()) as [string, string];
    }));
  return { url: `${endpoint.replace(/\/$/, "")}/v1/logs`, headers };
});

// Runs the send in the background; it can never reject.
function background(send: () => Promise<unknown>) {
  const p = Promise.resolve().then(send)
    .then((res) => res instanceof Response && !res.ok && console.warn("telemetry send rejected", res.status, res.url))
    .catch((err) => console.warn("telemetry send failed", err));
  safely(() => EdgeRuntime?.waitUntil(p));
  return p;
}

const id = () => crypto.randomUUID().replaceAll("-", "");
const clean = (attrs: Attrs) => Object.fromEntries(Object.entries(attrs).filter(([, v]) => v !== undefined && v !== null));

function envelope(type: string, payload: Record<string, unknown>) {
  if (!sentry) return Promise.resolve();
  const body = [JSON.stringify({ dsn: sentry.dsn, sent_at: new Date().toISOString() }), JSON.stringify({ type }), JSON.stringify(payload)].join("\n");
  return background(() =>
    fetch(sentry.url, {
      method: "POST",
      headers: { "Content-Type": "application/x-sentry-envelope", "X-Sentry-Auth": `Sentry sentry_version=7, sentry_key=${sentry.key}` },
      body,
    })
  );
}

// A Sentry issue: an Error becomes an exception, anything else a message.
export function report(fn: string, problem: unknown, level: "error" | "warning", extra: Attrs = {}) {
  return safely(() =>
    envelope("event", {
      event_id: id(),
      timestamp: Date.now() / 1000,
      platform: "javascript",
      level,
      server_name: SERVICE,
      tags: { function: fn },
      extra: clean(extra),
      ...(problem instanceof Error
        ? { exception: { values: [{ type: problem.name, value: problem.message }] } }
        : { message: { formatted: `${fn}: ${String(problem)}` } }),
    })
  );
}

// A Sentry cron check-in; the monitor is created or updated from monitorConfig.
export function checkIn(slug: string, status: "ok" | "error", monitorConfig: Record<string, unknown>) {
  return safely(() => envelope("check_in", { check_in_id: id(), monitor_slug: slug, status, monitor_config: monitorConfig }));
}

const otlpValue = (v: string | number | boolean) =>
  typeof v === "boolean" ? { boolValue: v } : typeof v === "number" ? (Number.isInteger(v) ? { intValue: v } : { doubleValue: v }) : { stringValue: v };

// One Grafana (Loki) log record named `event` with attrs as attributes.
export function log(event: string, attrs: Attrs, severity: "INFO" | "WARN" | "ERROR" = "INFO") {
  return safely(() => {
    if (!grafana) return Promise.resolve();
    const attributes = Object.entries(clean(attrs)).map(([key, v]) => ({ key, value: otlpValue(v as string | number | boolean) }));
    const record = { timeUnixNano: `${Date.now()}000000`, severityText: severity, body: { stringValue: event }, attributes: [{ key: "event", value: { stringValue: event } }, ...attributes] };
    const body = { resourceLogs: [{ resource: { attributes: [{ key: "service.name", value: { stringValue: SERVICE } }] }, scopeLogs: [{ logRecords: [record] }] }] };
    return background(() => fetch(grafana.url, { method: "POST", headers: { ...grafana.headers, "Content-Type": "application/json" }, body: JSON.stringify(body) }));
  });
}

// The handler with telemetry around it: every call is logged to Grafana (status, ms, note); a thrown error or a
// 5xx goes to Sentry as an error, a 4xx is logged only. The handler's result or error is passed through unchanged.
// Callers whose requests send no telemetry (TELEMETRY_IGNORE_IPS, comma list), e.g. the owner testing.
const ignoredIps = new Set((Deno.env.get("TELEMETRY_IGNORE_IPS") ?? "").split(",").map((ip) => ip.trim()).filter(Boolean));
const ignored = (req: Request) =>
  // x-client-ip: the visitor's IP as forwarded by the homepage's /api/get-jwt proxy.
  [req.headers.get("x-client-ip") ?? "", ...(req.headers.get("x-forwarded-for") ?? "").split(",")].some((ip) => ignoredIps.has(ip.trim()));

export const withTelemetry = (fn: string, handler: Handler) => async (req: Request) => {
  if (safely(() => ignored(req))) return handler(req, {});
  const note: Note = {};
  const started = Date.now();
  const done = (status: number, err?: unknown) =>
    safely(() => {
      const attrs = { function: fn, status, ms: Date.now() - started, ...note };
      log(`${fn}.call`, attrs, status >= 500 ? "ERROR" : status >= 400 ? "WARN" : "INFO");
      if (status >= 500) report(fn, err ?? note.error ?? `HTTP ${status}`, "error", attrs);
    });
  try {
    const res = await handler(req, note);
    done(res.status);
    return res;
  } catch (err) {
    done(500, err);
    throw err;
  }
};
