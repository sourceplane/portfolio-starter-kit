#!/usr/bin/env bash
# EVERY COMPONENT THIS REPO SHIPS IS PLACED BY EXACTLY ONE PHASE
# (saas-bootstrap-engine BE5, Tier 0).
#
# `repo-blueprint.yaml` decides what a product is made of. A component that no
# module names is not a component a product gets — and nothing would say so.
# The failure is quiet and late: the fork builds, its CI goes green, and the
# missing piece surfaces when somebody looks for a worker that was never
# copied.
#
# orun already enforces the other half — every MODULE belongs to exactly one
# phase, and a module naming an unknown module is a parse error. What it cannot
# know is what this repository contains, because a blueprint declares what to
# place and not what exists. That is this file's job.
#
# bash + python3 + PyYAML. No network, no orun, no credential.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

echo "── every component against the blueprint that places it"
python3 - "$root" <<'PY'
import pathlib, sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required for the coverage gate (pip install pyyaml)")

root = pathlib.Path(sys.argv[1])
problems = []
def bad(m): problems.append(m)

# A component directory this repository deliberately keeps to itself. Declared
# with its reason rather than skipped by a pattern: "tests/*" would also hide
# the test suite a product genuinely needs, and the next
# baseline-only directory should have to be argued for in a diff.
# EMPTY: every component here is a site's. The baseline's own suites live in
# `testing/`, which is not a component at all and so is not one this gate can
# miss. The map stays so that the next baseline-only directory has to be
# argued for in a diff; the check below refuses an exemption whose directory is
# absent, so a stale entry cannot linger.
BASELINE_ONLY: dict[str, str] = {}

bp = yaml.safe_load((root / "repo-blueprint.yaml").read_text())

# Where each module takes its content from, and which phase places it.
placed_by = {}
for m in bp.get("modules") or []:
    src = (m.get("from") or "").rstrip("/")
    if src:
        placed_by.setdefault(src, []).append(m["name"])
phase_of = {n: ph["name"] for ph in (bp.get("phases") or []) for n in ph["modules"]}

components = sorted(
    p.parent.relative_to(root).as_posix()
    for p in root.rglob("component.yaml")
    if "node_modules" not in p.parts and ".git" not in p.parts
)
if not components:
    sys.exit("no component.yaml anywhere — this check has gone blind")

for comp in components:
    modules = placed_by.get(comp, [])
    reason = BASELINE_ONLY.get(comp)

    if reason and modules:
        bad(f"{comp} is declared baseline-only ({reason}) and yet {modules[0]} "
            f"places it — one of the two is wrong")
        continue
    if reason:
        continue
    if not modules:
        bad(f"{comp} is a component and no module places it. Either add one, or "
            f"declare it baseline-only in this file with the reason.")
        continue
    if len(modules) > 1:
        bad(f"{comp} is placed by {len(modules)} modules ({', '.join(modules)}) "
            f"— a component comes from one place")
        continue
    if modules[0] not in phase_of:
        bad(f"{comp} is placed by {modules[0]}, which is in no phase")

# The other direction: a module naming a path this repo does not have places
# nothing, silently. orun resolves `from` against the source tree and an absent
# path is an empty module, not an error.
for src, modules in sorted(placed_by.items()):
    if not (root / src).exists():
        bad(f"module {modules[0]} takes its content from {src}, which does not "
            f"exist — it would place nothing, and say nothing")

# A directory named baseline-only must actually BE one, or the exemption is
# protecting nothing and will outlive the thing it was written for.
for comp in BASELINE_ONLY:
    if not (root / comp).exists():
        bad(f"{comp} is declared baseline-only and does not exist — drop the entry")

