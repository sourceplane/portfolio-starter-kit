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
a custom-domain component (§6: the brokered deploy token carries no zone
permissions, so attaching a domain is the owner's step, and `SITE_URL` makes
the build use it).

## 6. The baseline (PK3)

The repository instantiates new sites the way
[cirrus-baseline](https://github.com/sourceplane/cirrus-baseline) instantiates
products: a console card (`blueprint.yaml`) the platform renders, a build
document (`repo-blueprint.yaml`) `orun new` runs, and a rename engine that
makes the copy somebody else's.

| Cirrus | Here | Why the difference |
|---|---|---|
| `01-product` (the whole product in one landing), `07-domain`, `08-docs` (baseline-v22) | two: `01-product` (the whole site in one landing), `03-docs` (PK-6; three — `01-scaffold`, `02-site`, `03-docs` — before it) | one component deploys; no data plane, no fleet, no bindings, no domain phase |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_D1_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | `CLOUDFLARE_API_TOKEN` (`workers-deploy`), `CLOUDFLARE_ACCOUNT_ID` | no D1 |
| `07-domain` (parked component) | no domain phase; `SITE_URL` per environment | `workers-deploy` has no DNS or zone scope; `dns-edit` needs zone ids a build does not have |
| task contracts in `tasks/` | `.baseline/tasks/` | `tasks/` is this repository's own work tree (`intent.yaml` `work:`), where an unkeyed contract is an error |
| ships its own README | ships `.baseline/product/README.md` as the site's README | this README is about the baseline; a site's owner needs the site's |
| — | `work-tree.mjs` strips `work:` from the site's intent | a site has no `specs/` or `tasks/` |
| stack-tectonic 0.20.0 (lane-scoped install) | 0.19.0 (the job installs in its own tree) | Next 16's Turbopack cannot build through the lane's symlinked `node_modules` (risks PK-J) |
| one push workflow (`ci.yml`), no `checks.yml` | `checks.yml` on pull requests only, its job skipped on bootstrap branches (`orun/BASE-…`) | `orun.run/watch@v1` takes the newest run for a commit from any workflow (risks PK-K); a bootstrap landing is checked by `plan` alone, as Cirrus's is (PK-6) |
| rebrand rules for a SaaS (console prefix, SDK class, CLI bin, API host) | rules for a site: the source link (owner + repo), the `SITE_NAME` seam, the domain, the subdomain, Worker names, secret refs, the repo slug | the identity this tree actually carries |

**Identity in the app** is two literals in `apps/web/app/site.ts`: `SITE_NAME`
(the heading, page titles, Open Graph card, RSS channel, JSON-LD author) and
`SOURCE_URL` (the nav and footer). The rename writes the site name with
`JSON.stringify`, so any name the card's pattern admits — apostrophes and
ampersands included — stays a valid string; the RSS channel escapes it.

**The site's CI is on from its first commit.** `ci.yml` used to wait for an
`ORUN_CI` repository variable, which a bootstrap has no way to set: every site
would have converged on nothing. It now plans nothing only while
`intent.yaml` names the placeholder `ws_CHANGE_ME`, which this repository
carries and no site does (the scaffold writes the site's workspace, or
`ws_SET_ME`, which fails loudly).

**Testing without the platform.** `testing/lib/bootstrap.sh` places every
phase and runs the blueprint's own `run:` hooks, read out of the document, so
the whole bootstrap short of the platform's typed actions runs in CI on every
pull request; `testing/e2e.test.sh` then builds, dry-deploys and serves what it
produced and runs the component's own smoke against it.
