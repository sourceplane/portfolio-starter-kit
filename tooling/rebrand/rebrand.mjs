#!/usr/bin/env node
// Rebrand renamer for the portfolio-starter-kit baseline (zero-dependency).
//
// This repository is a baseline: a product is instantiated from it, branded,
// and deployed as somebody's own site. This script rewrites every *instance
// identity* literal in the product tree — repo slug, the site's display name,
// its source-repository link, the product domain, Cloudflare worker resource
// names (so an instance is account-safe even when it shares an account with
// another), the workers.dev subdomain placeholder — to the values in a values
// file, and leaves *org-owned* identity alone (the orun state backend, the
// `sourceplane.io` manifest apiVersion, company mailboxes).
//
// The engine is Cirrus's (sourceplane/cirrus-baseline tooling/rebrand): the
// FROM side declared in `.baseline/identity.json`, every written value held
// opaque until the last rule has run, and a leftover sweep that fails on any
// identity a rule did not rename. The rules are this tree's.
//
// Usage (from the product root, on a git tree with the files staged):
//   node tooling/rebrand/rebrand.mjs --values .rebrand/values.json [--dry-run] [--allow-dirty]
//   node tooling/rebrand/rebrand.mjs --verify [--values .rebrand/values.json]
//
// Values file (see tooling/rebrand/values.example.json):
//   {
//     "reponame":          "acme-notes",          // required — repo slug
//     "productname":       "Acme Notes",          // required — the site's display name
//     "productdomain":     "acme.dev",            // optional — default <reponame>.example.com (set later)
//     "githuborg":         "acme-inc",            // owner of the product repo (source link)
//     "brandSlug":         "acme",                // default: reponame — worker name prefix
//     "subdomain":         "acme",                // default: your-workers-subdomain
//     "orunWorkspace":     "ws_XXXXXXXX",         // the segment secret refs name
//     "orunWorkspaceSlug": "acme-space"           // optional: wins over orunWorkspace there
//   }
//
// Modes:
//   (default)   apply the rename map in place, then run the leftover sweep
//   --dry-run   report per-rule match counts; change nothing
//   --verify    only run the leftover sweep (non-zero exit on residue)

import { execFileSync } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

// ── Inputs ─────────────────────────────────────────────────────

function flag(name) {
  return process.argv.includes(`--${name}`);
}
function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const dryRun = flag("dry-run");
const verifyOnly = flag("verify");

let values = {};
// --verify takes --values too, optionally: without them it cannot tell the
// product's own identity from a leftover of the baseline's.
const valuesPath = arg("values");
if (!verifyOnly && !valuesPath) {
  console.error("usage: rebrand.mjs --values <file> [--dry-run] | --verify [--values <file>]");
  process.exit(2);
}
if (valuesPath) {
  values = JSON.parse(fs.readFileSync(valuesPath, "utf8"));
  for (const required of ["reponame", "productname"]) {
    if (typeof values[required] !== "string" || values[required].length === 0) {
      console.error(`rebrand: values file is missing required field "${required}"`);
      process.exit(2);
    }
  }
}

// ── THE BASELINE'S OWN IDENTITY — the FROM side, declared ──────
//
// Read from `.baseline/identity.json` beside THIS SCRIPT, not the working
// directory: the rebrand runs with its cwd set to the PRODUCT being branded,
// and a product does not carry `.baseline/` (no module places it). The phase
// hooks invoke this as `node {{ .baseline.dir }}/tooling/rebrand/rebrand.mjs`,
// so the script's own path is the one thing that always points at the
// baseline. `--baseline-identity <file>` overrides it (the test suite pins one).
//
//   slug         the repo slug: intent name, worker prefix, secret project
//   pascal       the code-identifier form (swept for, never expected)
//   productName  the display name, as the SITE_NAME seam spells it
//   domain       the product domain (BASE_DOMAIN)
//   subdomain    the workers.dev subdomain this tree carries
//   githubOwner  the owner in the site's source link
const BASELINE_IDENTITY_FILE =
  arg("baseline-identity") ??
  path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "..", ".baseline", "identity.json");
