#!/usr/bin/env node
// A product carries no work tree of the baseline's (zero-dependency).
//
// This repository's intent.yaml declares where ITS work lives:
//
//   work:
//     epics: specs/epics
//     tasks: tasks
//     sync: on-merge
//
// and `orun plan` on main reconciles that tree into the workspace's work
// plane. A site built from this baseline has neither directory — `specs/` and
// `tasks/` are the factory's, and the leak gate keeps them out — and its
// bootstrap work is opened on the platform by the build itself. Left in, the
// block would point the product's every plan at two directories that do not
// exist.
//
// So 01-product removes it from the product's copy, before its landing:
//
//   node tooling/bootstrap/work-tree.mjs --strip    # 01-product
//   node tooling/bootstrap/work-tree.mjs --check    # prints declared | absent
//
// The block removed is the top-level `work:` key with everything indented
// under it, and the comment lines directly above it that belong to it. It is
// not put back: a product that wants a work tree declares its own. Idempotent.
import * as fs from "node:fs";

const FILE = process.argv.includes("--file")
  ? process.argv[process.argv.indexOf("--file") + 1]
  : "intent.yaml";

function usage() {
  console.error("usage: work-tree.mjs --strip | --check [--file intent.yaml]");
  process.exit(2);
}

function findWork(lines) {
  const start = lines.findIndex((l) => /^work:\s*(#.*)?$/.test(l));
  if (start < 0) return null;
  let end = start + 1;
  while (end < lines.length && (lines[end].trim() === "" || /^\s/.test(lines[end]))) end++;
  // Trailing blank lines belong to the gap before the next key, not the block.
  while (end > start + 1 && lines[end - 1].trim() === "") end--;
  // Its own comment: the contiguous `#` lines directly above it.
  let from = start;
  while (from > 0 && /^#/.test(lines[from - 1])) from--;
  return { from, end };
}

function strip() {
  const text = fs.readFileSync(FILE, "utf8");
  const lines = text.split("\n");
  const found = findWork(lines);
  if (!found) {
    console.log(`work-tree --strip: ${FILE} declares no work tree — nothing to do`);
    return;
  }
  let { from, end } = found;
  // Drop one of the blank lines that separated it from its neighbours.
  if (end < lines.length && lines[end].trim() === "" && from > 0 && lines[from - 1].trim() === "") end++;
  fs.writeFileSync(FILE, [...lines.slice(0, from), ...lines.slice(end)].join("\n"));
  console.log(`work-tree --strip: removed the baseline's work tree from ${FILE}`);
}

function check() {
  const lines = fs.readFileSync(FILE, "utf8").split("\n");
  console.log(findWork(lines) ? "declared" : "absent");
}

const mode = process.argv[2];
if (mode === "--strip") strip();
else if (mode === "--check") check();
else usage();
