#!/usr/bin/env bash
# hooks/render-deployment-docs.sh runs in the build box, which has python3 but
# not PyYAML. The first console build to reach 03-docs stopped there on
# `import yaml`, with exit 1 and its site live. This runs the hook on a
# scaffolded tree under a python3 with no third-party packages, and checks it
# reads SITE_URL from intent.yaml the same way with and without PyYAML.
# Offline: the probes find nothing, which the record says as "unreachable".
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

python3 -m venv --without-pip "$work/bare"
if "$work/bare/bin/python3" -c 'import yaml' 2>/dev/null; then
  echo "render.test.sh: the bare python3 still imports yaml — cannot test" >&2; exit 1
fi

site="$work/site"; mkdir -p "$site/.github/workflows"
mkdir -p "$site/.rebrand"
printf '{"reponame":"acme-notes","subdomain":"acme"}\n' > "$site/.rebrand/values.json"
printf '# Acme Notes\n\nA portfolio.\n' > "$site/README.md"
printf 'jobs:\n  lane:\n    steps:\n      - with:\n          version: v2.78.4\n' > "$site/.github/workflows/ci.yml"
cat > "$site/intent.yaml" <<'YAML'
execution:
  state:
    workspace: ws_TEST0000
environments:
  stage:
    env:
      BASE_DOMAIN: acme.dev
  prod:
    # a custom domain
    env:
      SITE_URL: "https://acme.dev/"  # trailing slash dropped
YAML

fail=0
for py in "$work/bare/bin" ""; do
  label="${py:+without PyYAML}"; label="${label:-with the system python3}"
  [ -n "$py" ] || python3 -c 'import yaml' 2>/dev/null || { echo "   (skipped: system python3 has no PyYAML)"; continue; }
  rm -f "$site/ai/context/deployment.md"
  if ! (cd "$site" && PATH="${py:+$py:}$PATH" bash "$here/hooks/render-deployment-docs.sh" . ws_TEST0000 "$here" >/dev/null 2>"$work/err"); then
    echo "  ✕ $label: the hook failed"; sed 's/^/      /' "$work/err"; fail=1; continue
  fi
  rec="$site/ai/context/deployment.md"
  grep -q 'stage `https://acme-notes-web-stage.acme.workers.dev`' "$rec" || { echo "  ✕ $label: stage origin is not the workers.dev URL"; fail=1; }
  grep -q 'prod `https://acme.dev`' "$rec" || { echo "  ✕ $label: prod origin is not SITE_URL"; fail=1; }
  grep -q '<!-- 03-docs:begin -->' "$site/README.md" || { echo "  ✕ $label: README section missing"; fail=1; }
  [ "$fail" = 0 ] && echo "   $label: record rendered, SITE_URL read"
done
[ "$fail" = 0 ] || exit 1
echo "render.test.sh: ok"