const BASELINE_DEFAULTS = {
  slug: "portfolio-starter-kit",
  pascal: "PortfolioStarterKit",
  productName: "My Portfolio",
  domain: "portfolio-starter-kit.example.com",
  subdomain: "your-workers-subdomain",
  githubOwner: "sourceplane",
};
const baseline = (() => {
  let declared = {};
  try {
    declared = JSON.parse(fs.readFileSync(BASELINE_IDENTITY_FILE, "utf8"));
  } catch {
    declared = {}; // absent is fine: the defaults ARE this baseline's identity
  }
  const id = { ...BASELINE_DEFAULTS };
  for (const k of Object.keys(BASELINE_DEFAULTS)) {
    if (declared[k] !== undefined) id[k] = declared[k];
  }
  for (const [k, v] of Object.entries(id)) {
    if (typeof v !== "string" || v.length === 0) {
      console.error(`rebrand: ${BASELINE_IDENTITY_FILE} field "${k}" must be a non-empty string`);
      process.exit(2);
    }
  }
  if (/[^a-z0-9-]/.test(id.slug)) {
    console.error(`rebrand: ${BASELINE_IDENTITY_FILE} "slug" must be a lowercase slug ([a-z0-9-])`);
    process.exit(2);
  }
  return { ...id, envPrefix: id.slug.toUpperCase().replace(/-/g, "_") };
})();
// Regex-escape, for the rules that build a pattern out of the identity.
const rx = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// All fields are unused under --verify; the fallbacks keep derivation total.
const reponame = values.reponame ?? "";
const productname = values.productname ?? "";
// The domain is NOT ASKED at bootstrap: a site goes live on workers.dev and an
// owner sets a domain later. Until then the reserved placeholder
// `<reponame>.example.com` (RFC 2606 — it can never be someone else's) stands
// wherever the domain goes, so setting it is replacing one string.
const productdomain = (values.productdomain ?? "").trim() || (reponame ? `${reponame}.example.com` : "");
const githuborg = (values.githuborg ?? "").trim() || baseline.githubOwner;
const brandSlug = (values.brandSlug ?? "").trim() || reponame;
const subdomain = (values.subdomain ?? "").trim() || "your-workers-subdomain";
// A `secret://<workspace>/<project>/<env>/<KEY>` ref names the WORKSPACE first
// and the project (repo) second. The workspace segment is the product's
// workspace — an explicit slug if one was given, else the ws_… id itself
// (the platform's resolve accepts a slug, a public id or a ws_ ref) — and the
// repo name only as the last resort when no workspace was given at all.
const orunWorkspaceSlug = (() => {
  const explicit = (values.orunWorkspaceSlug ?? "").trim();
  if (explicit) return explicit;
  const ws = (values.orunWorkspace ?? "").trim();
  if (ws) return ws;
  return reponame;
})();

if (!verifyOnly && /[^a-z0-9-]/.test(`${reponame}${brandSlug}`)) {
  console.error("rebrand: reponame/brandSlug must be lowercase slugs ([a-z0-9-])");
  process.exit(2);
}
if (!verifyOnly && /[^A-Za-z0-9-]/.test(githuborg)) {
  console.error("rebrand: githuborg must be a GitHub owner name ([A-Za-z0-9-])");
  process.exit(2);
}

// In-place rewrite of the whole tree: insist on a clean checkout so the
// result is reviewable as one diff (and trivially revertible).
if (!verifyOnly && !dryRun && !flag("allow-dirty")) {
  const status = execFileSync("git", ["status", "--porcelain"], { encoding: "utf8" });
  if (status.trim().length > 0) {
    console.error("rebrand: working tree is not clean — commit/stash first (or pass --allow-dirty)");
    process.exit(2);
  }
}

// ── File set ───────────────────────────────────────────────────

// Tracked text files only. Exclusions are generated/locked artifacts, this
// tool and the identity it reads, and binary content.
const EXCLUDE_RE = new RegExp(
  [
    "^tooling/rebrand/",
    "^\\.rebrand/",
    // The baseline's declared identity. Renaming its contents would make the
    // product claim to be a baseline called by the product's own name.
    "^\\.baseline/",
    "^pnpm-lock\\.yaml$",
    "\\.(png|jpg|jpeg|ico|gif|webp|woff2?|ttf|eot)$",
  ].join("|"),
);

function trackedFiles() {
  return execFileSync("git", ["ls-files"], { encoding: "utf8" })
    .split("\n")
    .filter((f) => f.length > 0 && !EXCLUDE_RE.test(f))
    .filter((f) => {
      // `git ls-files` also lists gitlinks (a grounded sandbox checkout carries
      // `baseline/` as one) and paths deleted from disk. Only regular files
      // are sweepable.
      try {
        return fs.statSync(f).isFile();
      } catch {
        return false;
      }
    });
}

// ── Protected literals (org-owned identity, never rewritten) ───
//
// Masked before the rules run and restored after, so no rename can touch the
// org's shared infrastructure identity.
const PROTECTED = [
  /https:\/\/orun-api\.sourceplane\.ai/g, // orun state backend
  /sourceplane\.io/g, // manifest apiVersion, owned by the orun tooling
  /[A-Za-z0-9._%+-]+@sourceplane\.ai/g, // company mailboxes
];
const MASK = (i, j) => `\u0000REBRAND_PROTECTED_${i}_${j}\u0000`;

