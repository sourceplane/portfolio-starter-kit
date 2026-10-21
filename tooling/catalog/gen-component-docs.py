#!/usr/bin/env python3
"""Generate each component's docs (overview / architecture / runbook).

    python3 tooling/catalog/gen-component-docs.py           # write
    python3 tooling/catalog/gen-component-docs.py --check   # fail on drift (CI)

The Orun workspace's Docs library renders the `docs/` folder next to every
`component.yaml`. These pages are generated, not hand-written, because almost
everything in them is already declared somewhere CI validates: the component's
manifest (type, description, dependencies, environments, the secrets a lane
resolves, the smoke), its Worker config (bindings, triggers, the wiring the
deploy fills in), its Terraform (resources and outputs), its migrations and its
package scripts. A hand-written copy of those facts drifts the first time one
changes; a generated one cannot, because `--check` fails the pull request that
changes the fact without the page.

What is NOT derivable (why a component exists, what a failure means for this
product in particular) belongs in the component's `description` and in the
product's own docs, not here.

The pages ship with the component into every product built from this tree, so
they say nothing about where they came from: no factory paths, no generator
path, no provenance. Zero dependencies beyond PyYAML.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

try:
    import yaml
except ImportError:  # pragma: no cover - the contract job installs it
    sys.exit("gen-component-docs needs PyYAML (pip install pyyaml)")

ROOT = pathlib.Path(__file__).resolve().parents[2]
ROOTS = ("apps", "packages", "infra", "tests")
SKIP_DIRS = {"node_modules", "dist", ".turbo", "docs", ".next", ".open-next",
             ".wrangler", ".svelte-kit", ".nuxt", ".output", ".astro", "coverage"}

# Paths a shipped page must never name: products are not placed with them.
FACTORY = re.compile(
    r"repo-blueprint|BOOTSTRAP\.md|(?<![\w.-])(testing|specs|tasks|docs/phases|hooks)/"
    r"|\.baseline/|tooling/(rebrand|bootstrap|catalog)/")


# ── reading what is declared ─────────────────────────────────────────────

def strip_jsonc(text: str) -> str:
    """JSONC → JSON: drop comments outside strings, then trailing commas."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            out.append(c)
            i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def read_json(path: pathlib.Path) -> dict | None:
    try:
        return json.loads(strip_jsonc(path.read_text(encoding="utf-8")))
    except (OSError, ValueError):
        return None


def rel(p: pathlib.Path) -> str:
    return p.relative_to(ROOT).as_posix()


def discover() -> list[dict]:
    found = []
    for root in ROOTS:
        base = ROOT / root
        if not base.is_dir():
            continue
        stack = [base]
        while stack:
            d = stack.pop()
            for entry in sorted(d.iterdir()):
                if entry.is_dir():
                    if entry.name in SKIP_DIRS or entry.name.startswith("."):
                        continue
                    if (entry / "main.tf").exists() and not (entry / "component.yaml").exists():
                        continue
                    if len(entry.relative_to(base).parts) <= 3:
                        stack.append(entry)
                elif entry.name == "component.yaml":
                    found.append(read_component(entry))
    comps = [c for c in found if c["name"] and c["type"]]
    return sorted(comps, key=lambda c: c["name"])


