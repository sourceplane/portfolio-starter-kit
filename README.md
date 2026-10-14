# portfolio-starter-kit

Vercel's [Portfolio Blog Starter](https://github.com/vercel/examples/tree/main/solutions/blog)
(the "Portfolio Starter Kit" template) — MDX posts, syntax highlighting,
an RSS feed, a sitemap, JSON-LD and dynamic Open Graph images — running on
**Cloudflare Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare), inside the
repository conventions of the
[Cirrus baseline](https://github.com/sourceplane/cirrus-baseline).

The template's code is the code. What the port adds is the Workers build,
the monorepo wrapper, a test package, and the deploy contract; what it
swaps is the two Vercel analytics scripts (for Cloudflare Web Analytics)
and the hard-coded site origin (for an environment variable). See
[`specs/epics/portfolio-starter-kit`](specs/epics/portfolio-starter-kit/README.md)
for the design, the milestones and the as-built status.

## What is here

| Surface | Where |
|---|---|
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
| `NEXT_PUBLIC_SITE_URL` | The site's public origin for sitemap, RSS, OG and JSON-LD links. The Orun build sets it to the environment's Worker URL; set it for a custom domain. Defaults to `http://localhost:3000`. |
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
| Deploy on push | Orun deploys `portfolio-starter-kit-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`) |

## Deploying

`.github/workflows/checks.yml` runs install, typecheck, lint, test and build
on every push and pull request. `ci.yml` is the Orun pipeline: set
`execution.state.workspace` in `intent.yaml` to this product's workspace
(`orun cloud link`), connect a Cloudflare account to it, and set the
`ORUN_CI` repository variable to `true`. A merge to `main` then deploys the
Worker to `stage`, then `prod`.