// ── Substituted values are opaque ──────────────────────────────
//
// The rules run in sequence over one buffer. If each wrote its VALUE into it,
// every later rule could match that value again — a product whose domain
// contains the baseline's slug would have it renamed a second time by the
// repo-slug rule, and every phase of a bootstrap re-runs this over the whole
// tree. So a rule writes a TOKEN standing for its value, and every token is
// expanded once, after the last rule. A token is NUL, `H<n>`, NUL; its outer
// characters take the word/non-word class of the value's own edges, so a
// later rule's `\b` sees the boundary the value would have given it.
const heldValues = [];
const heldIndex = new Map();
function hold(value) {
  if (value === "") return "";
  let i = heldIndex.get(value);
  if (i === undefined) {
    i = heldValues.push(value) - 1;
    heldIndex.set(value, i);
  }
  const edge = (c) => (/\w/.test(c) ? "0" : "\u0001");
  return `${edge(value[0])}\u0000H${i}\u0000${edge(value[value.length - 1])}`;
}
const HELD_RE = /[0\u0001]\u0000H(\d+)\u0000[0\u0001]/g;
function release(text) {
  return text.replace(HELD_RE, (_, i) => heldValues[Number(i)]);
}

// ── Worker resource names ──────────────────────────────────────
//
// Every Cloudflare worker ships prefixed with the slug (`<slug>-<base>`, the
// base being its `apps/<base>/` directory): the component's `workerName`, the
// environment URLs, the deploy smoke. Re-prefix it so an instance's workers
// never collide with another's in a shared account.
function workerBases(files) {
  const bases = new Set();
  for (const file of files) {
    const m = /^apps\/([^/]+)\//.exec(file);
    if (m) bases.add(m[1]);
  }
  return [...bases];
}

// ── Rename map (ordered, most specific first) ──────────────────

function literalPairs() {
  return [
    // The site's source link (apps/web/app/site.ts SOURCE_URL, the docs).
    // Before the repo-slug rule, which would otherwise rename only its tail
    // and leave the link pointing at the baseline's owner.
    [`github.com/${baseline.githubOwner}/${baseline.slug}`, `github.com/${githuborg}/${reponame}`, "source repository link"],
    // The product domain wherever it is the product's (BASE_DOMAIN, docs).
    // Before the repo-slug rule: the placeholder domain starts with the slug.
    [baseline.domain, productdomain, "product domain"],
    // The workers.dev subdomain (component parameters, build origin, intent
    // environment URLs, docs).
    [baseline.subdomain, subdomain, "workers.dev subdomain"],
  ];
}

function regexPairs(files) {
  const list = [
    // The display-name seam. JSON.stringify writes a valid TS string for any
    // name the card's pattern admits (apostrophes and ampersands included).
    {
      re: new RegExp(`SITE_NAME = "${rx(baseline.productName)}"`, "g"),
      replacement: () => `SITE_NAME = ${JSON.stringify(productname)}`,
      label: "site name seam",
    },
    // Secret refs: `secret://<workspace>/<project>/…`. MUST precede the
    // repo-slug pass, which would otherwise rewrite only the project half. The
    // workspace segment is ANY segment — a ws_… id or a slug.
    {
      re: new RegExp(`\\bsecret://[A-Za-z0-9_-]+/${rx(baseline.slug)}/`, "g"),
      replacement: () => `secret://${orunWorkspaceSlug}/${reponame}/`,
      label: "secret ref workspace/project",
    },
  ];

  const bases = workerBases(files);
  if (bases.length > 0) {
    // Longest-first so an alternation never matches a shorter prefix of a base.
    const wb = bases.slice().sort((a, b) => b.length - a.length).map(rx).join("|");
    list.push({
      re: new RegExp(`\\b${rx(baseline.slug)}-(${wb})\\b`, "g"),
      replacement: (_m, base) => `${brandSlug}-${base}`,
      label: "worker CF name",
    });
  }

  // Repo slug: intent metadata.name and per-env `repo:` params, the root
  // package name, docs. Runs AFTER the worker pass so `<slug>-<base>` has
  // already been consumed.
  list.push({
    re: new RegExp(`\\b${rx(baseline.slug)}\\b`, "g"),
    replacement: () => reponame,
    label: "repo slug",
  });
  return list;
}

