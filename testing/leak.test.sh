#!/usr/bin/env bash
# THE LEAK GATE — what a site carries, and what stays in the factory.
#
# A site built from this baseline is somebody's site, not a copy of this
# repository. It gets the product: the app, its tests, its CI, its tooling,
# its README, its AGENTS.md and its two context pages. It does NOT get the
# factory: the blueprints, the bootstrap and rebrand tooling, the test gates,
# the task contracts and identity under `.baseline/`, this repository's own
# epic and task tree, or BOOTSTRAP.md.
#
# This asks orun to DERIVE the placement — every file every phase would write
# — and gates that set. Derivation runs no hooks, contacts nothing and writes
# nothing. testing/placement.test.sh gates the same rules over a tree that is
# actually placed and branded.
#
# Needs: orun + python3. No network, no credential.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

command -v orun >/dev/null || { echo "leak.test.sh needs orun on PATH" >&2; exit 1; }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

echo "── deriving what every phase would place"
sets=()
while IFS=$'\t' read -r k v; do sets+=( --set "$k=$v" ); done < <(
  python3 - "$here/fixtures/acme.json" <<'PY'
import json, sys
for k, v in json.load(open(sys.argv[1])).items():
    if not k.startswith("_"):
        print(f"{k}\t{'true' if v is True else 'false' if v is False else v}")
PY
)
orun new --blueprint "$root/repo-blueprint.yaml" --status --json \
  --out "$scratch/empty" "${sets[@]}" > "$scratch/status.json"

python3 - "$scratch/status.json" "$root" <<'PY'
import json, pathlib, re, sys

status = json.load(open(sys.argv[1]))
root = pathlib.Path(sys.argv[2])
problems = []
def bad(m): problems.append(m)

# Against an empty output directory every file a phase places is "missing", so
# the union of those lists IS the site's file set.
placed = sorted({f for ph in status["phases"] for f in (ph.get("missing") or [])})
if len(placed) < 50:
    sys.exit(f"only {len(placed)} files derived — the tree is not a site")

# ── the context pack, exactly ─────────────────────────────────────────────
ALLOWED_AI = {"ai/context/deployment.md", "ai/context/operations.md"}
shipped_ai = {p for p in placed if p.startswith("ai/")}
for extra in sorted(shipped_ai - ALLOWED_AI):
    bad(f"{extra} ships to the site and is this repository's own state")
for missing in sorted(ALLOWED_AI - shipped_ai):
    bad(f"{missing} is declared a product file and would not ship")

# ── the factory never ships ───────────────────────────────────────────────
NEVER = (".baseline/", "specs/", "tasks/", "testing/", "hooks/", "docs/phases/",
         "tooling/rebrand/", "tooling/bootstrap/", ".github/workflows/baseline.yml",
         ".github/workflows/tag.yml", "BOOTSTRAP.md", "repo-blueprint.yaml",
         "blueprint.yaml", "flows/", "agents/")
for p in placed:
    for never in NEVER:
        if p == never or p.startswith(never):
            bad(f"{p} would ship — it is the factory, not the site")

# ── nothing local and nothing built ───────────────────────────────────────
# Every `.env.<x>` but `.env.example` (which ships), and Terraform state.
LOCAL = re.compile(r"(^|/)(\.env(\.(?!example$)[^/]+)?|\.dev\.vars(\..*)?|node_modules|\.next|"
                   r"\.open-next|\.wrangler|\.turbo|\.orun|next-env\.d\.ts|[^/]*\.tsbuildinfo|"
                   r"\.terraform|[^/]*\.tfstate(\.[^/]*)?)(/|$)")
for p in placed:
    if LOCAL.search(p):
        bad(f"{p} would ship — a local or built file of whoever ran the bootstrap")

# ── the site's README and agent page, not this repository's ───────────────
if "README.md" not in placed:
    bad("README.md would not ship")
for must in ("AGENTS.md", ".github/workflows/ci.yml",
             "apps/web/component.yaml", "apps/web/app/site.ts", "tests/web/component.yaml",
             ".rebrand/values.json", "apps/web/.env.example"):
    if must not in placed:
        bad(f"{must} would not ship, and a site needs it")

# ── PROVENANCE, which rebrand has no rule for ─────────────────────────────
# Not a search for this baseline's name: the rebrand rewrites that, and this
# gate reads the sources before it runs. What the rebrand cannot rewrite is a
# sentence about where the site CAME FROM, or one about being a baseline.
PROVENANCE = re.compile(
    r"\bfork(ed)? (of|from)\b|\bbaseline (repo|repository|commit|tag)\b|\bthis baseline\b"
    r"|BOOTSTRAP\.md|repo-blueprint|specs/epics|\.baseline/",
    re.I,
)
SOURCES = {"README.md": ".baseline/product/README.md",
           "AGENTS.md": ".baseline/product/AGENTS.md",
           "ai/context/operations.md": "ai/context/operations.md",
           "ai/context/deployment.md": "ai/context/deployment.md"}
for shipped, src in SOURCES.items():
    for n, line in enumerate((root / src).read_text(errors="replace").splitlines(), 1):
        if PROVENANCE.search(line):
            bad(f"{shipped} (from {src}:{n}) tells the site about the factory: {line.strip()[:80]}")

if problems:
    print("FAIL: the site would carry the baseline:", file=sys.stderr)
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    sys.exit(1)

print(f"   {len(placed)} files derived across every phase")
print(f"   ai/context is exactly {len(ALLOWED_AI)} declared file(s); none of the "
      f"{len(NEVER)} factory paths; nothing local or built; no provenance prose")
PY

echo "leak.test.sh: ok"
