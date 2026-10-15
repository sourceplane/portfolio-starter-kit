# portfolio-starter-kit — risks and open questions

## PK-A — `next/og` inside the Worker (RISK, mitigated)

`ImageResponse` bundles Satori and a resvg wasm. It is the one request-time
render in the template and the one place a Worker's CPU and size limits
could bite. Mitigation: verified under `wrangler dev` (PK1's done-when),
and the image is small (text on white). If a product hits the limits, the
rejected alternative in `design.md` §2 (pre-render at build) is the fallback.

## PK-B — Tailwind 4 alpha → stable (RESOLVED)

The template pinned `tailwindcss@4.0.0-alpha.13`. The port uses the stable
4.x line; the template's `global.css` (`@import 'tailwindcss'`, `@apply`,
`dark:` via `prefers-color-scheme`) is valid as written.

## PK-C — `params` is a Promise (RESOLVED)

Next 15 made route `params` async and Next 16 removed the synchronous
access the template used (`params.slug`). The page and `generateMetadata`
now `await params`. Without it every post would 404 on Next 16.

## PK-D — Speed Insights has no one-to-one twin (ACCEPTED)

Cloudflare Web Analytics reports Core Web Vitals, which is what Speed
Insights showed; the dashboard differs. The beacon is opt-in by token.

## PK-E — Unknown post slugs (RESOLVED)

`dynamicParams = false`: a Worker has no filesystem at request time, so
every post is pre-rendered and anything else is a 404 (upstream would
`notFound()` after an on-demand `fs` read — same result, different path).

## PK-F — The RSS route handler on Next 15+ (RESOLVED)

GET route handlers stopped being cached by default in Next 15, so `/rss`
ran at request time and failed on the Worker (`readdir` of the posts
directory). `export const dynamic = 'force-static'` pre-renders it at build,
which is what the template did on Next 14.

## PK-G — No live bootstrap yet (OPEN)

Everything short of the platform is proven on every pull request: the card
against the build, the blueprint read by the pinned orun, the leak gate, the
offline bootstrap with the blueprint's own hooks, the site's own plan for the
02-site merge, and the produced site built, dry-deployed, served and
smoke-tested. What is NOT proven is the platform's half — the repository
created and linked, the Cloudflare token minted by `integrations/reconcile`,
a real `wrangler deploy`, the probes against workers.dev. Hence the registry
row is `unlisted` until one bootstrap from the tag has come up, as virga's
and cirrus-baseline's first tags were.

## PK-H — A custom domain is the owner's step (ACCEPTED)

Attaching a domain to a Worker needs zone-level permissions. The platform
brokers `workers-deploy` (Workers Scripts, KV, account read — no DNS) and
`dns-edit` only with zone ids, which a build does not have. Rather than ship a
parked component (Cirrus's `07-domain` is one), the site's README says how to
attach the domain and set `SITE_URL`, and the build honours it.

## PK-I — The build saw an empty workers.dev subdomain (RESOLVED)

`apps/web/component.yaml`'s `buildCommand` read `${WORKERS_DEV_SUBDOMAIN}`,
which the workers-assets composition exports to the smoke step only: every
deploy would have baked `https://<worker>-<env>..workers.dev` into the
sitemap, the feed and the Open Graph links. The subdomain is now written in
the command (and renamed with the rest of the identity), behind `SITE_URL`.