// ── Leftover sweep ─────────────────────────────────────────────
//
// After a rebrand (or under --verify) every remaining baseline-identity
// literal is residue: either org-owned (allowed, masked above) or a missed
// rename (reported, non-zero exit). The pascal form and the env-var prefix
// have no rule because nothing in this tree spells them; they are swept so
// that the first file that does fails here, naming itself, rather than
// shipping the baseline's name.
//
// The placeholder subdomain is residue only when the product changed it — a
// product that kept the placeholder has not deployed yet, and that is not a
// missed rename. Under --verify without values it is skipped for the same
// reason.
const subdomainChanged = !verifyOnly && subdomain !== baseline.subdomain;
const RESIDUE_RE = new RegExp(
  (subdomainChanged ? `${rx(baseline.subdomain)}|` : "") +
    [
      `\\b${rx(baseline.slug)}\\b`,
      `${rx(baseline.slug)}-`,
      rx(baseline.pascal),
      `${rx(baseline.envPrefix)}_`,
      rx(baseline.domain),
    ].join("|"),
  "g",
);
const ALLOWED_RESIDUE = [
  /https:\/\/orun-api\.sourceplane\.ai/, // orun state backend
  /[A-Za-z0-9._%+-]+@sourceplane\.ai/, // company mailboxes
];

function sweep(files, allowedLiterals = []) {
  const residue = [];
  for (const file of files) {
    let text;
    try {
      text = fs.readFileSync(file, "utf8");
    } catch {
      continue;
    }
    for (const line of text.split("\n")) {
      let cleaned = ALLOWED_RESIDUE.reduce((l, re) => l.replace(new RegExp(re.source, "g"), ""), line);
      // The rename's own TARGET values: a product legitimately named with the
      // baseline's slug inside it is not residue.
      for (const lit of allowedLiterals) {
        if (lit) cleaned = cleaned.split(lit).join("");
      }
      if (new RegExp(RESIDUE_RE.source).test(cleaned)) {
        residue.push(`${file}: ${line.trim().slice(0, 120)}`);
      }
    }
  }
  return residue;
}

// ── Main ───────────────────────────────────────────────────────

const files = trackedFiles();
const literals = literalPairs();
const regexes = regexPairs(files);

// Every value a rule can write. A value some rule would match again is HELD
// wherever it already stands: every phase of a bootstrap re-runs this over the
// whole tree, so what an earlier phase wrote is input to the next pass and
// must come out of it unchanged.
const produced = [
  ...literals.map(([, to]) => to),
  `SITE_NAME = ${JSON.stringify(productname)}`,
  `secret://${orunWorkspaceSlug}/${reponame}/`,
  reponame,
  ...workerBases(files).map((base) => `${brandSlug}-${base}`),
].filter((v, i, all) => v && all.indexOf(v) === i);
const rematchable = (v) =>
  literals.some(([from]) => v.includes(from)) || regexes.some(({ re }) => new RegExp(re.source).test(v));
// Longest first, so a held value is never split by a shorter one inside it.
const guarded = produced.filter(rematchable).sort((a, b) => b.length - a.length);
const allowedTargets = produced.filter((to) => new RegExp(RESIDUE_RE.source).test(to));

if (verifyOnly) {
  const residue = sweep(files, valuesPath ? allowedTargets : []);
  if (residue.length > 0) {
    console.error(`rebrand --verify: ${residue.length} baseline-identity leftover(s):`);
    for (const r of residue) console.error(`  ${r}`);
    process.exit(1);
  }
  console.log("rebrand --verify: no baseline-identity leftovers.");
  process.exit(0);
}

const counts = new Map();
const touched = new Set();
const count = (label, n = 1) => counts.set(label, (counts.get(label) ?? 0) + n);

for (const file of files) {
  let text;
  try {
    text = fs.readFileSync(file, "utf8");
  } catch {
    continue;
  }
  if (text.includes("\0")) continue; // binary safety net
  const original = text;

  const masks = [];
  PROTECTED.forEach((re, i) => {
    text = text.replace(re, (m) => {
      const token = MASK(i, masks.length);
      masks.push([token, m]);
      return token;
    });
  });

  // What a previous pass already wrote stays as written.
  for (const value of guarded) text = text.split(value).join(hold(value));

  for (const [from, to, label] of literals) {
    const n = text.split(from).length - 1;
    if (n === 0) continue;
    text = text.split(from).join(hold(to));
    count(label, n);
  }
  for (const { re, replacement, label } of regexes) {
    text = text.replace(re, (...m) => {
      count(label);
      return hold(replacement(...m));
    });
  }

  // Every rule has run; only now do the values it wrote appear.
  text = release(text);
  for (const [token, value] of masks) text = text.split(token).join(value);

  if (text !== original) {
    touched.add(file);
    if (!dryRun) fs.writeFileSync(file, text);
  }
}

console.log(`rebrand${dryRun ? " (dry-run)" : ""}: ${touched.size} file(s) affected`);
for (const [label, n] of counts) console.log(`  ${String(n).padStart(5)}  ${label}`);
if (dryRun) process.exit(0);

const residue = sweep(trackedFiles(), allowedTargets);
if (residue.length > 0) {
  console.error(`rebrand: ${residue.length} baseline-identity leftover(s) after rename:`);
  for (const r of residue) console.error(`  ${r}`);
  process.exit(1);
}
console.log("rebrand: leftover sweep clean.");