def read_component(file: pathlib.Path) -> dict:
    doc = yaml.safe_load(file.read_text(encoding="utf-8")) or {}
    meta, spec = doc.get("metadata") or {}, doc.get("spec") or {}
    params = spec.get("parameters") or {}
    deps = [d.get("component") for d in (spec.get("dependsOn") or []) if isinstance(d, dict)]
    envs = []
    # Secrets may be declared for the whole component or per environment
    # (`subscribe.environments[].secretEnv`); a page lists both.
    req_env = set((spec.get("secretEnv") or {}).keys())
    opt_env = set((spec.get("optionalSecretEnv") or {}).keys())
    for e in ((spec.get("subscribe") or {}).get("environments") or []):
        req_env |= set((e.get("secretEnv") or {}).keys())
        opt_env |= set((e.get("optionalSecretEnv") or {}).keys())
        rules = [(r.get("profile"), ((r.get("when") or {}).get("triggerRef")))
                 for r in (e.get("profileRules") or [])]
        envs.append({"name": e.get("name"), "profile": e.get("profile"), "rules": rules})
    return {
        "dir": file.parent,
        "path": rel(file.parent),
        "name": meta.get("name"),
        "description": (meta.get("description") or "").strip(),
        "type": spec.get("type"),
        "deps": [d for d in deps if d],
        "secret_env": sorted(req_env),
        "optional_env": sorted(opt_env - req_env),
        "envs": envs,
        "params": params,
        "migrations_path": spec.get("path") if spec.get("type") == "db-migrate" else None,
    }


def package_of(c: dict) -> dict | None:
    return read_json(c["dir"] / "package.json")


def worker_config(c: dict) -> tuple[str | None, dict | None]:
    """The config a deploy uses: the template when wiring renders one."""
    names = ["wrangler.template.jsonc", c["params"].get("wranglerConfig") or "",
             "wrangler.jsonc", "wrangler.json"]
    for name in names:
        if name and (c["dir"] / name).is_file():
            return name, read_json(c["dir"] / name)
    return None, None


WIRING = re.compile(r"@@wiring\(([^/)]+)/__ENV__:([^)]+)\)@@")


def wired(value) -> str | None:
    m = WIRING.search(str(value)) if value is not None else None
    return f"`{m.group(2)}` from `{m.group(1)}`" if m else None


def bindings(cfg: dict) -> list[tuple[str, str, str]]:
    rows = []
    for kv in cfg.get("kv_namespaces") or []:
        rows.append((kv.get("binding"), "Workers KV namespace", wired(kv.get("id")) or "declared in the config"))
    for b in cfg.get("r2_buckets") or []:
        rows.append((b.get("binding"), "R2 bucket", wired(b.get("bucket_name")) or f"`{b.get('bucket_name')}`"))
    for d in cfg.get("d1_databases") or []:
        rows.append((d.get("binding"), "D1 database", wired(d.get("database_id")) or "declared in the config"))
    for h in cfg.get("hyperdrive") or []:
        rows.append((h.get("binding"), "Hyperdrive (pooled Postgres)", wired(h.get("id")) or "declared in the config"))
    if isinstance(cfg.get("ai"), dict) and cfg["ai"].get("binding"):
        rows.append((cfg["ai"]["binding"], "Workers AI", "account-level; no resource to provision"))
    for d in ((cfg.get("durable_objects") or {}).get("bindings") or []):
        rows.append((d.get("name"), "Durable Object", f"class `{d.get('class_name')}`"))
    for s in cfg.get("services") or []:
        rows.append((s.get("binding"), "Service binding", f"Worker `{s.get('service')}`"))
    for q in ((cfg.get("queues") or {}).get("producers") or []):
        rows.append((q.get("binding"), "Queue producer", f"queue `{q.get('queue')}`"))
    for r in cfg.get("ratelimits") or []:
        simple = r.get("simple") or {}
        rows.append((r.get("name"), "Rate limiter",
                     f"{simple.get('limit')} requests / {simple.get('period')}s per location"))
    assets = cfg.get("assets") or {}
    if assets.get("binding"):
        rows.append((assets["binding"], "Static assets", f"`{assets.get('directory')}`"))
    return [r for r in rows if r[0]]


