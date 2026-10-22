#!/usr/bin/env bash
# THE REBRAND WRITES EACH VALUE ONCE, AND WHAT IT WROTE STAYS WRITTEN.
#
# Drives the real tooling/rebrand/rebrand.mjs over one-file trees and compares
# the file. Each case is a shape this baseline's identity actually takes in the
# tree — the source link, the site-name seam, the worker name, the placeholder
# domain, a secret ref — and each runs through as many passes as a bootstrap
# makes (every phase re-runs the rebrand over everything already placed), so a
# value written by an early phase must survive every later one unchanged.
#
# The identity is PINNED (fixtures/baseline-identity.portfolio-starter-kit.json)
# rather than read from .baseline/identity.json: what this tests is the engine,
# and its fixtures spell the identity out literally.
#
# Needs: node, git. No network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
rebrand="$here/../tooling/rebrand/rebrand.mjs"
identity="$here/fixtures/baseline-identity.portfolio-starter-kit.json"

fail=0
# check NAME VALUES-JSON FILE CONTENT WANT [PASSES]
check() {
  local name="$1" values="$2" file="$3" content="$4" want="$5" passes="${6:-1}"
  local tmp got out i
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  for ((i = 1; i <= passes; i++)); do
    git -C "$tmp" add -A
    if ! out="$(cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty 2>&1)"; then
      echo "   ✕  $name: rebrand pass $i failed:" >&2
      printf '%s\n' "$out" | sed 's/^/        /' >&2
      fail=1
      rm -rf "$tmp"
      return
    fi
  done
  got="$(cat "$tmp/$file")"
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then
    echo "   ok  $name"
  else
    echo "   ✕  $name:" >&2
    echo "        got:  $got" >&2
    echo "        want: $want" >&2
    fail=1
  fi
}

acme='{"reponame":"acme-notes","productname":"Acme Notes","productdomain":"acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'

echo "── rebrand: the site's own identity"
check "the source link names the product's owner and repository" \
  "$acme" apps/web/app/site.ts \
  'export const SOURCE_URL = "https://github.com/sourceplane/portfolio-starter-kit"' \
  'export const SOURCE_URL = "https://github.com/acme-inc/acme-notes"'
check "the site-name seam takes the product's name" \
  "$acme" apps/web/app/site.ts 'export const SITE_NAME = "My Portfolio"' \
  'export const SITE_NAME = "Acme Notes"'
check "…and stays a valid string for a name with an apostrophe and an ampersand" \
  '{"reponame":"sams-notes","productname":"Sam'"'"'s Notes & Links","productdomain":"sam.dev"}' \
  apps/web/app/site.ts 'export const SITE_NAME = "My Portfolio"' \
  'export const SITE_NAME = "Sam'"'"'s Notes & Links"'
check "the display name elsewhere is content, and is left alone" \
  "$acme" apps/web/app/blog/posts/hello.mdx 'Welcome to My Portfolio.' \
  'Welcome to My Portfolio.'
check "the worker name is re-prefixed, the environment suffix kept" \
  "$acme" apps/web/component.yaml 'workerName: portfolio-starter-kit-web' \
  'workerName: acme-notes-web'
check "the build origin: worker name and subdomain" \
  "$acme" apps/web/component.yaml \
  'buildCommand: NEXT_PUBLIC_SITE_URL="${SITE_URL:-https://portfolio-starter-kit-web-${ORUN_ENVIRONMENT}.your-workers-subdomain.workers.dev}" pnpm build' \
  'buildCommand: NEXT_PUBLIC_SITE_URL="${SITE_URL:-https://acme-notes-web-${ORUN_ENVIRONMENT}.acme.workers.dev}" pnpm build'
check "the placeholder domain is the product's domain, not a renamed slug" \
  "$acme" intent.yaml '      BASE_DOMAIN: portfolio-starter-kit.example.com' \
  '      BASE_DOMAIN: acme.dev'
check "no domain given: the reserved placeholder, for an owner to replace later" \
  '{"reponame":"acme-notes","productname":"Acme Notes","githuborg":"acme-inc","subdomain":"acme"}' \
  intent.yaml '      BASE_DOMAIN: portfolio-starter-kit.example.com' \
  '      BASE_DOMAIN: acme-notes.example.com'
check "an empty domain is no domain" \
  '{"reponame":"acme-notes","productname":"Acme Notes","productdomain":""}' \
  intent.yaml '      BASE_DOMAIN: portfolio-starter-kit.example.com' \
  '      BASE_DOMAIN: acme-notes.example.com'
