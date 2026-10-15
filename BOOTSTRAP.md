# BOOTSTRAP — a new site from this baseline, in phases

How to go from **nothing** to a **portfolio site live on stage and prod,
documented**, with ONE provider consent.

There is one artifact: **`repo-blueprint.yaml`**. It declares what to place,
in what order, what each phase needs first, and what to say while it runs.
`orun new` is the whole runtime — the phases below are its `--phase` names,
not separate workflows. The console card the platform renders is
**`blueprint.yaml`**; it names the build document and states the inputs, the
brokered secrets and the programme, and `testing/manifest.test.sh` holds it
to what the build document does.

Target wall-clock: **about six minutes** — an estimate summed from the
phases until a bootstrap measures it: two landings, each checked by `plan`
alone, one Next.js build per environment, stage and prod deployed side by
side until `03-docs` restores the promotion gate. baseline-v2 measured 8m43s
from the console's Build (2026-10-15) over three landings, about 1m50s of it
the build sandbox starting; `01-product` drops one landing and the Checks
waits, cirrus-baseline baseline-v22's shape.

## 0. What you need

- GitHub org access (repository creation) and a machine with `git`, `node`
  (≥ 22), `pnpm` (10.12.1), `python3` with PyYAML, `curl`, and the `orun`
  CLI **≥ v2.58.11** — the floor for RUNNING the bootstrap (the phase overlay,
  landings that commit per phase and wait on the PR's whole CI run,
  `githubOwner` on the doctor probe, `environments` on the secrets probe, a
  probe deferred for a project not yet created, and `from: workspace`). The
  site's own `ci.yml` pins its lanes separately (v2.78.4).
