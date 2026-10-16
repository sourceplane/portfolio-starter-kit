#!/usr/bin/env node
// Give a re-run phase something to land (zero-dependency).
//
// A phase lands as a pull request and is verified by the convergence run that
// follows the merge. When that convergence FAILS — a provider error, a runner
// starved out, a smoke that raced route propagation past its retries — the
// merge has already happened, so every file the phase places is on main. orun
// derives phase state from the files on disk (never from a stored record), so
// a retried build finds the phase placed, and even a forced re-run of it
// produces an EMPTY diff: `orun.pr/land@v1` has nothing to commit, and the
// product's CI (`orun plan --changed`) deploys a component only when one of
// its files changed in the push. Nothing lands, nothing redeploys, and the
// operator is told the phase is fine.
//
// This tool is what the phase's `retouch` hook runs before it stages and
// lands: for each component the phase deploys, it rewrites ONE trailing line
// in that component's `component.yaml`,
//
//     # orun: redeploy <phase> <stamp>
//
// replacing the previous marker if there is one (never accumulating), so the
// landing has a diff and exactly those components are in the changed set. The
// same convention was hand-edited before this existed (`# ci: re-trigger
// deploy …` lines, duplicated by hand); this is that edit with a name, a
// stamp, and a phase to answer for it.
//
// THE MARKER IS A DEPLOY TRIGGER, NOT STATE. Nothing reads it back: orun does
// not learn from it whether a phase ran, and this repository's invariant —
// phase state is DERIVED from the tree, never stored in it — holds. Delete the
// line and nothing is lost but the next redeploy's reason to happen.
//
//   node retouch.mjs --phase 01-product --affects .baseline/tasks/01-product.TaskContract.yaml
//   node retouch.mjs --phase 01-product --components web,web-tests
//
// Options:
//   --phase <name>          the phase the marker names (required)
//   --components a,b,c      the components to touch, by `metadata.name` …
//   --affects <contract>    … or read them from a TaskContract's `spec.affects`
//   --check                 resolve every component and exit non-zero naming
//                           any without a component.yaml; write nothing
//   --dry-run               print what would change; write nothing
//
// The stamp is ORUN_RUN_ID if set, else ORUN_SESSION_ID, else a UTC timestamp
// (YYYYMMDDTHHMMSSZ) — whichever identifies the run that asked for the deploy.
//
// Runs in the product checkout (the phase hooks' working directory). A
// component is found by the `metadata.name` its component.yaml declares, not
// by directory: `apps/web` and `tests/web` both carry one, and only the
// first is named `web`.

import * as fs from "node:fs";
import * as path from "node:path";

const MARKER_RE = /^# orun: redeploy \S+ \S+\r?$/;
const SKIP_DIRS = new Set(["node_modules", ".git", ".orun", "dist", ".next", ".open-next", ".turbo"]);
const MAX_DEPTH = 4;

function usage(msg) {
  if (msg) console.error(`retouch: ${msg}`);
  console.error(
    "usage: retouch.mjs --phase <name> (--components a,b,c | --affects <TaskContract.yaml>) [--check] [--dry-run]",
  );
  process.exit(2);
}

function parseArgs(argv) {
  const opts = { phase: null, components: null, affects: null, check: false, dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => {
      if (i + 1 >= argv.length) usage(`${a} needs a value`);
      return argv[++i];
    };
    if (a === "--phase") opts.phase = next();
    else if (a === "--components") opts.components = next();
    else if (a === "--affects") opts.affects = next();
    else if (a === "--check") opts.check = true;
    else if (a === "--dry-run") opts.dryRun = true;
    else if (a === "-h" || a === "--help") usage();
    else usage(`unknown argument ${a}`);
  }
  if (!opts.phase) usage("--phase is required");
  if (/\s/.test(opts.phase)) usage("--phase must be a single token");
  if (!opts.components && !opts.affects) usage("one of --components or --affects is required");
  if (opts.components && opts.affects) usage("--components and --affects are exclusive");
  return opts;
}

