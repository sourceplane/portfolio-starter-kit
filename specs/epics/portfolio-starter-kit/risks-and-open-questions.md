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

## PK-G — The one-landing shape is not yet proven live (OPEN; `baseline-v2` was)

Everything short of the platform is proven on every pull request: the card
against the build, the blueprint read by the pinned orun, the leak gate, the
offline bootstrap with the blueprint's own hooks, the site's own plan for the
01-product merge, and the produced site built, dry-deployed, served and
smoke-tested. The platform's half — the repository created and linked, the
Cloudflare token minted by `integrations/reconcile`, a real `wrangler
deploy`, the probes against workers.dev — only a live bootstrap proves.

*2026-10-15:* the first live bootstrap, from `baseline-v1` (workspace
`test-portfolio-starter-kit`), stopped at `02-site`'s final probe and found
PK-J and PK-K. `baseline-v2`, with both fixed, then went live from the
console's Build (`portfolio-live`, `bst_R3SZP8S4`): 8m43s end to end, over
its three landings (IMPLEMENTATION-STATUS, PK5). What `main` builds since
PK5 — one landing, `01-product`, then `03-docs` — has not been bootstrapped
live. The first bootstrap from the next tag closes this, and replaces PK5's
6-minute estimate with a measurement.

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

## PK-J — Turbopack cannot build through a lane-shared install (RESOLVED in baseline-v2)

The first live bootstrap (workspace `test-portfolio-starter-kit`, from
`baseline-v1`) failed both deploy lanes in `build-app`:

```
Symlink [project]/apps/web/node_modules/next is invalid, it points out of the filesystem root
```

stack-tectonic 0.20.0 marks the workspace install `scope: lane`; orun runs it
once in the source checkout and stages every job's tree with its top-level
`node_modules` as a symlink to the source's (orun
`internal/runner/workspace.go`, `materializeTree`). Next 16 builds with
Turbopack, which refuses a dependency that resolves outside its root.

Rejected fixes: `next build --webpack` gets past the symlink but bundles
`next/og`'s Node build, which reads fonts from disk and compiles wasm at
runtime — `/og` answered 500 under `wrangler dev`; `turbopack.root` must equal
`outputFileTracingRoot`, and moving that reshapes OpenNext's standalone
output. Fix: pin stack-tectonic **0.19.0**, where the job installs inside its
own staged tree; with one job per lane the shared install saved nothing.

Why the tests missed it: `testing/e2e.test.sh` replayed the lane's steps in a
plain checkout. It now stages the job as orun does (`testing/lib/stage-job.py`)
with the install layout the pinned composition plans — reproduced red on
`baseline-v1`'s pin, green on 0.19.0 — so a future bump is tested, not assumed.
Upstream: stack-tectonic's lane-scoped install is incompatible with a Next 16
(Turbopack) build in `cloudflare-workers-assets-turbo`.

## PK-K — The convergence watch read the wrong workflow (RESOLVED in baseline-v2)

The same bootstrap's `converge` step reported green while the platform's run
had failed: `orun.run/watch@v1` with `sha:` takes the newest workflow run for
the commit from ANY workflow (`RunForCommit`, `per_page=1`), and `checks.yml`
also ran on the push to main. The final `verify` probe caught it (404 from
both URLs). `checks.yml` now runs on pull requests only, so a push to main
starts `ci.yml` alone; `testing/coverage.test.sh` fails if a shipped workflow
other than `ci.yml` runs on push. Upstream: the watch could select the run by
workflow (e.g. the one that ran `orun run`).
