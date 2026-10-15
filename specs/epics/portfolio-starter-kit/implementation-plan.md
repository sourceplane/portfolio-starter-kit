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

1. Cut `baseline-v1` with `tag.yml` from the merged `main`.
2. Register the row in orun-cloud's `infra/baselines-registry/baselines.yaml`
   (unlisted) with the card vendored at the tag.
3. Bootstrap one site from the tag against a workspace; record its timings;
   then flip the row to public with a page on orunbase.com.

## Sequencing note

PK1 needs only PK0's contracts; PK2 is documentation over PK1's verified
build; PK3 packages PK1's site as a baseline. Deploying is the gated Orun
lane, not a milestone.
