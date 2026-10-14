# portfolio-starter-kit — design

## 1. What the template is

A portfolio with a blog. `app/blog/posts/*.mdx` are read with `fs` by
`app/blog/utils.ts` (a hand-rolled front-matter parser), listed on `/` and
`/blog`, rendered on `/blog/[slug]` with `next-mdx-remote/rsc` and
`sugar-high` highlighting, with JSON-LD per post. `/rss` is a route handler
that builds the feed, `sitemap.ts` and `robots.ts` are Next's metadata
routes, `/og` renders an Open Graph PNG with `next/og`'s `ImageResponse`.
Geist fonts, Tailwind 4, Vercel Analytics and Speed Insights.

## 2. The mapping (Vercel → Cloudflare)

| Vercel primitive the template uses | Here |
|---|---|
| Next.js hosting (SSG pages + route handlers) | Cloudflare Workers + Static Assets; pre-rendered pages, `/rss`, `/sitemap.xml` and `/robots.txt` are served from the static-assets incremental cache; `/og` runs in the Worker |
| `next/og` `ImageResponse` (Satori + resvg wasm) | Unchanged; runs under `nodejs_compat` in the OpenNext Worker |
| `@vercel/analytics` + `@vercel/speed-insights` | `app/components/analytics.tsx`: the Cloudflare Web Analytics beacon (Core Web Vitals included), rendered only when `NEXT_PUBLIC_CF_BEACON_TOKEN` is set |
| Hard-coded `https://portfolio-blog-starter.vercel.app` origin | `baseUrl = process.env.NEXT_PUBLIC_SITE_URL`; the Orun build sets it to `https://portfolio-starter-kit-web-<env>.<subdomain>.workers.dev`, a custom domain overrides it |
| Build-time `fs` reads of the posts | Unchanged: every post is pre-rendered; `dynamicParams = false` makes an unknown slug a 404 instead of a runtime `fs` call |
| Deploy on push | Orun: `apps/web/component.yaml` (`cloudflare-workers-assets-turbo`) deploys `portfolio-starter-kit-web-{stage,prod}` on merge to `main` once the product is linked |

Alternative rejected: pre-rendering the OG images at build time into
static assets. It would remove the only request-time render, but the
template's contract is `/og?title=<anything>`, and keeping it dynamic is
what makes the port equivalent.

## 3. The repository

```
apps/web               the template (app/, with posts under app/blog/posts) + the Workers build
  component.yaml       build with turbo (NEXT_PUBLIC_SITE_URL from the environment), deploy, smoke /
  wrangler.jsonc       worker name, nodejs_compat, ASSETS binding
  open-next.config.ts  static-assets incremental cache — the site binds nothing
tests/web              vitest: the posts loader, formatDate, the sitemap under a configured origin
```

## 4. The build

`pnpm --filter @app/web build` = `next build` (standalone, traced from the
monorepo root) → `opennextjs-cloudflare build --skipBuild` →
`opennextjs-cloudflare populateCache local` (copies the prerender cache into
the assets bundle). `NEXT_PUBLIC_SITE_URL` and `NEXT_PUBLIC_CF_BEACON_TOKEN`
are read at build time.

## 5. Out of scope

Comments, a CMS, image optimisation through Cloudflare Images (the template
uses `next/image` with local files, which OpenNext serves unoptimised), and
a custom domain (the baseline's `cloudflare-domain` root).