def tf_facts(c: dict) -> dict:
    tf_dir = c["dir"] / (c["params"].get("terraformDir") or "terraform")
    resources, outputs, variables, backend = [], [], [], None
    for f in sorted(tf_dir.glob("*.tf")) if tf_dir.is_dir() else []:
        text = f.read_text(encoding="utf-8")
        resources += [f"{t}.{n}" for t, n in re.findall(r'^resource\s+"([^"]+)"\s+"([^"]+)"', text, re.M)]
        outputs += re.findall(r'^output\s+"([^"]+)"', text, re.M)
        variables += re.findall(r'^variable\s+"([^"]+)"', text, re.M)
        m = re.search(r'backend\s+"([^"]+)"', text)
        backend = backend or (m.group(1) if m else None)
    imports = (tf_dir / "adopt.tf").is_file() if tf_dir.is_dir() else False
    return {"dir": rel(tf_dir) if tf_dir.is_dir() else None, "resources": resources,
            "outputs": outputs, "variables": variables, "backend": backend, "adopt": imports}


def published(c: dict) -> list[tuple[str, str]]:
    spec = c["params"].get("secretOutputs") or ""
    pairs = []
    for part in str(spec).split(","):
        if "=" in part:
            k, v = part.split("=", 1)
            pairs.append((k.strip(), v.strip()))
    return pairs


def test_files(c: dict) -> list[str]:
    out = []
    for p in sorted(c["dir"].rglob("*")):
        if any(part in SKIP_DIRS for part in p.relative_to(c["dir"]).parts):
            continue
        if p.is_file() and re.search(r"\.(test|spec)\.(ts|tsx|js|mjs|cjs)$", p.name):
            out.append(p.name)
    return out


def migrations(c: dict) -> list[str]:
    path = c["migrations_path"]
    if not path:
        return []
    d = ROOT / path
    if not d.is_dir():
        return []
    return sorted(p.name for p in d.iterdir() if p.is_dir() or p.suffix == ".sql")


# ── markdown ─────────────────────────────────────────────────────────────

def md_table(header: list[str], rows: list[list[str]]) -> list[str]:
    """A table laid out the way prettier lays it out, so a repo whose lint is
    `prettier --check` accepts the page as written."""
    cols = len(header)
    width = [max(3, len(header[i]), *(len(r[i]) for r in rows)) for i in range(cols)]
    def line(cells):
        return "| " + " | ".join(c.ljust(width[i]) for i, c in enumerate(cells)) + " |"
    return [line(header), "| " + " | ".join("-" * w for w in width) + " |", *(line(r) for r in rows)]


# ── phrasing ─────────────────────────────────────────────────────────────

KIND = {
    "cloudflare-worker-turbo": "A Cloudflare Worker, deployed per environment by its CI lane.",
    "cloudflare-workers-assets-turbo": "A Cloudflare Worker with Static Assets (server rendering plus "
                                       "static files), deployed per environment by its CI lane.",
    "terraform": "Terraform-managed infrastructure, planned and applied per environment by its CI lane.",
    "db-migrate": "Applies this repository's ordered database migrations per environment: "
                  "plan on pull requests, apply on merge to `main`.",
    "turbo-package": "A workspace package built by the turbo pipeline. It deploys nothing itself: "
                     "its lane type-checks, lints, tests and builds it.",
}

TRIGGER = {"github-push-main": "a push to `main`", "github-pull-request": "a pull request"}


def env_line(e: dict) -> str:
    s = f"`{e['name']}`: `{e['profile']}`"
    for profile, ref in e["rules"]:
        s += f", `{profile}` on {TRIGGER.get(ref, f'`{ref}`')}"
    return s


def is_tests(c: dict) -> bool:
    return c["name"].endswith("-tests") or c["path"].startswith("tests/")


def subject_of(c: dict, by_name: dict) -> str | None:
    if c["name"].endswith("-tests"):
        s = c["name"][: -len("-tests")]
        return s if s in by_name else None
    return None


def names_list(c: dict, keep) -> list[str]:
    """Secret names a lane resolves, required first; an optional one (from
    `optionalSecretEnv`) is resolved when it exists and skipped when not."""
    req = [f"- `{k}`" for k in c["secret_env"] if keep(k)]
    opt = [f"- `{k}` (optional)" for k in c["optional_env"] if keep(k)]
    return req + opt


