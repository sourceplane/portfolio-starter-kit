#!/usr/bin/env bash
# The two things a bootstrap turns off in intent.yaml and puts back —
# `prod.promotion` (tooling/bootstrap/promotion.mjs) and dev's push-to-main
# activation (tooling/bootstrap/dev-lanes.mjs) — must each defer, be
# idempotent both ways, leave a parseable intent while deferred, and restore
# the file BYTE-FOR-BYTE: a restore that reproduced the block by hand would
# be a second place the intent is authored.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
fail=0
ok() { echo "   ok  $1"; }
bad() { echo "   ✕  $1" >&2; fail=1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp "$root/intent.yaml" "$tmp/intent.yaml"

for tool in promotion dev-lanes; do
  f="$tmp/intent.yaml"; cp "$root/intent.yaml" "$f"
  echo "── $tool.mjs"
  node "$root/tooling/bootstrap/$tool.mjs" --check --file "$f" | grep -q -E 'enforced|active' && ok "starts enforced/active" || bad "starts enforced/active"
  node "$root/tooling/bootstrap/$tool.mjs" --defer --file "$f" >/dev/null
  node "$root/tooling/bootstrap/$tool.mjs" --check --file "$f" | grep -q deferred && ok "--defer defers" || bad "--defer defers"
  python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$f" && ok "deferred intent still parses" || bad "deferred intent still parses"
  cp "$f" "$tmp/once.yaml"; node "$root/tooling/bootstrap/$tool.mjs" --defer --file "$f" >/dev/null
  cmp -s "$f" "$tmp/once.yaml" && ok "a second --defer changes nothing" || bad "a second --defer changes nothing"
  node "$root/tooling/bootstrap/$tool.mjs" --restore --file "$f" >/dev/null
  cmp -s "$f" "$root/intent.yaml" && ok "--restore is byte-exact" || bad "--restore is byte-exact"
  node "$root/tooling/bootstrap/$tool.mjs" --restore --file "$f" >/dev/null
  cmp -s "$f" "$root/intent.yaml" && ok "a second --restore changes nothing" || bad "a second --restore changes nothing"
done

echo "── what each deferral means to a push-to-main plan"
f="$tmp/intent.yaml"; cp "$root/intent.yaml" "$f"
node "$root/tooling/bootstrap/dev-lanes.mjs" --defer --file "$f" >/dev/null
python3 - "$f" <<'PY' && ok "dev is no longer activated by github-push-main while deferred" || bad "dev is no longer activated by github-push-main while deferred"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
refs = d["environments"]["dev"]["activation"]["triggerRefs"]
assert "github-push-main" not in refs and "github-pull-request" in refs, refs
PY
f="$tmp/intent.yaml"; cp "$root/intent.yaml" "$f"
node "$root/tooling/bootstrap/promotion.mjs" --defer --file "$f" >/dev/null
python3 - "$f" <<'PY' && ok "prod has no promotion gate while deferred" || bad "prod has no promotion gate while deferred"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert "promotion" not in d["environments"]["prod"], d["environments"]["prod"].keys()
PY

echo "── work-tree.mjs — the baseline's work tree does not ship"
f="$tmp/intent.yaml"; cp "$root/intent.yaml" "$f"
node "$root/tooling/bootstrap/work-tree.mjs" --check --file "$f" | grep -q declared && ok "this repository declares a work tree" || bad "this repository declares a work tree"
node "$root/tooling/bootstrap/work-tree.mjs" --strip --file "$f" >/dev/null
node "$root/tooling/bootstrap/work-tree.mjs" --check --file "$f" | grep -q absent && ok "--strip removes it" || bad "--strip removes it"
python3 - "$f" "$root/intent.yaml" <<'PY' && ok "everything else in the intent is untouched" || bad "everything else in the intent is untouched"
import sys, yaml
after, before = (yaml.safe_load(open(p)) for p in sys.argv[1:3])
assert "work" not in after, list(after)
before.pop("work")
assert after == before, "a key other than work: changed"
PY
grep -q 'Where the work lives' "$f" && bad "the block's own comment is left behind" || ok "the block's own comment goes with it"
cp "$f" "$tmp/once.yaml"; node "$root/tooling/bootstrap/work-tree.mjs" --strip --file "$f" >/dev/null
cmp -s "$f" "$tmp/once.yaml" && ok "a second --strip changes nothing" || bad "a second --strip changes nothing"

if [ "$fail" -ne 0 ]; then echo "bootstrap-defer.test.sh: failure(s)" >&2; exit 1; fi
echo "bootstrap-defer.test.sh: ok"
