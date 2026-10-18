# portfolio-starter-kit (PK) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template.

| Milestone | State | PR |
|---|---|---|
| PK0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/portfolio-starter-kit/pull/1) |
| PK1 — the portfolio on Workers | ✅ Shipped | [#2](https://github.com/sourceplane/portfolio-starter-kit/pull/2) |
| PK2 — ready to instantiate | ✅ Shipped | [#3](https://github.com/sourceplane/portfolio-starter-kit/pull/3) |
| PK3 — a baseline | ✅ Shipped | [#4](https://github.com/sourceplane/portfolio-starter-kit/pull/4) (PK-4), tagged `baseline-v1` |
| PK4 — proven live | ✅ Shipped | [#5](https://github.com/sourceplane/portfolio-starter-kit/pull/5) (PK-5), tagged `baseline-v2`; proven by a console bootstrap on 2026-10-15 (below) |
| PK5 — one landing | ✅ Shipped | [#6](https://github.com/sourceplane/portfolio-starter-kit/pull/6) (PK-6) — on `main`, not yet tagged; not yet proven by a live bootstrap (risk PK-G) |
| PK6 — the cirrus standard | ✅ Shipped | PK-7 — on `main` after `baseline-v2`, not yet tagged |

## Departures from the upstream template

### `await params` in `app/blog/[slug]/page.tsx`

Next 16 route params are a Promise; the template's synchronous `params.slug`
read `undefined` and every post 404'd. Both `generateMetadata` and the page
await them.

### `dynamicParams = false` on `blog/[slug]`

Every post is pre-rendered; an unknown slug is a 404 (no filesystem on a
Worker).

### `dynamic = 'force-static'` on `app/rss/route.ts`

Next 15 made GET route handlers dynamic by default; the feed reads the posts
with `fs`, which a Worker has only at build time, so it is pre-rendered like
the sitemap (the template on Next 14 was static anyway).

### Cloudflare Web Analytics instead of `@vercel/analytics` + `@vercel/speed-insights`

`app/components/analytics.tsx` renders the beacon script when
`NEXT_PUBLIC_CF_BEACON_TOKEN` is set; otherwise nothing.

### `baseUrl` from `NEXT_PUBLIC_SITE_URL`

The template hard-codes its Vercel demo origin; the port reads the
environment (the Orun build sets the Worker URL; `http://localhost:3000`
when unset).

### Tailwind 4 stable

`tailwindcss` and `@tailwindcss/postcss` move from `4.0.0-alpha.13` to the
stable 4.x line.

### "deploy" / "view source" links

The nav's `deploy` item and the footer's `view source` link pointed at the
Vercel template page; they point at this repository (the nav item reads
`source`).

### The site's name and source link come from `app/site.ts` (PK3)

`SITE_NAME` replaces the template's two names — "My Portfolio" (heading, Open
Graph, RSS, JSON-LD author) and "Next.js Portfolio Starter" (the default
`<title>` and the `/og` fallback) — with one; `SOURCE_URL` replaces the
repository link in the nav and the footer. They are the seam the baseline's
rename rewrites. The RSS channel title is XML-escaped.

### `apps/web/README.md` is the app's, not the template's (PK3)

The upstream README advertised "Deploy with Vercel" and a Vercel demo, and it
ships into every site. It now describes the app and credits the template (MIT).

## Departures from the port (PK3)

| What | Before | After | Why |
|---|---|---|---|
| `apps/web` build origin | `${WORKERS_DEV_SUBDOMAIN}` | the subdomain literal, behind `${SITE_URL:-…}` | the composition exports the subdomain to the smoke step only (risks PK-I) |
| `apps/web` smoke | `grep 'My Portfolio'` | the nav's `/blog` link, and `/rss` is a feed | the name is the owner's, and HTML-escaped when it carries `&` or `'` |
| `ci.yml` gate | `vars.ORUN_CI == 'true'` | skip only while `intent.yaml` names `ws_CHANGE_ME` | a bootstrap cannot set a repository variable |
| stack-tectonic | 0.18.2 | 0.20.0 | first-deploy retry (0.19.0), one install per lane (0.20.0) — cirrus-baseline's pin |
| orun lane pin | v2.78.0 | v2.78.4 | cirrus-baseline's pin |
| `intent.yaml` | terraform `parameterDefaults`; docs pages under `specs/` | neither; docs pages `ai/context/*` | no terraform component; the pages must exist in a site |
| `tasks/PK-1..3` | no `metadata` | `metadata.name` and `title` | `orun work check` (≥ v2.79) refused them |

## The cirrus standard (PK6)

Nothing about the site changed. What changed is the baseline around it:

| What | Before | After | Why |
|---|---|---|---|
| orun pin | `kiox.yaml` (v2.15.0) + `kiox.lock`, shipped to every site | gone; orun is pinned where it runs, the `orun-action` `version:` in each workflow | nothing ran the kiox pin, and it disagreed with the lanes (v2.78.4) |
| `root-kiox`, `root-kiox-lock` modules | in `01-product` | removed (`testing/phases.test.sh`, the rebrand's skip list and `docs/phases/01-product.md` follow) | a site is placed with 65 − 2 + 6 = 69 files: no kiox, plus the docs below |
| component docs | none | `apps/web/docs/` and `tests/web/docs/` — `overview.md`, `architecture.md`, `runbook.md` | cirrus-baseline documents every component; the workspace Docs library renders `docs/` beside each `component.yaml` |
| how the docs stay true | — | `tooling/catalog/gen-component-docs.py` derives them from the manifest, the Worker config, Terraform, migrations and package scripts; Baseline CI runs it with `--check` | a hand-written copy of a manifest drifts silently |
| context pack | `operations.md`, `deployment.md` | plus `current.md`, `decisions.md`, `open-risks.md` | cirrus-baseline's shape; the three new pages are this repository's own and no module places them (the leak gate still allows exactly two) |
| status | PK5 "in progress, this PR, to be tagged `baseline-v3`"; risk PK-G "no live bootstrap yet", planning the `02-site` merge; no PK4 or PK5 in the plan | PK5 shipped, on `main`, untagged; PK-G says `baseline-v2` went live and the one-landing shape has not; the plan has PK4–PK6 | the documents had not caught up with the tags and the live run |

## Verified (PK6)

- `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer}.test.sh`
  green; `gen-component-docs.py --check` green (2 components, 6 pages).
- `testing/leak.test.sh` (v2.58.11): 69 files derived (65 − 2 kiox + 6 docs
  pages); ai/context still exactly the two declared pages; nothing of the
  factory, nothing local or built, no provenance prose.
- `testing/placement.test.sh` (v2.58.11, as `baseline.yml` runs it): 69
  files placed, both landings, branded, re-tenanted; the site's own `orun
  plan` for the 01-product merge deploys `web` to stage and prod side by
  side; `--resume` changes nothing.
- `pnpm install --frozen-lockfile`, `wire:fixture`, `typecheck`, `lint`,
  `test` (5 tests, 2 files), `build` green.
- `testing/e2e.test.sh` (v2.78.4) green: the finished site under the Checks
  sequence, the stage lane's planned steps in a staged job tree, `wrangler
  dev` over the built Worker, the component's own smoke, and `/`, `/blog`, a
  post, a 404, `/rss`, `/sitemap.xml`, `/robots.txt` and `/og` on the stage
  origin.
- `orun task check PK-7` complete.

## One landing (PK5)

cirrus-baseline's baseline-v22 builds its whole product in one landing
(`01-product`) and checks each bootstrap pull request with `plan` alone. This
baseline now does the same (PK-6):

| Before (baseline-v2) | Now | Why |
|---|---|---|
| three phases: `01-scaffold`, `02-site`, `03-docs` | two: `01-product` (every module), `03-docs` (hooks only; its name kept, the gap kept, as Cirrus kept `08-docs`) | a landing has a fixed cost (place, PR, checks, merge, convergence start); nothing in the scaffold/site split was order the plan could not carry |
| `01-scaffold` waited on Checks (install, typecheck, lint, test, build) and `plan`; `02-site` merged without waiting (`wait: false`); `03-docs` waited on both | every landing waits on its PR's CI, which on `orun/BASE-…` is `plan` alone: `ci.yml` skips the lanes and `checks.yml` now skips its job | the convergence on main installs, builds, deploys and smoke-tests the site for real, and this baseline's own CI runs the Checks over a bootstrapped tree at the tag being built (e2e); Checks on the PR was the same build twice, and most of each landing's wait |
| the brokered secrets minted in `02-site`'s `pre` | minted in `01-product`'s `post`, after `repo` and `link`, before `land` | the repository exists and is linked before a secret is written for its project — Cirrus's order |
| `02-site` seeded the lockfile from the baseline's, then pruned | `pnpm install --lockfile-only` only confirms the placed lockfile | the whole tree is placed at once, so the complete lockfile is already the right one |
| `.baseline/tasks/01-scaffold`, `02-site` | `.baseline/tasks/01-product` (`affects: [web, web-tests]` — the retouch set) | one landing, one task |
| the offline bootstrap committed one landing per phase from an empty repository | the repository's empty first commit, then one per phase | on the platform the first pull request opens against an empty "Initial commit" by `orun`; it is the base the one landing's push is planned against (`testing/placement.test.sh` §4, `testing/e2e.test.sh` §2) |
| e2e ran the Checks at the scaffold's landing and at the finished site | at the finished site only | there is no scaffold landing, and no landing waits on Checks |

Measured on `baseline-v2` from the console's Build, 2026-10-15
(`portfolio-live`, `bst_R3SZP8S4`): 8m43s end to end — about 1m50s of build
sandbox start, `01-scaffold` 1m5s, `02-site` 4m7s, `03-docs` 1m40s (its
landing waited 52s on Checks). The estimate here is 6 minutes (5 + 1), to be
replaced by the first bootstrap from `baseline-v3`.

## The first live bootstrap (PK4)

`baseline-v1`, registered unlisted, built in workspace
`test-portfolio-starter-kit`: `01-scaffold` landed; `02-site` stopped at its
final probe (404 on both workers.dev URLs). Two findings, both fixed here
(risks PK-J, PK-K):

| Finding | Cause | Fix |
|---|---|---|
| both deploy lanes failed `build-app` | stack-tectonic 0.20.0's lane-scoped install links each job's `node_modules` out of its staged tree; Next 16's Turbopack refuses it | pin stack-tectonic 0.19.0 (the job installs inside its own tree) |
| the watch reported the convergence green | `orun.run/watch@v1` took `checks.yml`'s run for the commit | `checks.yml` on pull requests only; a gate that only `ci.yml` runs on push |
| the tests passed anyway | e2e replayed the lane in a plain checkout | e2e stages the job as orun does (`testing/lib/stage-job.py`), with the planned install layout: red on 0.20.0, green on 0.19.0 |

## Verified (PK3)

- `orun new --status` reads the blueprint at v2.58.11 (the bootstrap floor),
  v2.78.4 (the lane pin) and v2.79.0.
- `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer}.test.sh`
  green; `orun work check` clean.
- `testing/leak.test.sh`: 65 files derived; nothing of the factory, nothing
  local or built; no provenance prose.
- `testing/placement.test.sh` (offline bootstrap, fixture "Sam's Notes &
  Links" / `acme-inc/acme-portfolio`): three landings; rebrand `--verify`
  clean; workspace re-tenanted, `work:` stripped, promotion and dev lanes
  restored; deployment record rendered; the site's own `orun plan` for the
  02-site merge deploys `web` to stage and prod side by side with the site's
  origin, Worker name, smoke and secret refs; `--resume` changes nothing.
- `testing/e2e.test.sh`: the scaffold's landing and the finished site pass
  the Checks sequence; the stage lane's `build-app`, `verify-build-output` and
  `deploy-dry-run` pass; `wrangler dev` serves the built Worker; the
  component's own smoke passes; `/`, `/blog`, a post, a 404, `/rss` (well-formed
  with the escaped name), `/sitemap.xml` (absolute on the stage origin),
  `/robots.txt` and `/og` (PNG) are the site's own.
- Not verified: a live bootstrap against a workspace (risks PK-G).

## Verified (PK1–PK2)

- Local: `pnpm typecheck`, `pnpm lint`, `pnpm test` (3 tests), `pnpm build`
  green; `wrangler dev` over `.open-next/worker.js`: `/`, `/blog`,
  `/blog/vim` 200; `/blog/nope` 404; `/rss` 200 `text/xml` with 3 items;
  `/sitemap.xml` 200; `/robots.txt` 200; `/og?title=Hello` 200 `image/png`
  1200×630.
- CI: `Checks` green on #2.
- Not verified: a live deploy (gated until the product is linked to an Orun
  workspace with a Cloudflare connection) and the Web Analytics beacon with
  a real token.

## Versions

| Package | Version | Why |
|---|---|---|
| next | 16.3.8 | newest inside `@opennextjs/cloudflare` 1.20.11's peer range |
| @opennextjs/cloudflare | ^1.20.11 | static-assets incremental cache + `populateCache local` |
| tailwindcss, @tailwindcss/postcss | ^4.1 (stable) | the template pinned `4.0.0-alpha.13` |
| next-mdx-remote | ^6.0.0 | as upstream |