def bullet_list(names: list[str], by_name: dict) -> list[str]:
    if not names:
        return ["- (none)"]
    out = []
    for n in names:
        d = by_name.get(n)
        out.append(f"- **{n}** — {d['description']}" if d and d["description"] else f"- **{n}**")
    return out


# ── pages ────────────────────────────────────────────────────────────────

def overview(c: dict, by_name: dict, dependents: list[str]) -> str:
    pkg = package_of(c)
    kind = KIND.get(c["type"], f"A `{c['type']}` component.")
    subject = subject_of(c, by_name)
    if is_tests(c):
        kind = (f"The test suite for **{subject}**. " if subject else "A test suite. ") + \
               "It deploys nothing: its lane installs, builds and runs the tests."
    lines = [f"# {c['name']}", ""]
    if c["description"]:
        lines += [c["description"], ""]
    facts = [["Type", f"`{c['type']}`"], ["Source", f"`{c['path']}`"]]
    if pkg and pkg.get("name"):
        facts.append(["Package", f"`{pkg['name']}`"])
    if c["envs"]:
        facts.append(["Environments", " · ".join(env_line(e) for e in c["envs"])])
    lines += [kind, "", *md_table(["", ""], facts)]
    lines += ["", "## Depends on", "", *bullet_list(c["deps"], by_name),
              "", "## Depended on by", "", *bullet_list(dependents, by_name), ""]
    return "\n".join(lines)


def architecture(c: dict, by_name: dict) -> str:
    lines = [f"# {c['name']} — architecture", ""]
    t = c["type"]

    if t == "terraform":
        f = tf_facts(c)
        lines += [f"A `terraform` root at `{f['dir'] or c['path']}`.", ""]
        if f["backend"] == "http":
            lines += ["- **State** lives in the Orun Cloud HTTP state backend — no local state and",
                      "  no state bucket to manage."]
        lines += ["- **Credentials are brokered per run** from the workspace's provider",
                  "  connections and resolved by name; none is stored in this repository."]
        if f["adopt"]:
            lines += ["- **Adoption** (`adopt.tf`): when state is empty but the resource already",
                      "  exists, plan-time import adopts it instead of failing."]
        lines.append("")
        if f["resources"]:
            lines += ["## Resources", "", *[f"- `{r}`" for r in f["resources"]], ""]
        pub = published(c)
        if pub:
            lines += ["## Published outputs", "",
                      "Written as job-output secrets on each environment after an apply; deploy",
                      "lanes downstream resolve them by name.", "",
                      *md_table(["Secret", "Terraform output"], [[f"`{k}`", f"`{v}`"] for k, v in pub]), ""]
        elif f["outputs"]:
            lines += ["## Outputs", "", *[f"- `{o}`" for o in f["outputs"]], ""]
        if c["secret_env"] or c["optional_env"]:
            lines += ["## Resolved at run time (names only)", "", *names_list(c, lambda k: True), ""]
        return "\n".join(lines)

    if t == "db-migrate":
        migs = migrations(c)
        lines += [f"Applies the migrations under `{c['migrations_path']}` in order, recording each one",
                  "it applies so a run only ever applies what is new. An already-applied migration",
                  "is never edited: a change is a new, later migration.", ""]
        if migs:
            lines += ["## Migrations", "", *[f"- `{m}`" for m in migs], ""]
        if c["secret_env"] or c["optional_env"]:
            lines += ["## Resolved at run time (names only)", "", *names_list(c, lambda k: True), ""]
        return "\n".join(lines)

    pkg = package_of(c)
    if t.startswith("cloudflare-"):
        cfg_name, cfg = worker_config(c)
        lines += [f"Built by the turbo pipeline from `{c['path']}` and deployed with wrangler.", ""]
        if cfg:
            facts = [["Worker config", f"`{c['path']}/{cfg_name}`"]]
            if cfg.get("main"):
                facts.append(["Entry", f"`{cfg['main']}`"])
            if cfg.get("compatibility_date"):
                facts.append(["Compatibility date", f"`{cfg['compatibility_date']}`"])
            if cfg.get("compatibility_flags"):
                facts.append(["Compatibility flags", ", ".join(f"`{x}`" for x in cfg["compatibility_flags"])])
            lines += [*md_table(["", ""], facts), ""]
            rows = bindings(cfg)
            lines += ["## Bindings", ""]
            if rows:
                lines += [*md_table(["Binding", "Kind", "Source"], [[f"`{b}`", k, s] for b, k, s in rows]), ""]
                if any("from `" in s for _, _, s in rows):
                    lines += ["Identifiers marked _from_ a component are filled in at deploy time from",
                              "that component's published outputs for the environment being deployed.", ""]
            else:
                lines += ["None: the Worker binds no storage or service.", ""]
            crons = (cfg.get("triggers") or {}).get("crons") or []
            if crons:
                lines += ["## Scheduled triggers", "", *[f"- `{x}`" for x in crons], ""]
            env_names = sorted((cfg.get("env") or {}).keys())
            var_names = sorted((cfg.get("vars") or {}).keys())
            if var_names:
                lines += ["## Variables", "", ", ".join(f"`{v}`" for v in var_names)
                          + (f" — overridden per environment ({', '.join(f'`{e}`' for e in env_names)})."
                             if env_names else "."), ""]
        wiring = names_list(c, lambda k: k.startswith("WIRING_"))
        others = names_list(c, lambda k: not k.startswith("WIRING_"))
        if wiring:
            lines += ["## Wiring", "",
                      "Resolved at deploy time from secrets the infrastructure lanes publish (names only):",
                      "", *wiring, ""]
        if others:
            lines += ["## Secrets resolved by the lane (names only)", "", *others, ""]
        return "\n".join(lines)

    # turbo-package
    if is_tests(c):
        files = test_files(c)
        lines += [f"A test package at `{c['path']}`. Its lane runs the suite before it builds.", ""]
        if files:
            lines += [f"## Suites ({len(files)})", "", *[f"- `{f}`" for f in files], ""]
        return "\n".join(lines)
    lines += [f"A workspace package at `{c['path']}`, consumed by the components that depend",
              "on it. It has no deployed surface of its own.", ""]
    if pkg and pkg.get("exports"):
        ex = pkg["exports"]
        keys = sorted(ex.keys()) if isinstance(ex, dict) else ["."]
        lines += ["## Exports", "", *[f"- `{k}`" for k in keys], ""]
    return "\n".join(lines)


