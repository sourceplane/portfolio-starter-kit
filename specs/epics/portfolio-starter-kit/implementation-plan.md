# portfolio-starter-kit — implementation plan

Milestones land in order; each task is one pull request on an
`orun/PK-n-<slug>` branch with an `Orun-Task: PK-n` trailer.

## PK0 — the spec ✅

This doc set, `epic.yaml` and the task contracts, merged to `main`.

**Done when**
- the five documents and `epic.yaml` are on `main`
- `tasks/PK-1..PK-3.TaskContract.yaml` exist (PK-4 joined with PK3)

## PK1 — the portfolio on Workers ✅

`apps/web` is the upstream template with the Workers build around it;
`tests/web` exercises the loader, `formatDate` and the sitemap.

**Done when**
- `pnpm install && pnpm typecheck && pnpm lint && pnpm test && pnpm build` is green locally and in `Checks`
- `wrangler dev` answers `/` and `/blog` (post list), `/blog/vim` (the post), `/blog/nope` (404), `/rss` (XML with three items), `/sitemap.xml`, `/robots.txt`, and `/og?title=Hello` with `image/png`

## PK2 — ready to instantiate ✅

README (run, test, preview, deploy; `NEXT_PUBLIC_SITE_URL`,
`NEXT_PUBLIC_CF_BEACON_TOKEN`), `IMPLEMENTATION-STATUS.md`, epic `completed`.

**Done when**
- the README quick start works from a fresh clone
- the status file lists every PR and departure

## PK3 — a baseline ✅

`blueprint.yaml`, `repo-blueprint.yaml`, `.baseline/` (identity, task
contracts, the site's README), `tooling/rebrand`, `tooling/bootstrap`,
`hooks/render-deployment-docs.sh`, `ai/context/`, `docs/phases/`,
`BOOTSTRAP.md`, `testing/`, `baseline.yml` and `tag.yml` (design §6).

**Done when**
- orun at the bootstrap floor (v2.58.11) and at the lane pin (v2.78.4) reads
  `repo-blueprint.yaml`, and `testing/manifest.test.sh` holds the card to it
- `Baseline CI` is green: the contract tests, the leak gate, the offline
  bootstrap (`testing/placement.test.sh`) and the end-to-end tier
  (`testing/e2e.test.sh`)
- the status file records what is proven offline and what only a live
  bootstrap can prove

## After PK3 (outside this repository)

1. Cut `baseline-v1` with `tag.yml` from the merged `main` — done:
   `baseline-v1` is [#4](https://github.com/sourceplane/portfolio-starter-kit/pull/4)'s merge.
2. Register the row in orun-cloud's `infra/baselines-registry/baselines.yaml`
   (unlisted) with the card vendored at the tag — done (IMPLEMENTATION-STATUS,
   PK4).
3. Bootstrap one site from the tag against a workspace; record its timings;
   then flip the row to public with a page on orunbase.com. The bootstrap
   from `baseline-v1` failed and became PK4; `baseline-v2`'s came up on
   2026-10-15 in 8m43s. The row's listing is the registry's record, not this
   repository's.

## PK4 — proven live ✅

What the first live bootstrap (from `baseline-v1`, workspace
`test-portfolio-starter-kit`) found, fixed, and the tests that missed it:

- stack-tectonic pinned to 0.19.0: 0.20.0's lane-shared install links each
  job's `node_modules` out of its tree, and Turbopack refuses it (risk PK-J);
- `checks.yml` on pull requests only, so the convergence watch reads
  `ci.yml`'s run on a push to main (risk PK-K);
- `testing/e2e.test.sh` stages the job as orun does
  (`testing/lib/stage-job.py`), red on the old pin, green on the new.

**Done when**
- a site bootstrapped from the registered tag is live on stage and prod, its
  deployment record on main — `baseline-v2`, 2026-10-15 (8m43s)
- what the first live bootstrap found is fixed, and the tests that missed it
  now reproduce it

## PK5 — one landing ✅

cirrus-baseline baseline-v22's shape: two phases instead of three —
`01-product` places, brands and lands the whole site, and its convergence
deploys it to stage and prod; `03-docs` records it — the brokered secrets
minted in `01-product`'s `post`, and each bootstrap landing checked by
`plan` alone (`ci.yml` skips the lanes and `checks.yml` its job on
`orun/BASE-…` branches).

**Done when**
- `repo-blueprint.yaml` builds the site in one landing and records it in a
  second; the card's programme names the same two
- Baseline CI is green, and a site bootstrapped from the next tag is live
  faster than `baseline-v2`'s 8m43s — the live half waits for a bootstrap
  from `baseline-v3`, the first tag that carries PK5 (risk PK-G)

## PK6 — the cirrus standard ✅

Bring the baseline to cirrus-baseline's standard, with nothing about the
site itself changing.

- **No kiox.** `kiox.yaml`/`kiox.lock` pinned an orun (v2.15.0) that nothing
  ran: every workflow installs orun itself through `orun-action` with its own
  `version:`. The files, their two modules and the rebrand's skip entry go.
- **Component docs.** `tooling/catalog/gen-component-docs.py` writes each
  component's `docs/overview.md`, `docs/architecture.md` and `docs/runbook.md`
  from what the component declares, as cirrus-baseline's do; the pages ship
  with the component. Baseline CI runs it with `--check`.
- **The context pack.** `ai/context/current.md`, `decisions.md` and
  `open-risks.md` beside the two pages a site ships with — this
  repository's own, so no module places them.
- **Status that agrees with the tags.** PK5 is shipped (untagged until
  `baseline-v3`); risk PK-G says what `baseline-v2` proved live and what the
  one-landing shape has not.
- **The subdomain from the Cloudflare connection (PK-8).** The card's
  `subdomain` input declares `from: connection.cloudflare.workersSubdomain`,
  as cirrus-baseline's does since baseline-v23: the bootstrap door fills it
  from the connection the build is bound to, so the console asks for nothing
  a typo could get wrong. `testing/manifest.test.sh` takes cirrus-baseline's
  rule, which requires the provider in `spec.requires.integrations`.

**Done when**
- nothing outside this milestone's own record names kiox (`git grep -i
  kiox`), and the leak gate and the offline bootstrap pass without the two
  modules
- the docs check is green in Baseline CI
- this file, the status file and `epic.yaml` agree

## PK7 — the domain is set later (PK-9) ✅

**Done when** the console card asks for no domain; `productdomain` is an
optional build input, empty by default; a site built without one is branded
with the reserved placeholder `<reponame>.example.com` where the domain goes
(`BASE_DOMAIN` in `intent.yaml`, the README's `SITE_URL` example), its
absolute links keep the workers.dev origin until an owner sets `SITE_URL`,
and its README says how an owner sets the real one; Baseline CI places,
leak-checks and plans a site built with no domain. Shipped in `baseline-v4`.

## Sequencing note

PK1 needs only PK0's contracts; PK2 is documentation over PK1's verified
build; PK3 packages PK1's site as a baseline. Deploying is the gated Orun
lane, not a milestone.
