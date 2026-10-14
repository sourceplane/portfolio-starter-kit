#!/usr/bin/env node
// BF6 deploy-time wiring renderer (zero-dependency).
//
// Renders a wrangler config from a committed template by substituting wiring
// tokens of the form:
//
//   @@wiring(<component>/<env>:<key>)@@
//
// Token values come from one of two sources:
//   --map <file>          a single JSON file: { "<component>/<env>": { "<key>": "..." } }
//                         (the committed wiring.fixture.json — offline PR dry-runs)
//   --secrets-dir <dir>   one JSON file per component/env named <component>__<env>.json,
//                         each containing that environment's payload (fetched from
//                         AWS Secrets Manager by the composition's wire-live step)
//
// Fails loudly listing every unresolved token — a missing wiring key must
// never produce a deployable config.
//
// Usage:
//   node render.mjs --template wrangler.template.jsonc --out wrangler.jsonc --map wiring.fixture.json
//   node render.mjs --template wrangler.template.jsonc --out wrangler.jsonc --secrets-dir /tmp/wiring

import * as fs from "node:fs";
import * as path from "node:path";

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const templatePath = arg("template");
const outPath = arg("out");
const mapPath = arg("map");
const secretsDir = arg("secrets-dir");

if (!templatePath || !outPath || (!mapPath && !secretsDir)) {
  console.error(
    "usage: render.mjs --template <file> --out <file> (--map <file> | --secrets-dir <dir>)",
  );
  process.exit(2);
}

const envName = arg("env");
// `__ENV__` names the environment a single-environment config is rendered
// for (see live.mjs); a fixture render picks one the same way.
const template = fs
  .readFileSync(templatePath, "utf8")
  .replace(/__ENV__/g, envName ?? "stage");
const TOKEN_RE = /@@wiring\(([a-z0-9-]+)\/([a-z0-9-]+):([a-zA-Z0-9_]+)\)@@/g;

/** "component/env" -> payload object */
const sources = new Map();

function payloadFor(component, env) {
  const id = `${component}/${env}`;
  if (sources.has(id)) return sources.get(id);
  let payload;
  if (mapPath) {
    const map = JSON.parse(fs.readFileSync(mapPath, "utf8"));
    payload = map[id];
  } else {
    const file = path.join(secretsDir, `${component}__${env}.json`);
    if (fs.existsSync(file)) payload = JSON.parse(fs.readFileSync(file, "utf8"));
  }
  sources.set(id, payload);
  return payload;
}

const unresolved = [];
const rendered = template.replace(TOKEN_RE, (token, component, env, key) => {
  const payload = payloadFor(component, env);
  const value = payload?.[key];
  if (typeof value !== "string" || value.length === 0) {
    unresolved.push(token);
    return token;
  }
  return value;
});

if (unresolved.length > 0) {
  console.error("wire: unresolved wiring tokens:");
  for (const t of unresolved) console.error(`  ${t}`);
  process.exit(1);
}

// Guard: a rendered config must contain no leftover *well-formed* tokens.
// (A fresh regex — TOKEN_RE is /g-stateful; doc comments describing the token
// shape with <placeholders> intentionally do not match.)
if (/@@wiring\([a-z0-9-]+\/[a-z0-9-]+:[a-zA-Z0-9_]+\)@@/.test(rendered)) {
  console.error("wire: rendered output still contains wiring tokens");
  process.exit(1);
}

fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
fs.writeFileSync(outPath, rendered);
console.log(
  `wire: rendered ${path.basename(outPath)} from ${path.basename(templatePath)} (${sources.size} wiring source(s))`,
);