def runbook(c: dict, by_name: dict) -> str:
    t = c["type"]
    pkg = package_of(c)
    lines = [f"# {c['name']} — runbook", "", "## How it runs", ""]
    deploys = [e["name"] for e in c["envs"]
               if any(ref == "github-push-main" for _, ref in e["rules"])]
    if deploys and t in ("terraform", "db-migrate"):
        lines += [f"Pull requests plan it; a merge to `main` applies it to "
                  f"{', '.join(f'`{e}`' for e in deploys)}."]
    elif deploys:
        lines += [f"Pull requests verify it; a merge to `main` deploys it to "
                  f"{', '.join(f'`{e}`' for e in deploys)}."]
    else:
        lines += ["Its lane runs on every pull request that changes it; it has no deployed surface."]
    lines += ["CI plans what changed (`orun plan --changed`) and runs each lane with `orun run`;",
              "the plan orders a component after everything it depends on.", ""]

    if pkg and pkg.get("scripts"):
        name = pkg.get("name")
        wanted = [s for s in ("dev", "build", "test", "typecheck", "lint", "preview") if s in pkg["scripts"]]
        if name and wanted:
            lines += ["## Local commands", "", "```bash",
                      *[f"pnpm --filter {name} {s}" for s in wanted], "```", ""]

    smoke = c["params"].get("smokeCommand")
    if smoke and "No smoke" not in str(smoke):
        lines += ["## Verify", "", "After a deploy the lane runs this smoke against the environment it",
                  "deployed (`ORUN_ENVIRONMENT`); `DEPLOYED_URL` overrides the URL:", "",
                  "```bash", str(smoke).strip(), "```", ""]

    lines += ["## Rollback", "",
              "Revert the commit on `main`. The next convergence applies the previous desired",
              "state; nothing was changed out of band, so there is nothing else to undo.", "",
              "## Common failures", ""]
    if t == "terraform":
        lines += ["- **Provider authentication fails**: the workspace's provider connection is",
                  "  missing or revoked. Reconnect it in the console; credentials are brokered",
                  "  from it per run.",
                  "- **\"Already exists\" on a first apply**: state is empty but the resource is",
                  "  not." + (" `adopt.tf` imports it at plan time; if it still fails, the resource"
                              " was renamed outside Terraform." if tf_facts(c)["adopt"] else
                              " Import it, or delete the stray resource, then re-run."), ""]
    elif t == "db-migrate":
        lines += ["- **An applied migration's file changed**: the run stops rather than guess.",
                  "  Restore the file and write the change as a new migration.",
                  "- **The database is unreachable**: the infrastructure lane it depends on has",
                  "  not applied for this environment; that lane runs first in a convergence.", ""]
    elif t.startswith("cloudflare-"):
        _, cfg = worker_config(c)
        takes_wiring = any(k.startswith("WIRING_") for k in c["secret_env"] + c["optional_env"]) or \
            bool(cfg and WIRING.search(json.dumps(cfg)))
        if takes_wiring:
            lines += ["- **A `WIRING_*` secret is missing at deploy**: an infrastructure lane upstream",
                      "  has not applied for this environment yet. Within one convergence the plan",
                      "  runs it first; on its own, re-run that lane."]
        lines += ["- **The smoke fails right after a first deploy**: a new workers.dev route can",
                  "  answer 4xx for a few seconds and the lane retries. A failure that persists",
                  "  is a regression in the deployed code.", ""]
    else:
        lines += ["- **A dependent fails to build after a change here**: run `pnpm typecheck`",
                  "  across the workspace before merging.", ""]
    return "\n".join(lines)