# ── WHAT THE CATALOG SEES OF EACH COMPONENT ───────────────────────────────
#
# Every component ships its generated pages (overview, architecture, runbook)
# and must ATTACH them in `spec.docs`: a `docs/` folder no manifest declares is
# never attached, so a fresh site's Docs library showed nothing for any
# component and the catalog failed every one of them on docs and on runbook.
# A component also needs a description: it is the catalog's one-line answer to
# "what is this", and the test suite had none.
#
# And a domain may not share a component's name. The catalog keys entities by
# name, so the `web` domain (`spec.domain: web`) took the `web` component's
# place, and the site's one deployable was missing from its own catalog
# (seen on the platform's live builds of this baseline).
WANT_DOCS = {"overview": "docs/overview.md", "architecture": "docs/architecture.md", "runbook": "docs/runbook.md"}
names, domains = {}, {}
for comp in components:
    if comp in BASELINE_ONLY:
        continue
    doc = yaml.safe_load((root / comp / "component.yaml").read_text()) or {}
    meta, spec = doc.get("metadata") or {}, doc.get("spec") or {}
    names[meta.get("name")] = comp
    if spec.get("domain"):
        domains.setdefault(spec["domain"], comp)
    if not (meta.get("description") or "").strip():
        bad(f"{comp}/component.yaml has no metadata.description — the catalog shows the component with nothing to say")
    docs = spec.get("docs") or {}
    got = {"overview": docs.get("overview")}
    for page in docs.get("pages") or []:
        got[page.get("role")] = page.get("path")
    for role, path in WANT_DOCS.items():
        if got.get(role) != path:
            bad(f"{comp}/component.yaml does not attach {path} as its {role} "
                f"(spec.docs) — the page ships and the catalog never sees it")
        elif not (root / comp / path).is_file():
            bad(f"{comp}/component.yaml attaches {path}, which does not exist")
for domain, comp in sorted(domains.items()):
    if domain in names:
        bad(f"{comp} declares domain `{domain}`, which is also the name of the "
            f"component in {names[domain]} — the catalog keeps one of the two")

# ── WHAT `ignore` ACTUALLY EXCLUDES (BE6) ──────────────────────────────────
#
# orun matches an ignore entry two ways, and WHICH ONE depends on the entry:
# a pattern containing no glob metacharacter is compared against each path
# SEGMENT, and only a pattern containing one is compared against the whole
# relative path. So `apps/admin-worker/wrangler.jsonc` matches nothing at all —
# no segment is ever equal to it — and the entry is INERT while reading exactly
# like a rule.
#
# That was not hypothetical. Twelve such entries were inert in this file's own
# blueprint, and a canary written to `apps/admin-worker/wrangler.jsonc` was
# placed straight into a product — which is the leak their comment says they
# exist to prevent. An `ignore` list that silently does nothing is worse than
# no list, because the comment above it reads as a defence.
for entry in bp.get("ignore") or []:
    if "/" in entry and not any(c in entry for c in "*?["):
        bad(f'ignore entry "{entry}" names a path and has no glob character, so orun '
            f'matches it against path SEGMENTS and it excludes nothing. Write it as '
            f'"**/{entry}".')

# A workflow that runs the FACTORY must not ship to the factory's products.
# `github-workflows` copies the whole `.github` directory, so a lane added for
# this repository travels to every product built from it — and one that reads a
# path under `testing/` cannot work there, because `testing/` is not placed.
# A nightly lane did exactly this once: shipped, on a cron, reading an intent
# file no product has.
ignored = set(bp.get("ignore") or [])
workflows = sorted((root / ".github" / "workflows").glob("*.y*ml"))
for wf in workflows:
    text = wf.read_text(encoding="utf-8")
    if "testing/" not in text:
        continue
    rel = f".github/workflows/{wf.name}"
    if f"**/{rel}" not in ignored and rel not in ignored:
        bad(f"{rel} reads a path under testing/, which no product is placed with, "
            f"and is not in the blueprint's ignore list — so it ships into every "
            f'product and fails there. Add "**/{rel}" to ignore.')

# ONE WORKFLOW ON A PUSH TO MAIN, in what a product carries. The bootstrap
# watches each phase's convergence with `orun.run/watch@v1` and `sha:`, which
# takes the newest workflow run for the merge commit — from any workflow. A
# second one on push (checks.yml did this) can be the run it finds: the first
# live bootstrap watched Checks go green while ci.yml's deploy lanes had
# failed. So every shipped workflow but ci.yml stays off pushes to main.
import yaml as _yaml
on_push = []
for wf in workflows:
    rel = f".github/workflows/{wf.name}"
    if f"**/{rel}" in ignored or rel in ignored:
        continue  # the factory's own; never in a product
    doc = _yaml.safe_load(wf.read_text(encoding="utf-8")) or {}
    on = doc.get("on", doc.get(True))  # PyYAML reads a bare `on:` key as True
    if isinstance(on, str):
        on = {on: None}
    elif isinstance(on, list):
        on = {k: None for k in on}
    push = (on or {}).get("push", "absent")
    if push == "absent":
        continue
    branches = (push or {}).get("branches") if isinstance(push, dict) else None
    if branches is None or "main" in branches:
        on_push.append(wf.name)
