// Probe live apps. Targets come from the PROBE_TARGETS env var (a JSON array,
// stored as a repo secret so private apps' URLs stay out of this public repo).
//
// Target fields:
//   name      label used in logs and issues (for private apps use a neutral alias)
//   url       what to fetch
//   status    expected HTTP status (default 200); redirects are not followed
//   contains  optional text the response body must contain
//   location  optional substring the Location header must contain (for 30x)
//   ui        optional text a headless browser must see rendered (UI mode only)
//
// Usage: node probe.mjs [--ui] [--out results.json]
// Exit code 0 always; results go to the --out file for the workflow to act on.
import { writeFileSync } from "node:fs";

const args = process.argv.slice(2);
const uiMode = args.includes("--ui");
const outIdx = args.indexOf("--out");
const out = outIdx >= 0 ? args[outIdx + 1] : "results.json";

const targets = JSON.parse(process.env.PROBE_TARGETS || "[]");
if (!targets.length) {
  console.error("PROBE_TARGETS is empty");
  process.exit(1);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// Errors are printed in public logs; never let a URL through.
const scrub = (s) => s && String(s).replace(/https?:\/\/\S+/g, "<url>");

async function httpCheck(t) {
  const want = t.status ?? 200;
  const res = await fetch(t.url, {
    redirect: "manual",
    signal: AbortSignal.timeout(45_000),
    headers: { "user-agent": "AndyFooBlah-uptime/1 (+https://github.com/AndyFooBlah/uptime)" },
  });
  if (res.status !== want) return `HTTP ${res.status}, expected ${want}`;
  if (t.location && !(res.headers.get("location") || "").includes(t.location)) {
    return "redirect went somewhere unexpected";
  }
  if (t.contains) {
    const body = await res.text();
    if (!body.includes(t.contains)) return "expected text missing from response";
  }
  return null;
}

let browser;
async function uiCheck(t) {
  if (!browser) {
    const { chromium } = await import("playwright");
    browser = await chromium.launch();
  }
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  try {
    const res = await page.goto(t.url, { waitUntil: "domcontentloaded", timeout: 60_000 });
    if (!res || res.status() >= 400) return `page HTTP ${res ? res.status() : "none"}`;
    await page.getByText(t.ui, { exact: false }).first().waitFor({ timeout: 45_000 });
    if (errors.length) return `uncaught page error: ${errors[0]}`;
    return null;
  } catch (e) {
    return `UI text not rendered (${String(e.message || e).split("\n")[0].slice(0, 120)})`;
  } finally {
    await page.close();
  }
}

// Up to 3 tries, 20s apart, so a scale-to-zero cold start is not an outage.
async function withRetries(fn, t) {
  let err;
  for (let i = 0; i < 3; i++) {
    try {
      err = await fn(t);
    } catch (e) {
      err = String(e.cause?.code || e.message || e).slice(0, 160);
    }
    if (!err) return null;
    if (i < 2) await sleep(20_000);
  }
  return err;
}

const results = [];
for (const t of targets) {
  const checks = [["http", httpCheck]];
  if (uiMode && t.ui) checks.push(["ui", uiCheck]);
  for (const [kind, fn] of checks) {
    const started = Date.now();
    const error = await withRetries(fn, t);
    const r = { name: t.name, kind, ok: !error, error: scrub(error), ms: Date.now() - started };
    results.push(r);
    console.log(`${r.ok ? "ok  " : "FAIL"} ${kind.padEnd(4)} ${t.name}${r.error ? " — " + r.error : ""}`);
  }
}
if (browser) await browser.close();
writeFileSync(out, JSON.stringify(results, null, 2));
