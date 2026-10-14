#!/usr/bin/env node
// Deploy-time wiring for deployables whose composition has no wire-live step
// (cloudflare-workers-assets-turbo). Reads the wiring documents the infra
// components lease-publish — WIRING_<COMPONENT>_<ENV> in the job env, each a
// JSON document — into a temp dir and renders the wrangler template with
// render.mjs. Fails loudly on any unresolved token.
//
//   node live.mjs --template wrangler.template.jsonc --out wrangler.jsonc \
//     --components cloudflare-kv,cloudflare-r2 --envs stage,prod
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const template = arg("template");
const out = arg("out");
const components = (arg("components") ?? "").split(",").filter(Boolean);
const env = arg("env");
const envs = (arg("envs") ?? env ?? "stage,prod").split(",").filter(Boolean);
if (!template || !out || components.length === 0) {
  console.error(
    "usage: live.mjs --template <file> --out <file> --components a,b (--env stage | --envs stage,prod)",
  );
  process.exit(2);
}

const dir = fs.mkdtempSync(path.join(os.tmpdir(), "wiring-"));
const missing = [];
for (const component of components) {
  for (const env of envs) {
    const key = `WIRING_${component.toUpperCase().replace(/-/g, "_")}_${env.toUpperCase()}`;
    const value = process.env[key];
    if (!value) {
      missing.push(key);
      continue;
    }
    fs.writeFileSync(path.join(dir, `${component}__${env}.json`), value);
  }
}
if (missing.length > 0) {
  console.error("wire: missing wiring documents in the environment:");
  for (const m of missing) console.error(`  ${m}`);
  process.exit(1);
}

// A single-environment render (the workers-assets composition deploys one
// environment per job, with no wrangler `--env`): `__ENV__` in the template
// becomes that environment before the wiring tokens are resolved.
let templatePath = template;
if (env) {
  const text = fs.readFileSync(template, "utf8").replace(/__ENV__/g, env);
  templatePath = path.join(dir, path.basename(template));
  fs.writeFileSync(templatePath, text);
}

const render = path.join(path.dirname(fileURLToPath(import.meta.url)), "render.mjs");
const result = spawnSync(
  process.execPath,
  [render, "--template", templatePath, "--out", out, "--secrets-dir", dir],
  { stdio: "inherit" },
);
fs.rmSync(dir, { recursive: true, force: true });
process.exit(result.status ?? 1);