if on_push != ["ci.yml"]:
    bad(f"the workflows a product runs on a push to main are {on_push or 'none'}; "
        f"it must be exactly ci.yml — orun.run/watch@v1 watches the newest run "
        f"for a commit from ANY workflow, so a second one hides the convergence")

# A MANUAL RUN (the deploys contract, packages/contracts DEPLOY_WORKFLOW in
# orun-cloud). Orunbase's Run and Deploy buttons dispatch ci.yml on main with
# inputs component, environment and deploy_id, then find the run by the deploy
# id in its name; GitHub refuses a dispatch whose inputs the workflow does not
# declare (422), so a product without them has dead buttons. The plan step
# must plan a dispatch under the push-to-main binding (what a merge deploys),
# on main only, and read the inputs from env, never interpolate them.
import yaml as _ydisp
_ci_path = root / ".github" / "workflows" / "ci.yml"
_ci = _ydisp.safe_load(_ci_path.read_text(encoding="utf-8")) or {}
_on = _ci.get("on", _ci.get(True)) or {}
_wd = _on.get("workflow_dispatch") if isinstance(_on, dict) else None
_inputs = (_wd or {}).get("inputs") or {}
if set(_inputs) != {"component", "environment", "deploy_id"}:
    bad(f"ci.yml's workflow_dispatch declares inputs {sorted(_inputs) or 'none'}; Orunbase "
        f"dispatches component, environment and deploy_id, and GitHub refuses unknown inputs")
else:
    _intent = _ydisp.safe_load((root / "intent.yaml").read_text(encoding="utf-8")) or {}
    _envs = set((_intent.get("environments") or {}).keys())
    _opts = set(_inputs["environment"].get("options") or [])
    if _inputs["environment"].get("type") != "choice" or _opts != _envs:
        bad(f"ci.yml's environment input offers {sorted(_opts)}; intent.yaml declares {sorted(_envs)}")
    if "github-push-main" not in ((_intent.get("automation") or {}).get("triggerBindings") or {}):
        bad("a manual run plans under intent.yaml's github-push-main binding, which is missing")
if "inputs.deploy_id" not in str(_ci.get("run-name", "")):
    bad("ci.yml's run-name must carry inputs.deploy_id: Orunbase finds a deploy's run by that id")
_steps = (_ci.get("jobs") or {}).get("plan", {}).get("steps") or []
_plan_step = next((s for s in _steps if "plan_args" in str(s.get("run", ""))), None)
if _plan_step is None:
    bad("ci.yml's plan job has no step that builds plan_args")
else:
    _run = _plan_step["run"]
    for _needle, _why in (
        ('"$GITHUB_EVENT_NAME" = "workflow_dispatch"', "plans a dispatch on its own branch"),
        ("--trigger github-push-main", "plans a dispatch as a merge to main"),
        ('"$GITHUB_REF" != "refs/heads/main"', "refuses a dispatch started off main"),
        ('--env "$DISPATCH_ENVIRONMENT"', "filters a dispatch to its environment"),
    ):
        if _needle not in _run:
            bad(f"ci.yml's plan step no longer {_why} ({_needle!r} is gone)")
    if "${{" in _run and "inputs." in _run:
        bad("ci.yml's plan step interpolates inputs.* into its script; read them from env")
    _env = _plan_step.get("env") or {}
    if "inputs.component" not in str(_env.get("DISPATCH_COMPONENT", "")) \
            or "inputs.environment" not in str(_env.get("DISPATCH_ENVIRONMENT", "")):
        bad("ci.yml's plan step must take DISPATCH_COMPONENT / DISPATCH_ENVIRONMENT from inputs in env")

if problems:
    print("FAIL: the blueprint and this repository disagree about what a product is:",
          file=sys.stderr)
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    sys.exit(1)

shipped = len(components) - len(BASELINE_ONLY)
print(f"   {shipped} of {len(components)} components placed, "
      f"{len(BASELINE_ONLY)} baseline-only by declaration")
PY

echo "coverage.test.sh: ok"
