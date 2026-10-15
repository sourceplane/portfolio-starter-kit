#!/usr/bin/env bash
# TIER 2 — the site a bootstrap produces builds, deploys (dry) and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the 01-scaffold landing (the commit its first PR merges), run what
#      `checks.yml` runs on that PR — install with the lockfile the phase
#      pruned, render fixtures, typecheck, lint, test, build. That landing
#      WAITS on its checks, so a scaffold they refuse is a bootstrap that never
#      gets past phase one;
#   2. at the finished site, the same Checks sequence;
#   3. the stage lane's own steps, rendered by `orun plan` in the site: on a
#      pull request (the verify profile) `build-app` — the component's
#      buildCommand, origin and all, the same step the deploy profile runs —
#      `verify-build-output` and `deploy-dry-run` (`wrangler deploy --dry-run
#      --name <reponame>-web-stage`);
#   4. serve the built Worker with `wrangler dev` and run the component's OWN
#      `smokeCommand` against it, verbatim — the check the real deploy ends
#      with — and then read every route the site promises: the heading and
#      title carry the site's name, the nav links the site's repository, the
#      feed and the sitemap are absolute on the stage origin, the Open Graph
#      route renders a PNG, an unknown post is a 404.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare token, deploy for real and probe workers.dev. That is a
# bootstrap against a workspace (BOOTSTRAP.md); everything short of it is here.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` (or a warm store). A few minutes: two installs and builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
cleanup() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
sub="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['subdomain'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NEXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1

# What checks.yml runs, step for step, read out of the workflow the site
# carries so the two cannot drift: every `run:` of its one job, in order.
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  while IFS= read -r cmd; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done < <(python3 - "$dir/.github/workflows/checks.yml" <<'PY'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
for job in wf["jobs"].values():
    for step in job["steps"]:
        if "run" in step:
            print(step["run"].strip())
PY
)
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   3 phases placed and landed"

# ── 1. the scaffold's own pull request ─────────────────────────────────────
echo "── 01-scaffold's landing, under the checks its PR waits on"
git -C "$tree" worktree add -q "$scratch/at-01" "$(git -C "$tree" rev-parse HEAD~2)"
checks "$scratch/at-01" "$scratch/checks-01.log"

# ── 2. the finished site ───────────────────────────────────────────────────
echo "── the finished site, under the same checks"
checks "$tree" "$scratch/checks-site.log"

# ── 3. the deploy lane's steps, for stage ──────────────────────────────────
echo "── the stage lane: build-app, verify-build-output, deploy-dry-run"
s01="$(git -C "$tree" rev-parse HEAD~2)"; s02="$(git -C "$tree" rev-parse HEAD~1)"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base "$s01" --head "$s02" --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }
python3 - "$scratch/plan.json" "$scratch/steps" <<'PY'
import json, pathlib, sys
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
for s in job["steps"]:
    if s["id"] in ("build-app", "verify-build-output", "deploy-dry-run"):
        (out / f"{s['id']}.sh").write_text(s.get("run") or "")
(out / "path").write_text(job.get("path") or "apps/web")
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
PY
for step in build-app verify-build-output deploy-dry-run; do
  [ -f "$scratch/steps/$step.sh" ] || { echo "FAIL: the stage verify lane has no $step step" >&2; exit 1; }
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`) and ORUN_ENVIRONMENT; the step runs in the component's directory.
  if ! (cd "$tree/$(cat "$scratch/steps/path")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the deploy lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done

# ── 4. serve it, and smoke it as the deploy does ───────────────────────────
echo "── wrangler dev over the built Worker"
port=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
(cd "$tree/apps/web" && exec setsid pnpm exec wrangler dev --config wrangler.jsonc --ip 127.0.0.1 --port "$port" \
   --name "$repo-web-stage" --show-interactive-dev-session=false) > "$scratch/dev.log" 2>&1 < /dev/null &
dev_pid=$!
url="http://127.0.0.1:$port"
for _ in $(seq 1 90); do
  curl -s -o /dev/null "$url/" && break
  kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
  sleep 1
done
curl -s -o /dev/null "$url/" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }

echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the site" >&2; exit 1; }

echo "   ▸ every route the site promises"
python3 - "$url" "$values" "https://$repo-web-stage.$sub.workers.dev" <<'PY'
import html, json, re, sys, urllib.error, urllib.request
import xml.etree.ElementTree as ET
base, values, origin = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
name, repo, org = values["productname"], values["reponame"], values["githuborg"]
problems = []
def bad(m): problems.append(m)
def get(path):
    try:
        with urllib.request.urlopen(base + path, timeout=30) as r:
            return r.status, r.headers.get("content-type", ""), r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("content-type", ""), e.read()

status, _, body = get("/")
page = body.decode()
if status != 200:
    bad(f"/ answered {status}")
h1 = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
if not h1 or html.unescape(re.sub(r"<[^>]+>", "", h1.group(1))).strip() != name:
    bad(f"the home page's heading is {h1 and h1.group(1)!r}, not {name!r}")
title = re.search(r"<title>(.*?)</title>", page, re.S)
if not title or html.unescape(title.group(1)) != name:
    bad(f"the home page's <title> is {title and title.group(1)!r}, not {name!r}")
if f'href="https://github.com/{org}/{repo}"' not in page:
    bad(f"the nav does not link the site's repository github.com/{org}/{repo}")
if "My Portfolio" in page or "portfolio-starter-kit" in page:
    bad("the home page still carries the baseline's name")

for path, want in (("/blog", 200), ("/blog/vim", 200), ("/blog/no-such-post", 404), ("/robots.txt", 200)):
    s, _, _ = get(path)
    if s != want:
        bad(f"{path} answered {s}, want {want}")

s, ctype, body = get("/rss")
try:
    channel = ET.fromstring(body).find("channel")
    if channel.findtext("title") != name:
        bad(f"the feed's channel title is {channel.findtext('title')!r}, not {name!r}")
    links = [i.findtext("link") for i in channel.findall("item")]
    if len(links) != 3 or not all(l.startswith(origin + "/blog/") for l in links):
        bad(f"the feed's item links are not absolute on {origin}: {links}")
except ET.ParseError as e:
    bad(f"/rss is not well-formed XML ({e}) — a site name with an & must be escaped")

s, _, body = get("/sitemap.xml")
locs = re.findall(r"<loc>(.*?)</loc>", body.decode())
if not locs or not all(l.startswith(origin) for l in locs):
    bad(f"the sitemap is not absolute on {origin}: {locs[:3]}")

s, ctype, body = get("/og?title=Hello")
if s != 200 or not ctype.startswith("image/png") or body[:8] != b"\x89PNG\r\n\x1a\n":
    bad(f"/og answered {s} {ctype} — not a PNG")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   /, /blog, a post, a 404, /rss, /sitemap.xml, /robots.txt and /og — the site's own, on {origin}")
PY

echo "e2e.test.sh: ok"
