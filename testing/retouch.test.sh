#!/usr/bin/env bash
# A RE-RUN PHASE HAS SOMETHING TO LAND.
#
# A phase's convergence can fail AFTER its PR merged, and the merge has already
# put every file the phase places on main. orun derives phase state from the
# files, so a retried build sees the phase placed and a forced re-run of it
# lands an EMPTY diff — and the product's CI plans `--changed`, so a component
# whose files did not change in the push does not deploy. The phase's `retouch`
# hook (tooling/bootstrap/retouch.mjs) is what breaks that: one marker line at
# the end of each affected component.yaml,
#
#     # orun: redeploy <phase> <stamp>
#
# replaced rather than accumulated, so the landing has a diff and exactly the
# phase's components are in the changed set. The marker is a deploy trigger and
# nothing reads it back; phase state stays derived, never stored.
#
# This drives the real retouch.mjs over a two-component tree, then checks that
# every component the blueprint's retouch hooks name resolves in THIS tree —
# the layout a product is placed with.
# Needs: node. No network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
retouch="$root/tooling/bootstrap/retouch.mjs"

command -v node >/dev/null || { echo "retouch.test.sh needs node" >&2; exit 1; }

fail=0
ok()  { echo "   ok  $*"; }
bad() { echo "   ✕  $*" >&2; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A product tree with two components in two of the lanes the blueprint places
# into, a test package that shares a directory name with the first (as
# tests/<worker> does with apps/<worker>) and must NOT be touched, and the
# hand-written re-trigger line the fleet carried before this tool existed.
mkdir -p "$tmp/apps/alpha" "$tmp/infra/beta" "$tmp/tests/alpha" "$tmp/node_modules/x"
cat > "$tmp/apps/alpha/component.yaml" <<'Y'
apiVersion: sourceplane.io/v1
kind: Component
metadata:
  name: alpha
spec:
  type: cloudflare-worker-turbo
  labels:
    team: platform
# ci: re-trigger deploy (batch A — runner-starvation recovery 20260622T115650Z)
Y
# No trailing newline on purpose: the tool must add one, and only one.
printf 'apiVersion: sourceplane.io/v1\nkind: Component\nmetadata:\n  name: beta\nspec:\n  type: terraform' > "$tmp/infra/beta/component.yaml"
printf 'kind: Component\nmetadata:\n  name: alpha-tests\n' > "$tmp/tests/alpha/component.yaml"
printf 'kind: Component\nmetadata:\n  name: alpha\n' > "$tmp/node_modules/x/component.yaml"
cp "$tmp/apps/alpha/component.yaml" "$tmp/alpha.orig"
cp "$tmp/infra/beta/component.yaml" "$tmp/beta.orig"

markers() { grep -c '^# orun: redeploy ' "$1" || true; }

echo "── retouch: one marker, last, replaced not appended"
(cd "$tmp" && ORUN_RUN_ID=run-one node "$retouch" --phase 04-workers --components alpha,beta) > "$tmp/one.log" 2>&1 \
  || { bad "first run failed:"; sed 's/^/        /' "$tmp/one.log" >&2; }
for f in apps/alpha infra/beta; do
  [ "$(markers "$tmp/$f/component.yaml")" = 1 ] || bad "$f: $(markers "$tmp/$f/component.yaml") marker lines after one run, want 1"
  [ "$(tail -n1 "$tmp/$f/component.yaml")" = "# orun: redeploy 04-workers run-one" ] \
    || bad "$f: last line is '$(tail -n1 "$tmp/$f/component.yaml")'"
done
[ "$(tail -c1 "$tmp/infra/beta/component.yaml" | od -An -c | tr -d ' ')" = '\n' ] \
  || bad "infra/beta: no trailing newline after retouch"
ok "both components carry the marker as their last line"

(cd "$tmp" && ORUN_RUN_ID=run-two node "$retouch" --phase 04-workers-restore --components alpha,beta) > "$tmp/two.log" 2>&1 \
  || { bad "second run failed:"; sed 's/^/        /' "$tmp/two.log" >&2; }
for f in apps/alpha infra/beta; do
  [ "$(markers "$tmp/$f/component.yaml")" = 1 ] || bad "$f: $(markers "$tmp/$f/component.yaml") marker lines after two runs — the marker accumulated"
  [ "$(tail -n1 "$tmp/$f/component.yaml")" = "# orun: redeploy 04-workers-restore run-two" ] \
    || bad "$f: second run did not replace the marker: '$(tail -n1 "$tmp/$f/component.yaml")'"
done
grep -q 'replace marker' "$tmp/two.log" || bad "second run did not report a replacement"
ok "a second run replaces the marker (a different phase's too) rather than appending"

echo "── retouch: every other byte is as it was"
if [ "$(head -n -1 "$tmp/apps/alpha/component.yaml" | cksum)" = "$(cksum < "$tmp/alpha.orig")" ]; then
  ok "apps/alpha: the file above the marker is byte-for-byte the original"
else
  bad "apps/alpha: bytes above the marker changed"
  diff <(head -n -1 "$tmp/apps/alpha/component.yaml") "$tmp/alpha.orig" >&2 || true
fi
if [ "$(head -n -1 "$tmp/infra/beta/component.yaml" | cksum)" = "$(printf '%s\n' "$(cat "$tmp/beta.orig")" | cksum)" ]; then
  ok "infra/beta: only a newline was added before the marker"
else
  bad "infra/beta: bytes above the marker changed"
fi
grep -q '^# ci: re-trigger deploy' "$tmp/apps/alpha/component.yaml" \
  && ok "the hand-written re-trigger line is left alone" \
  || bad "the hand-written re-trigger line was removed"
[ "$(cat "$tmp/tests/alpha/component.yaml")" = "$(printf 'kind: Component\nmetadata:\n  name: alpha-tests\n')" ] \
  && ok "tests/alpha (alpha-tests) was not touched — components resolve by metadata.name" \
  || bad "tests/alpha was touched: a component is its metadata.name, not its directory name"

echo "── retouch: the same stamp twice is a no-op"
(cd "$tmp" && ORUN_RUN_ID=run-two node "$retouch" --phase 04-workers-restore --components alpha,beta) > "$tmp/again.log" 2>&1 \
  || bad "idempotent re-run failed"
grep -q 'nothing to do' "$tmp/again.log" && ok "re-running with the same stamp reports nothing to do" \
  || bad "re-running with the same stamp did not report a no-op: $(tail -1 "$tmp/again.log")"

echo "── retouch: the stamp"
(cd "$tmp" && env -u ORUN_RUN_ID ORUN_SESSION_ID=sess-9 node "$retouch" --phase p --components beta) >/dev/null 2>&1
[ "$(tail -n1 "$tmp/infra/beta/component.yaml")" = "# orun: redeploy p sess-9" ] \
  && ok "ORUN_SESSION_ID stamps when ORUN_RUN_ID is unset" \
  || bad "ORUN_SESSION_ID was not used: '$(tail -n1 "$tmp/infra/beta/component.yaml")'"
(cd "$tmp" && env -u ORUN_RUN_ID -u ORUN_SESSION_ID node "$retouch" --phase p --components beta) >/dev/null 2>&1
tail -n1 "$tmp/infra/beta/component.yaml" | grep -Eq '^# orun: redeploy p [0-9]{8}T[0-9]{6}Z$' \
  && ok "with neither, a UTC timestamp" \
  || bad "no timestamp stamp: '$(tail -n1 "$tmp/infra/beta/component.yaml")'"

echo "── retouch: --dry-run writes nothing, --check names what is missing"
before="$(cksum < "$tmp/apps/alpha/component.yaml")"
(cd "$tmp" && ORUN_RUN_ID=dry node "$retouch" --phase p --components alpha --dry-run) > "$tmp/dry.log" 2>&1 \
  || bad "--dry-run failed"
[ "$before" = "$(cksum < "$tmp/apps/alpha/component.yaml")" ] && grep -q 'would replace marker' "$tmp/dry.log" \
  && ok "--dry-run reports the change and leaves the file alone" \
  || bad "--dry-run wrote, or did not say what it would do"

if (cd "$tmp" && node "$retouch" --phase p --components alpha,gamma --check) > "$tmp/check.log" 2>&1; then
  bad "--check passed with gamma absent"
else
  grep -q 'gamma' "$tmp/check.log" && ok "--check fails and names gamma" \
    || bad "--check failed without naming the missing component: $(cat "$tmp/check.log")"
fi
if (cd "$tmp" && ORUN_RUN_ID=x node "$retouch" --phase p --components alpha,gamma) > "$tmp/miss.log" 2>&1; then
  bad "a run with a missing component succeeded"
else
  [ "$(tail -n1 "$tmp/apps/alpha/component.yaml")" != "# orun: redeploy p x" ] \
    && ok "a missing component refuses the whole run before any file is written" \
    || bad "a missing component still wrote the components that exist"
fi
(cd "$tmp" && node "$retouch" --phase p --components alpha,beta --check) >/dev/null 2>&1 \
  && ok "--check passes when every component resolves" || bad "--check failed on a complete set"

echo "── retouch: --affects reads a task contract"
cat > "$tmp/contract.yaml" <<'Y'
# A contract, as .baseline/tasks/*.TaskContract.yaml are written.
apiVersion: orun.io/v1
kind: TaskContract
spec:
  goal: Two components converge
  affects:
    - alpha
    # a comment between items
    - beta
  doneWhen:
    - convergence green
  gates: []
Y
(cd "$tmp" && ORUN_RUN_ID=via-contract node "$retouch" --phase 05-edge --affects contract.yaml) > "$tmp/aff.log" 2>&1 \
  || { bad "--affects run failed:"; sed 's/^/        /' "$tmp/aff.log" >&2; }
for f in apps/alpha infra/beta; do
  [ "$(tail -n1 "$tmp/$f/component.yaml")" = "# orun: redeploy 05-edge via-contract" ] \
    || bad "$f: --affects did not touch it"
done
grep -q '2 of 2' "$tmp/aff.log" && ok "spec.affects named both, and both were touched" \
  || bad "--affects touched the wrong number: $(tail -1 "$tmp/aff.log")"
printf 'spec:\n  affects: [alpha, beta]\n' > "$tmp/flow.yaml"
(cd "$tmp" && ORUN_RUN_ID=flow node "$retouch" --phase p --affects flow.yaml --check) >/dev/null 2>&1 \
  && ok 'the flow form `affects: [a, b]` reads too' || bad "the flow form of affects did not read"
printf 'spec:\n  goal: nothing\n' > "$tmp/none.yaml"
(cd "$tmp" && node "$retouch" --phase p --affects none.yaml --check) >/dev/null 2>&1 \
  && bad "a contract with no affects passed --check" || ok "a contract with no affects refuses"

# ── THE BLUEPRINT'S OWN HOOKS RESOLVE IN THIS TREE ─────────────────────────
# Every `retouch` hook in repo-blueprint.yaml names the components a phase
# redeploys, through a contract (.baseline/tasks/) or a list. A product is placed with this
# repository's layout, so each must resolve here — a contract that names a
# component nobody ships, or a component that moved, fails a real bootstrap at
# the landing, an hour in. `{{ .baseline.dir }}` is this checkout.
echo "── the blueprint's retouch hooks, against this tree"
hooks=0
while IFS= read -r line; do
  hooks=$((hooks + 1))
  argv="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*run:[[:space:]]*//' \
          -e "s#{{ \.baseline\.dir }}#$root#g" -e 's#{{ \.phase\.name }}#probe#g')"
  if (cd "$root" && node -e '
      const argv = JSON.parse(process.argv[1]);
      const { spawnSync } = require("node:child_process");
      const r = spawnSync(argv[0], [...argv.slice(1), "--check"], { stdio: ["ignore", "pipe", "pipe"] });
      process.stdout.write(r.stdout); process.stderr.write(r.stderr);
      process.exit(r.status ?? 1);
    ' "$argv") > "$tmp/hook.log" 2>&1; then
    ok "$(grep -c -- '->' "$tmp/hook.log") component(s): ${argv#*retouch.mjs\", }"
  else
    bad "a retouch hook does not resolve: $argv"; sed 's/^/        /' "$tmp/hook.log" >&2
  fi
done < <(grep -E '^\s*run: \[.*retouch\.mjs' "$root/repo-blueprint.yaml")
[ "$hooks" -ge 1 ] || bad "only $hooks retouch hook(s) in repo-blueprint.yaml — 01-product lands the deployable site and needs one"

[ "$fail" -eq 0 ] || exit 1
echo "retouch.test.sh: ok"
