# portfolio-starter-kit (PK) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template.

| Milestone | State | PR |
|---|---|---|
| PK0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/portfolio-starter-kit/pull/1) |
| PK1 — the portfolio on Workers | ✅ Shipped | [#2](https://github.com/sourceplane/portfolio-starter-kit/pull/2) |
| PK2 — ready to instantiate | ✅ Shipped | [#3](https://github.com/sourceplane/portfolio-starter-kit/pull/3) |
| PK3 — a baseline | ✅ Shipped | [#4](https://github.com/sourceplane/portfolio-starter-kit/pull/4) (PK-4), tagged `baseline-v1` |
| PK4 — proven live | 🟡 In progress | this PR (PK-5), to be tagged `baseline-v2` |

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