// `spec.affects` from a TaskContract, with a reader small enough to need no
// YAML dependency: the contracts are a flat mapping with one block sequence.
// Accepts the block form (`affects:` then `- name` lines indented under it)
// and the flow form (`affects: [a, b]`).
function readAffects(file) {
  let text;
  try {
    text = fs.readFileSync(file, "utf8");
  } catch (e) {
    console.error(`retouch: cannot read ${file}: ${e.message}`);
    process.exit(1);
  }
  const lines = text.split(/\r?\n/);
  const names = [];
  for (let i = 0; i < lines.length; i++) {
    const m = /^(\s*)affects:\s*(.*?)\s*$/.exec(lines[i]);
    if (!m) continue;
    const indent = m[1].length;
    const inline = m[2].replace(/\s+#.*$/, "");
    if (inline.startsWith("[")) {
      const body = inline.replace(/^\[/, "").replace(/\]\s*$/, "");
      for (const part of body.split(",")) {
        const v = part.trim().replace(/^["']|["']$/g, "");
        if (v) names.push(v);
      }
      break;
    }
    for (let j = i + 1; j < lines.length; j++) {
      const line = lines[j];
      if (/^\s*(#.*)?$/.test(line)) continue;
      const lead = /^(\s*)/.exec(line)[1].length;
      if (lead <= indent) break;
      const item = /^\s*-\s*(.+?)\s*$/.exec(line);
      if (!item) break;
      names.push(item[1].replace(/\s+#.*$/, "").replace(/^["']|["']$/g, ""));
    }
    break;
  }
  if (names.length === 0) {
    console.error(`retouch: ${file} declares no spec.affects — nothing to touch`);
    process.exit(1);
  }
  return names;
}

// `metadata.name` from a component.yaml, read the same minimal way.
function componentName(file) {
  const lines = fs.readFileSync(file, "utf8").split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const m = /^(\s*)metadata:\s*$/.exec(lines[i]);
    if (!m) continue;
    const indent = m[1].length;
    for (let j = i + 1; j < lines.length; j++) {
      const line = lines[j];
      if (/^\s*(#.*)?$/.test(line)) continue;
      const lead = /^(\s*)/.exec(line)[1].length;
      if (lead <= indent) break;
      const nm = /^\s*name:\s*(.+?)\s*$/.exec(line);
      if (nm && lead === indent + 2) return nm[1].replace(/^["']|["']$/g, "");
    }
  }
  return null;
}

// Every component.yaml in the tree, by the name it declares.
function indexComponents(root) {
  const byName = new Map();
  const walk = (dir, depth) => {
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const ent of entries) {
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) {
        if (SKIP_DIRS.has(ent.name) || depth >= MAX_DEPTH) continue;
        walk(full, depth + 1);
      } else if (ent.name === "component.yaml") {
        const name = componentName(full);
        if (!name) continue;
        const rel = path.relative(root, full);
        if (byName.has(name)) {
          console.error(
            `retouch: two component.yaml files declare metadata.name ${name}: ${byName.get(name)} and ${rel}`,
          );
          process.exit(1);
        }
        byName.set(name, rel);
      }
    }
  };
  walk(root, 0);
  return byName;
}

function stamp() {
  for (const key of ["ORUN_RUN_ID", "ORUN_SESSION_ID"]) {
    const v = (process.env[key] || "").trim();
    if (v) return v.replace(/\s+/g, "-");
  }
  return new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

// The file with exactly one marker line, last, and a trailing newline. Every
// other byte is kept as it was.
function retouched(text, marker) {
  const hadTrailingNewline = text.endsWith("\n");
  const lines = text.split("\n");
  if (hadTrailingNewline) lines.pop();
  const kept = lines.filter((l) => !MARKER_RE.test(l));
  // A file that was only a marker, or empty, still ends up valid.
  const body = kept.length ? kept.join("\n") + "\n" : "";
  return body + marker + "\n";
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const root = process.cwd();
  const wanted = opts.components
    ? opts.components.split(",").map((s) => s.trim()).filter(Boolean)
    : readAffects(opts.affects);
  if (wanted.length === 0) usage("no components named");

  const index = indexComponents(root);
  const missing = wanted.filter((n) => !index.has(n));
  if (missing.length) {
    console.error(
      `retouch: no component.yaml declares metadata.name for: ${missing.join(", ")} (looked under ${root})`,
    );
    process.exit(1);
  }
  if (opts.check) {
    for (const n of wanted) console.log(`retouch --check: ${n} -> ${index.get(n)}`);
    console.log(`retouch --check: ${wanted.length} component(s) resolve.`);
    return;
  }

  const marker = `# orun: redeploy ${opts.phase} ${stamp()}`;
  const verb = opts.dryRun ? "would" : "";
  let changed = 0;
  for (const n of wanted) {
    const rel = index.get(n);
    const file = path.join(root, rel);
    const before = fs.readFileSync(file, "utf8");
    const after = retouched(before, marker);
    const had = before.split("\n").some((l) => MARKER_RE.test(l));
    if (after === before) {
      console.log(`retouch: ${rel}: unchanged (marker already ${marker.slice(2)})`);
      continue;
    }
    if (!opts.dryRun) fs.writeFileSync(file, after);
    changed++;
    console.log(`retouch: ${rel}: ${verb ? "would " : ""}${had ? "replace" : "add"} marker`);
  }
  console.log(
    opts.dryRun
      ? `retouch --dry-run: ${changed} of ${wanted.length} file(s) would change; nothing written.`
      : changed > 0
        ? `retouch: ${changed} of ${wanted.length} component.yaml file(s) marked "${marker.slice(2)}" — the landing has a diff.`
        : `retouch: nothing to do (every marker already current).`,
  );
}

main();
