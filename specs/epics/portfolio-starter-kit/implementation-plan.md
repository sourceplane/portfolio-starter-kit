# portfolio-starter-kit — implementation plan

Milestones land in order; each task is one pull request on an
`orun/PK-n-<slug>` branch with an `Orun-Task: PK-n` trailer.

## PK0 — the spec

This doc set, `epic.yaml` and the task contracts, merged to `main`.

**Done when**
- the five documents and `epic.yaml` are on `main`
- `tasks/PK-1..PK-3.TaskContract.yaml` exist

## PK1 — the portfolio on Workers

`apps/web` is the upstream template with the Workers build around it;
`tests/web` exercises the loader, `formatDate` and the sitemap.

**Done when**
- `pnpm install && pnpm typecheck && pnpm lint && pnpm test && pnpm build` is green locally and in `Checks`
- `wrangler dev` answers `/` and `/blog` (post list), `/blog/vim` (the post), `/blog/nope` (404), `/rss` (XML with three items), `/sitemap.xml`, `/robots.txt`, and `/og?title=Hello` with `image/png`

## PK2 — ready to instantiate

README (run, test, preview, deploy; `NEXT_PUBLIC_SITE_URL`,
`NEXT_PUBLIC_CF_BEACON_TOKEN`), `IMPLEMENTATION-STATUS.md`, epic `completed`.

**Done when**
- the README quick start works from a fresh clone
- the status file lists every PR and departure

## Sequencing note

PK1 needs only PK0's contracts; PK2 is documentation over PK1's verified
build. Deploying is the gated Orun lane, not a milestone.