- A Cloudflare account (the free plan is enough for one Worker with static
  assets) and its **Account API token** with Workers Scripts Write (the
  console's Connect recipe lists the exact permission groups). It is the ONLY
  provider credential this baseline needs.
- An Orun Cloud workspace for the site — `orunWorkspace`, or the workspace
  the build runs in (ORUN_WORKSPACE) when that is unset — with an
  **admin-role API key** for headless runs (secret writes below admin are
  masked as `not_found`).
- **The repository allow-listed in the workspace** (console → Settings → Git
  repos), unless the credential can write links. `01-product`'s `link` step
  stops and names the fix if it is not.

## 1. One command: `--resume`

The whole bootstrap, unattended. `--resume` places every phase not already
derived as done, in order, honouring each phase's barrier:

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/portfolio-starter-kit
cd portfolio-starter-kit

orun new --blueprint repo-blueprint.yaml \
  --out ~/sites/acme-notes --run-hooks --resume \
  --set reponame=acme-notes --set productname="Acme Notes" \
  --set productdomain=acme.dev --set githuborg=acme-inc \
  --set orunWorkspace=ws_XXXXXXXX \
  --set subdomain=<workers-dev-subdomain>
```

**`--run-hooks` is the difference between placing files and bootstrapping a
site.** Without it `orun new` writes the tree and stops: no repository, no
landing, no convergence watch, no probe. That is deliberate — it is what
makes the offline bootstrap in `testing/` possible with no workspace and no
provider.

`--resume` is safe to re-run from anywhere, a fresh container with a fresh
`--out` included: **phase state is derived from the tree, never stored.** A
phase whose files are present but branded derives as `drifted`, and
`--resume` leaves it placed rather than reverting the site's identity.

## 1b. Or phase by phase

| phase | what it lands | verified by |
|---|---|---|
| `01-product` | the repository, created and linked; the brokered Cloudflare secrets; then the whole site in one PR — intent, CI, tooling, identity, `apps/web` + `tests/web` | its PR's `plan` green, merged; the convergence green (build, deploy, smoke) and both workers.dev URLs answering |
| `03-docs` | `ai/context/deployment.md` from probed facts; prod's promotion gate and dev's push lanes restored | the final probe |

```bash
orun new --blueprint repo-blueprint.yaml --out ~/sites/acme-notes --run-hooks \
  --phase 01-product --values ~/acme-notes.values.yaml
# … then 03-docs
```

Every later phase reads the identity back from `.rebrand/values.json` in the
placed tree, but the blueprint's **required** inputs — `reponame`,
`productname`, `productdomain`, `githuborg` — are validated before anything
runs, so pass them every time (a `--values` file is easier). The full guide,
one page per phase: [docs/phases/README.md](docs/phases/README.md).

| flag | what it does |
|---|---|
| `--status` | derives and prints every phase's state and writes nothing. It parses the document, validates each hook against the action registry and compiles every template; it needs no credential and no network |
| `--phase <name>` | places exactly that phase; its `requires.phases` still gates |
| `--until <name>` | places every phase through that one and stops |

What lands in the site is PRODUCT-ONLY: the app, its tests, its CI, its
tooling, its README and its two context pages. None of this repository's
machinery (`.baseline/`, the blueprints, `tooling/rebrand`,
`tooling/bootstrap`, `hooks/`, `testing/`, `docs/phases/`, `specs/`,
`tasks/`, this file) ships. That promise is a test: `testing/leak.test.sh`
derives what every phase would place and gates the set, and
`testing/placement.test.sh` gates the same rules over a placed, branded tree.

## 2. Headless / container mode

The blueprint's source is this repository (`sources: [{kind: dir, path: .}]`),
so the container contract is a shallow clone at a pinned tag plus two
tokens:

```bash
export ORUN_TOKEN=…          # orun auth, headless
export GITHUB_TOKEN=…        # fine-grained PAT (below)

git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/portfolio-starter-kit
cd portfolio-starter-kit
orun new --blueprint repo-blueprint.yaml \
  --out /work/acme-notes --run-hooks --resume --progress json \
  --values /work/acme-notes.values.yaml
```

| requirement | detail |
|---|---|
| `GITHUB_TOKEN` | fine-grained PAT: **read** on this repository; on the SITE's repository **contents write**, **pull-requests write**, **actions read+write** (`orun.run/watch@v1` resumes runs with `gh run rerun`), **checks read**; **repository create** on the owner if `01-product` creates it (or pre-create it — supported) |
| classic token caveat | a classic PAT or gh OAuth token also needs the `workflow` scope to push `.github/workflows/` |
| pinning | the clone's `--branch <tag>` pins everything: the blueprint, its modules and its hooks' scripts all come from that one commit |

## 3. After the site is live

- **Write**: posts are `.mdx` files in `apps/web/app/blog/posts/`; the home
  page is `apps/web/app/page.tsx`; the name and source link are
  `apps/web/app/site.ts`. Every merge to `main` redeploys.
- **Custom domain**: attach it to the Worker in Cloudflare, then set
  `SITE_URL` for the environment in the site's `intent.yaml` (its README,
  "Custom domain"). There is no domain phase: attaching a domain needs zone
  permissions the brokered `workers-deploy` token does not carry.
- **Refresh the record**: re-run `--phase 03-docs`; it is idempotent.

## 4. Testing this baseline

`.github/workflows/baseline.yml` runs three tiers on every pull request, and
each runs locally the same way:

```bash
for t in manifest phases coverage rebrand retouch bootstrap-defer; do bash testing/$t.test.sh; done
bash testing/leak.test.sh        # needs orun
bash testing/placement.test.sh   # needs orun, node, pnpm: the offline bootstrap
bash testing/e2e.test.sh         # + network for pnpm: the site built, dry-deployed and served
```

The offline bootstrap (`testing/lib/bootstrap.sh`) places every phase in
order and finishes each with the blueprint's OWN `run:` hooks — read out of
`repo-blueprint.yaml`, not transcribed — so the rebrand, the re-tenant, the
deferrals and their restore, the retouch marker, the lockfile and the
deployment record all run exactly as a real bootstrap runs them. Only the
platform's typed actions (task, repo, link, land, watch, probe, reconcile)
are stood in for, a landing becoming a commit.

## 5. Cutting a baseline tag (maintainers)

Every site built from this repository resolves a `baseline-vN` tag, so the
tag is cut by a workflow rather than by hand:

```bash
gh workflow run tag.yml -f version=baseline-v2          # from main
gh workflow run tag.yml -f version=baseline-v2 -f ref=<sha>
```

It refuses a version that is not `baseline-v<N>` and a tag that already
exists: a baseline tag is never moved. Then move the registry row in
orun-cloud's `infra/baselines-registry/baselines.yaml` by pull request —
after the tag exists, because the registry's sync fetches `blueprint.yaml`
at the tag and refuses the whole catalogue if it 404s.

## Troubleshooting

| Symptom | Cause → fix |
|---|---|
| `01-product` parks: `waiting for github for <org>` | the workspace's GitHub connection is to another account. Connect the App installation on `<org>` (console → Integrations → GitHub), then `--resume` |
| `01-product` stops at `link` | the repository is not linked to the workspace and the credential cannot link it. Allow-list it (console → Settings → Git repos) and re-run the phase |
| `01-product` waits on the `providers` probe, then stops | Cloudflare is not connected. Connect it (console → Integrations), then re-run the phase — the probe is a wait, not a failure |
| Secret WRITE fails `not_found` while listings work | the API key's role is below admin; re-mint it with the admin role |
| Deploy lane: Authentication error (10000) | the connection's token lacks Workers Scripts Write; re-issue it, re-connect, re-run `01-product` |
| Convergence failed AFTER the PR merged; re-running lands nothing | expected on its own — the files are on main. Re-run the phase (`--phase 01-product`, `--redo 01-product`, or the console's Retry): its `retouch` hook gives the landing a diff and the site redeploys |
| The site's `intent.yaml` says `workspace: ws_SET_ME` | `orunWorkspace` was empty and the build ran outside a workspace; set it and re-run `01-product` |
| A bootstrap stopped before `03-docs`; prod no longer waits on stage | the gate is deferred, not dropped: run `03-docs`, or `node tooling/bootstrap/promotion.mjs --restore --file <site>/intent.yaml` |
| `✕ input "productdomain" is required` | all four required inputs must be set on every invocation, single-phase ones included |
| `unknown flag: --phase` or a parse error in the blueprint | the CLI is below the v2.58.11 floor |
| `01-product` lanes fail in `build-app`: `Symlink apps/web/node_modules/next is invalid, it points out of the filesystem root` | the site's intent pins stack-tectonic ≥ 0.20.0, whose lane-scoped install links each job's node_modules out of its tree, which Next 16's Turbopack refuses. Pin 0.19.0 (baseline-v2 does; `intent.yaml` says why) |
| `01-product`'s convergence reported green, then `verify` got 404 from both URLs | a second workflow ran on the push to main and the watch took its run (baseline-v1's `checks.yml`). baseline-v2 runs `checks.yml` on pull requests only; read the CI run on main for the real result |
