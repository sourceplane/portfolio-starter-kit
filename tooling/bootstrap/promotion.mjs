#!/usr/bin/env node
// Stage and prod deploy side by side while a product is being bootstrapped
// (zero-dependency).
//
// intent.yaml gates prod behind stage: `environments.prod.promotion.dependsOn:
// [stage]`, which orun plans as an in-run edge from every prod job to the
// same component's stage job. That is the right rule for a product that is
// live — a change reaches prod only after it deployed to stage. During a
// bootstrap it protects nothing (both environments are empty, and every phase
// is watched to green before the next one starts) and it doubles the length
// of every convergence: each worker's prod deploy waits out its stage deploy.
//
// So 01-product defers the gate and 03-docs, the last landing, puts it back:
//
//   node tooling/bootstrap/promotion.mjs --defer     # 01-product, before its landing
//   node tooling/bootstrap/promotion.mjs --restore   # 03-docs, the last landing
//   node tooling/bootstrap/promotion.mjs --check     # prints deferred | enforced
//
// --defer replaces the prod `promotion:` block with one marker comment that
// base64-encodes the exact text removed, so --restore reproduces intent.yaml
// byte-for-byte. Both are idempotent. Restoring is a change to intent.yaml's
// `environments` section only, which `orun plan --changed` (intent impact
// `watch`, the default) maps to no component: the landing that restores it
// deploys nothing.
//
// The gate is deferred, never dropped: a bootstrap that stops before 03-docs
// leaves the marker in intent.yaml, and `--restore` (or a re-run of 03-docs)
// is the whole fix. docs/phases/03-docs.md says so.

import * as fs from "node:fs";

const FILE = process.argv.includes("--file")
  ? process.argv[process.argv.indexOf("--file") + 1]
  : "intent.yaml";
const MARKER = "@promotion-deferred";

function usage() {
  console.error("usage: promotion.mjs --defer | --restore | --check [--file intent.yaml]");
  process.exit(2);
}

// The `promotion:` block of the `prod:` environment: from its `promotion:`
// line up to (not including) the next line indented at or above it.
function findProdPromotion(text) {
  const lines = text.split("\n");
  let inEnvs = false;
  let prodIndent = -1;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^environments:\s*$/.test(line)) {
      inEnvs = true;
      continue;
    }
    if (!inEnvs) continue;
    if (/^\S/.test(line) && line.trim() !== "") break; // left the section
    const prod = /^(\s+)prod:\s*$/.exec(line);
    if (prod) {
      prodIndent = prod[1].length;
      continue;
    }
    if (prodIndent < 0) continue;
    const indent = line.length - line.trimStart().length;
    if (line.trim() !== "" && indent <= prodIndent) {
      prodIndent = -1; // left prod without finding one
      continue;
    }
    const m = /^(\s+)promotion:\s*$/.exec(line);
    if (!m) continue;
    const own = m[1].length;
    let end = i + 1;
    while (end < lines.length) {
      const l = lines[end];
      if (l.trim() !== "" && l.length - l.trimStart().length <= own) break;
      end++;
    }
    return { lines, start: i, end, indent: m[1] };
  }
  return null;
}

function defer() {
  const text = fs.readFileSync(FILE, "utf8");
  if (text.includes(MARKER)) {
    console.log(`promotion --defer: already deferred in ${FILE}`);
    return;
  }
  const found = findProdPromotion(text);
  if (!found) {
    console.log(`promotion --defer: prod has no promotion block in ${FILE} — nothing to defer`);
    return;
  }
  const { lines, start, end, indent } = found;
  const removed = lines.slice(start, end).join("\n");
  const b64 = Buffer.from(removed, "utf8").toString("base64");
  const marker = `${indent}# ${MARKER}:${b64} (tooling/bootstrap/promotion.mjs --restore puts it back)`;
  const out = [...lines.slice(0, start), marker, ...lines.slice(end)].join("\n");
  fs.writeFileSync(FILE, out);
  console.log(`promotion --defer: prod no longer waits on stage until --restore (${FILE})`);
}

function restore() {
  const text = fs.readFileSync(FILE, "utf8");
  const re = new RegExp(`^[ \\t]*# ${MARKER}:([A-Za-z0-9+/=]+).*$`, "m");
  const m = re.exec(text);
  if (!m) {
    console.log(`promotion --restore: nothing deferred in ${FILE}`);
    return;
  }
  const original = Buffer.from(m[1], "base64").toString("utf8");
  fs.writeFileSync(FILE, text.slice(0, m.index) + original + text.slice(m.index + m[0].length));
  console.log(`promotion --restore: prod waits on stage again (${FILE})`);
}

function check() {
  const text = fs.readFileSync(FILE, "utf8");
  console.log(text.includes(MARKER) ? "deferred" : "enforced");
}

const mode = process.argv[2];
if (mode === "--defer") defer();
else if (mode === "--restore") restore();
else if (mode === "--check") check();
else usage();
