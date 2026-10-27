# portfolio-starter-kit

Vercel's [Portfolio Blog Starter](https://github.com/vercel/examples/tree/main/solutions/blog)
(the "Portfolio Starter Kit" template) — MDX posts, syntax highlighting,
an RSS feed, a sitemap, JSON-LD and dynamic Open Graph images — running on
**Cloudflare Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare), and packaged
as an **Orun baseline**: one command takes a new site from nothing to live on
stage and prod, in its own repository, under its own name.

The template's code is the code. What the port adds is the Workers build,
the monorepo wrapper, a test package, and the deploy contract; what it
swaps is the two Vercel analytics scripts (for Cloudflare Web Analytics)
and the hard-coded site origin (for an environment variable). What the
baseline adds is everything needed to make a copy of it somebody else's —
built the way [cirrus-baseline](https://github.com/sourceplane/cirrus-baseline)
is. See [`specs/epics/portfolio-starter-kit`](specs/epics/portfolio-starter-kit/README.md)
for the design, the milestones and the as-built status.

## Instantiating a site

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/portfolio-starter-kit
cd portfolio-starter-kit
orun new --blueprint repo-blueprint.yaml --out ~/sites/acme-notes --run-hooks --resume \
  --set reponame=acme-notes --set productname="Acme Notes" \
  --set githuborg=acme-inc --set subdomain=<workers-dev-subdomain>
```

Or, once the platform's registry lists it, from the Orun console (Baselines →
`portfolio-starter-kit` → Build). Two phases — `01-product` (the repository
created, then the whole site in one pull request, deployed to stage and prod
and smoke-tested) and `03-docs` (the live deployment recorded) — each landing
one pull request in the new repository.
**[BOOTSTRAP.md](BOOTSTRAP.md)** is the operator guide;
[docs/phases/](docs/phases/README.md) has a page per phase.

The new repository receives the **site only** — the app, its tests, its CI,
its tooling, a README and an `AGENTS.md` of its own and its operating
contract — renamed throughout to the site's name, repository and Cloudflare
Worker. None of this repository's machinery ships.

| What makes it a baseline | Where |
|---|---|
| The console card (inputs, secrets, programme) | `blueprint.yaml` |
| The build document (modules, phases, hooks) | `repo-blueprint.yaml` |
| This tree's identity, and the bootstrap's task contracts | `.baseline/` |
| The rename engine | `tooling/rebrand/rebrand.mjs` |
| The bootstrap's helpers (deferrals, redeploy marker, work-tree strip) | `tooling/bootstrap/` |
| The deployment-record renderer | `hooks/render-deployment-docs.sh` |
| The site's README, agent page and context pack | `.baseline/product/README.md`, `.baseline/product/AGENTS.md`, `ai/context/` |
| The baseline's tests: contract, leak, offline bootstrap, end to end | `testing/`, `.github/workflows/baseline.yml` |
| Cutting a `baseline-vN` tag | `.github/workflows/tag.yml` |

## What is here (the site)

| Surface | Where |
|---|---|
| The site's name and source link | `apps/web/app/site.ts` |
| Home, `/blog`, `/blog/[slug]` | `apps/web/app` |
| Posts (MDX with front matter) | `apps/web/app/blog/posts` |
| RSS, sitemap, robots, OG images | `apps/web/app/rss/route.ts`, `app/sitemap.ts`, `app/robots.ts`, `app/og/route.tsx` |
| MDX components, posts loader | `apps/web/app/components/mdx.tsx`, `apps/web/app/blog/utils.ts` |
| Workers build and deploy contract | `apps/web/next.config.mjs`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` |
| Tests | `tests/web` (vitest) |

## Getting started

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build            # next build + opennextjs-cloudflare build → apps/web/.open-next
```

```bash
pnpm --filter @app/web dev        # http://localhost:3000
pnpm --filter @app/web preview    # wrangler dev over the built Worker
```

Two optional build-time variables (`apps/web/.env.example`):

| Variable | What it does |
|---|---|
| `NEXT_PUBLIC_SITE_URL` | The site's public origin for sitemap, RSS, OG and JSON-LD links. The Orun build sets it to the environment's `SITE_URL` (intent.yaml), else its Worker URL. Defaults to `http://localhost:3000`. |
| `NEXT_PUBLIC_CF_BEACON_TOKEN` | Cloudflare Web Analytics token (dashboard → Web Analytics → add a site). Unset, no script is rendered. |

Add a post by dropping an `.mdx` file with front matter (`title`,
`publishedAt`, `summary`) into `apps/web/app/blog/posts/`.

## How it maps to Vercel

| Vercel | Here |
|---|---|
| Next.js hosting (SSG + route handlers) | One Cloudflare Worker (`.open-next/worker.js`) + Static Assets; pre-rendered pages and the feed come from the static-assets cache, `/og` renders in the Worker |
| `next/og` `ImageResponse` | Unchanged, runs under `nodejs_compat` |
| Vercel Analytics + Speed Insights | Cloudflare Web Analytics beacon (`app/components/analytics.tsx`) |
| Hard-coded `vercel.app` origin | `NEXT_PUBLIC_SITE_URL` |
| Deploy on push | Orun deploys `<repo>-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`) |
| "Deploy with Vercel" (clone the template) | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

## CI

| Workflow | What it runs | Ships to a site |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a site carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the site built and dry-deployed per environment; the tests' `quick-check` lane installs and checks the package, it does not run them), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone is the check; a merge deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
| `baseline.yml` | the baseline's own tiers: contract tests, the blueprint read by the pinned orun, the leak gate, the offline bootstrap, the site built, dry-deployed and served | no |
| `tag.yml` | cuts a `baseline-vN` tag (manual) | no |
