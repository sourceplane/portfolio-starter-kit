#!/usr/bin/env node
// The dev verify lanes stay off main's convergences while a product is being
// bootstrapped (zero-dependency).
//
// intent.yaml activates `dev` on `github-push-main` as well as on pull
// requests: every merge to main re-verifies every component (builds, tests)
// on the dev rung beside the stage and prod deploys. That is the right rule
// for a product that is live. During a bootstrap it proves nothing — the
// content comes from a pinned baseline whose own CI already ran it, and
// every phase's pull request is checked by `plan` alone — and it costs the
// one thing a bootstrap's wall-clock is made of: runner slots. The site's
// landing is a Next.js build per environment; a third, on the dev rung,
// re-proves what the baseline's own CI already proved and competes with
// stage and prod for the runner pool. (Measured on the Cirrus baseline,
// where this tool comes from: dev took eight of eighteen lanes and stage and
// prod got five each.)
//
// So 01-product defers the trigger and 03-docs, the last landing, puts it
// back, exactly as tooling/bootstrap/promotion.mjs does for prod's gate:
//
//   node tooling/bootstrap/dev-lanes.mjs --defer     # 01-product, before its landing
//   node tooling/bootstrap/dev-lanes.mjs --restore   # 03-docs, the last landing
//   node tooling/bootstrap/dev-lanes.mjs --check     # prints deferred | active
//
// --defer replaces dev's `- github-push-main` trigger line with one marker
// comment that base64-encodes the exact text removed, so --restore
// reproduces intent.yaml byte-for-byte. Both are idempotent. Pull requests
// keep their dev lanes throughout: only the push-to-main activation moves.
//
// The trigger is deferred, never dropped: a bootstrap that stops before
// 03-docs leaves the marker in intent.yaml, and `--restore` (or a re-run of
// 03-docs) is the whole fix.
import * as fs from "node:fs";

const FILE = process.argv.includes("--file")
  ? process.argv[process.argv.indexOf("--file") + 1]
  : "intent.yaml";
const MARKER = "@dev-lanes-deferred";
const TRIGGER = "github-push-main";

function usage() {
  console.error("usage: dev-lanes.mjs --defer | --restore | --check [--file intent.yaml]");
  process.exit(2);
}

// The `- github-push-main` line under environments.dev.activation.triggerRefs.
function findDevPushTrigger(text) {
  const lines = text.split("\n");
  let inEnvs = false;
  let devIndent = -1;
  let inDev = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^environments:\s*$/.test(line)) {
      inEnvs = true;
      continue;
    }
    if (!inEnvs) continue;
    if (/^\S/.test(line) && line.trim() !== "") break; // left the section
    const env = /^(\s+)([A-Za-z0-9_-]+):\s*$/.exec(line);
    if (env && (devIndent < 0 || env[1].length <= devIndent)) {
      inDev = env[2] === "dev";
      if (inDev) devIndent = env[1].length;
      continue;
    }
    if (!inDev) continue;
    if (new RegExp(`^\\s+-\\s+${TRIGGER}\\s*$`).test(line)) return { lines, index: i };
  }
  return { lines, index: -1 };
}

function defer() {
  const text = fs.readFileSync(FILE, "utf8");
  if (text.includes(`# ${MARKER}:`)) {
    console.log(`dev-lanes --defer: already deferred in ${FILE}`);
    return;
  }
  const { lines, index } = findDevPushTrigger(text);
  if (index < 0) {
    console.log(`dev-lanes --defer: dev is not activated on ${TRIGGER} in ${FILE} — nothing to defer`);
    return;
  }
  const original = lines[index];
  const indent = /^(\s*)/.exec(original)[1];
  const b64 = Buffer.from(original, "utf8").toString("base64");
  const marker = `${indent}# ${MARKER}:${b64} (tooling/bootstrap/dev-lanes.mjs --restore puts it back)`;
  const out = [...lines.slice(0, index), marker, ...lines.slice(index + 1)].join("\n");
  fs.writeFileSync(FILE, out);
  console.log(`dev-lanes --defer: dev's verify lanes stay off main's convergences until --restore (${FILE})`);
}

function restore() {
  const text = fs.readFileSync(FILE, "utf8");
  const re = new RegExp(`^[ \\t]*# ${MARKER}:([A-Za-z0-9+/=]+) \\(tooling/bootstrap/dev-lanes\\.mjs --restore puts it back\\)$`, "m");
  const m = re.exec(text);
  if (!m) {
    console.log(`dev-lanes --restore: nothing deferred in ${FILE}`);
    return;
  }
  const original = Buffer.from(m[1], "base64").toString("utf8");
  fs.writeFileSync(FILE, text.slice(0, m.index) + original + text.slice(m.index + m[0].length));
  console.log(`dev-lanes --restore: dev verifies every merge to main again (${FILE})`);
}

function check() {
  const text = fs.readFileSync(FILE, "utf8");
  console.log(text.includes(`# ${MARKER}:`) ? "deferred" : "active");
}

const mode = process.argv[2];
if (mode === "--defer") defer();
else if (mode === "--restore") restore();
else if (mode === "--check") check();
else usage();
