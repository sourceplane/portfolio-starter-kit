#!/usr/bin/env bash
# The offline bootstrap: every phase of repo-blueprint.yaml, placed by orun and
# finished by the blueprint's own `run:` hooks, in order, the way a real
# `orun new --run-hooks --resume` takes a site from nothing to its last
# landing — minus the platform. Sourced by placement.test.sh and e2e.test.sh.
#
#   bootstrap_offline <root> <tree> <values.json> <log-dir> [until-phase]
#
# What stands in for the platform:
#   - the typed actions (`uses:` — task, repo, reconcile, land, watch, probe)
#     are skipped; a landing becomes a commit on `main`, which is what the
#     next phase's placement sees on the real thing too;
#   - the repository's first commit is an empty one, as on the real thing:
#     the platform's landing opens the first pull request against an empty
#     "Initial commit" by `orun`, and that commit is the base the first
#     landing's push is planned against;
#   - `link` (a `run:` hook that calls `orun cloud`) is skipped — it needs a
#     workspace;
#   - `{{ .inputs.* }}` render from the fixture.
# Everything else — the rebrand, the re-tenant, the work-tree strip, the
# deferrals and their restore, the retouch marker, the deployment-docs
# render — runs exactly as declared.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git.

bootstrap_offline() {
  local root="$1" tree="$2" values="$3" logs="$4" until="${5:-}"
  local sets=() k v phase
  while IFS=$'\t' read -r k v; do sets+=( --set "$k=$v" ); done < <(
    python3 - "$values" <<'PY'
import json, sys
for k, v in json.load(open(sys.argv[1])).items():
    if not k.startswith("_"):
        print(f"{k}\t{'true' if v is True else 'false' if v is False else v}")
PY
  )
  mkdir -p "$tree"/{apps,infra,packages,tests} "$logs"
  for d in apps infra packages tests; do touch "$tree/$d/.gitkeep"; done
  (
    cd "$tree"
    git init -q -b main
    git config user.email bootstrap@example.invalid
    git config user.name "offline bootstrap"
    git commit -q --allow-empty -m "Initial commit"
  ) || { echo "FAIL: the repository's first commit" >&2; return 1; }

  for phase in $(python3 -c "import yaml,sys;print(' '.join(p['name'] for p in yaml.safe_load(open(sys.argv[1]))['phases']))" "$root/repo-blueprint.yaml"); do
    echo "── $phase: place"
    if ! orun new --blueprint "$root/repo-blueprint.yaml" --out "$tree" --phase "$phase" \
         "${sets[@]}" > "$logs/place-$phase.log" 2>&1; then
      echo "FAIL: $phase did not place" >&2; tail -20 "$logs/place-$phase.log" >&2; return 1
    fi
    echo "── $phase: post hooks"
    if ! python3 "$root/testing/lib/run-hooks.py" "$root/repo-blueprint.yaml" "$phase" post \
         "$tree" "$root" "$values" --skip link > "$logs/hooks-$phase.log" 2>&1; then
      echo "FAIL: $phase's post hooks" >&2; tail -30 "$logs/hooks-$phase.log" >&2; return 1
    fi
    sed 's/^/  /' "$logs/hooks-$phase.log"
    # The landing: what the PR merges is what the next phase is placed onto.
    (
      cd "$tree"
      git config user.email bootstrap@example.invalid
      git config user.name "offline bootstrap"
      git checkout -q -B main 2>/dev/null || true
      git add -A
      git commit -q -m "land $phase" --allow-empty
    ) || { echo "FAIL: $phase did not commit" >&2; return 1; }
    [ "$phase" = "$until" ] && break
  done
  return 0
}