# ── main ─────────────────────────────────────────────────────────────────

def main() -> int:
    check = "--check" in sys.argv[1:]
    comps = discover()
    if not comps:
        print("no component.yaml found", file=sys.stderr)
        return 1
    by_name = {c["name"]: c for c in comps}
    dependents: dict[str, list[str]] = {c["name"]: [] for c in comps}
    for c in comps:
        for d in c["deps"]:
            dependents.setdefault(d, []).append(c["name"])

    drifted, written, leaks = [], 0, []
    for c in comps:
        pages = {
            "overview.md": overview(c, by_name, sorted(dependents.get(c["name"], []))),
            "architecture.md": architecture(c, by_name),
            "runbook.md": runbook(c, by_name),
        }
        for fname, body in pages.items():
            target = c["dir"] / "docs" / fname
            for n, line in enumerate(body.splitlines(), 1):
                m = FACTORY.search(line)
                if m:
                    leaks.append(f"{rel(target)}:{n} would name {m.group(0)!r}")
            current = target.read_text(encoding="utf-8") if target.exists() else None
            if current == body:
                continue
            if check:
                drifted.append(rel(target))
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(body, encoding="utf-8")
            written += 1

    if leaks:
        print("✗ a generated page would name a path products do not have:", file=sys.stderr)
        for l in leaks:
            print(f"    {l}", file=sys.stderr)
        return 1
    if check:
        if drifted:
            print(f"✗ {len(drifted)} component doc(s) differ from what the manifests say:", file=sys.stderr)
            for f in drifted:
                print(f"    {f}", file=sys.stderr)
            print("\nRun: python3 tooling/catalog/gen-component-docs.py", file=sys.stderr)
            return 1
        print(f"✓ component docs match {len(comps)} component.yaml file(s)")
        return 0
    print(f"✓ wrote {written} page(s) for {len(comps)} component(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