check "the repo slug" \
  "$acme" package.json '  "name": "portfolio-starter-kit",' \
  '  "name": "acme-notes",'
check "a secret ref names the product's workspace and project" \
  "$acme" apps/web/component.yaml 'T: secret://ws_KWQ45Z6M/portfolio-starter-kit/stage/CLOUDFLARE_API_TOKEN' \
  'T: secret://ws_79BDXAZQ/acme-notes/stage/CLOUDFLARE_API_TOKEN'
check "org-owned identity is not renamed" \
  "$acme" intent.yaml 'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai' \
  'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai'
check "without githuborg the source link keeps the baseline's owner" \
  '{"reponame":"acme-notes","productname":"Acme Notes","productdomain":"acme.dev"}' \
  apps/web/app/site.ts 'const SOURCE_URL = "https://github.com/sourceplane/portfolio-starter-kit"' \
  'const SOURCE_URL = "https://github.com/sourceplane/acme-notes"'

echo "── rebrand: a written value is not rewritten, in any later pass"
contains='{"reponame":"portfolio-starter-kit-2","productname":"My Portfolio 2","productdomain":"portfolio-starter-kit.example.com.au","githuborg":"sourceplane","subdomain":"your-workers-subdomain-2"}'
check "a repo slug containing the baseline's slug survives three passes" \
  "$contains" package.json '  "name": "portfolio-starter-kit",' \
  '  "name": "portfolio-starter-kit-2",' 3
check "a worker name built on it survives three passes" \
  "$contains" apps/web/component.yaml 'workerName: portfolio-starter-kit-web' \
  'workerName: portfolio-starter-kit-2-web' 3
check "a domain containing the baseline's domain survives three passes" \
  "$contains" intent.yaml 'BASE_DOMAIN: portfolio-starter-kit.example.com' \
  'BASE_DOMAIN: portfolio-starter-kit.example.com.au' 3
check "a subdomain containing the placeholder survives three passes" \
  "$contains" apps/web/component.yaml 'workersDevSubdomain: your-workers-subdomain' \
  'workersDevSubdomain: your-workers-subdomain-2' 3
check "a site name containing the baseline's name survives three passes" \
  "$contains" apps/web/app/site.ts 'export const SITE_NAME = "My Portfolio"' \
  'export const SITE_NAME = "My Portfolio 2"' 3

# --verify runs in every phase. Without the product's values it cannot tell
# the product's own identity from a leftover; with them it can. A real
# leftover must fail it either way.
verify() { # NAME VALUES FILE CONTENT WANT(pass|fail) [--values]
  local name="$1" values="$2" file="$3" content="$4" want="$5" withvalues="${6:-}" tmp got
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  git -C "$tmp" add -A
  if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --verify ${withvalues:+--values .rebrand/values.json} >/dev/null 2>&1); then got=pass; else got=fail; fi
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then echo "   ok  $name"; else echo "   ✕  $name: --verify ${got}ed, want $want" >&2; fail=1; fi
}
echo "── rebrand --verify: the product's own identity is not residue"
verify "given the values, a slug containing the baseline's passes" \
  "$contains" package.json '"name": "portfolio-starter-kit-2"' pass --values
verify "without them it cannot know, and fails" \
  "$contains" package.json '"name": "portfolio-starter-kit-2"' fail
verify "given the values, a real leftover still fails" \
  "$acme" package.json '"name": "portfolio-starter-kit"' fail --values
verify "a leftover worker name fails" \
  "$acme" apps/web/component.yaml 'workerName: portfolio-starter-kit-web' fail --values
verify "a leftover code identifier fails (no rule renames it — so nothing may spell it)" \
  "$acme" apps/web/app/x.ts 'export class PortfolioStarterKit {}' fail --values
verify "a clean product passes" \
  "$acme" package.json '"name": "acme-notes"' pass --values

echo "── rebrand: a residue it cannot rename fails the rebrand itself"
tmp="$(mktemp -d)"; git -C "$tmp" init -q; mkdir -p "$tmp/.rebrand" "$tmp/apps/web"
printf '%s\n' "$acme" > "$tmp/.rebrand/values.json"
printf 'const x = "PORTFOLIO_STARTER_KIT_TOKEN"\n' > "$tmp/apps/web/x.ts"
git -C "$tmp" add -A
if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty >/dev/null 2>&1); then
  echo "   ✕  an unrenamable env-var prefix passed the rebrand" >&2; fail=1
else
  echo "   ok  an unrenamable env-var prefix fails the rebrand, naming the file"
fi
rm -rf "$tmp"

[ "$fail" -eq 0 ] || exit 1
echo "rebrand.test.sh: ok"
