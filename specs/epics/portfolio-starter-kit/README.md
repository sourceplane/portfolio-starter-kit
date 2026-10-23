# Epic: portfolio-starter-kit (PK)

**Vercel's Portfolio Blog Starter is the blog-starter's bigger sibling: MDX instead of Markdown, an RSS feed, a sitemap, JSON-LD and dynamic Open Graph images. Three of those lean on Vercel-specific things — the analytics scripts, a hard-coded `vercel.app` origin, and `next/og` rendering images at request time — and all three have a Cloudflare answer: Cloudflare Web Analytics, the environment's Worker URL threaded into the build, and the same `ImageResponse` running inside the OpenNext Worker.**

The upstream code stays the code: the MDX components, the posts loader, the feed, the sitemap, the OG route. The port adds the Workers build, the monorepo wrapper, a test package for the loader and the sitemap, and the deploy contract. Departures are small and recorded: `params` is awaited (Next 15+), unknown slugs are a 404 (no filesystem on a Worker), the analytics component is Cloudflare's, the site origin comes from the environment, and the template's "deploy on Vercel" links point at this repository.

## Status

| Field | Value |
|-------|-------|
| Status | ✅ PK0–PK8 shipped (#1–#10): PK3 tagged `baseline-v1`, PK4 tagged `baseline-v2` and proven live by a console bootstrap (2026-10-15, 8m43s); PK5 (one landing, PK-6) and PK6 (the cirrus standard, PK-7, and the subdomain read from the Cloudflare connection, PK-8) tagged `baseline-v3`, the first tag of the one-landing shape — not yet proven live (risk PK-G); PK7 (the domain is set later, PK-9) tagged `baseline-v4`; PK8 (the build reads true, PK-10, [#10](https://github.com/sourceplane/portfolio-starter-kit/pull/10)) on `main`, not yet tagged |
| Cluster | **PK** (PK0–PK8) |
| Owner(s) | `apps/web` (the site) · `tests/web` (loader, date and sitemap tests) |
| Builds on | `cirrus-baseline` conventions; the `blog-starter` port's build shape (static-assets incremental cache + `populateCache`) |
| Upstream | [vercel/examples `solutions/blog`](https://github.com/vercel/examples/tree/main/solutions/blog) (the "Portfolio Starter Kit" template) |
| Changes | Adds the Workers build, the monorepo wrapper, tests and the deploy contract; swaps two Vercel scripts for one Cloudflare beacon; makes the origin an env var |
| Decisions locked | (1) OpenNext on Workers + Static Assets. (2) Posts pre-rendered, `dynamicParams = false`. (3) `baseUrl` = `NEXT_PUBLIC_SITE_URL`, set by the Orun build to the environment's Worker URL. (4) Tailwind 4 stable instead of the alpha the template pinned. |
| Gate | PK1 is the first user-visible rung. |
| Shipped as | `baseline-v1` ([#4](https://github.com/sourceplane/portfolio-starter-kit/pull/4)); `baseline-v2` ([#5](https://github.com/sourceplane/portfolio-starter-kit/pull/5)), live from the console on 2026-10-15; then `baseline-v3` (PK5: [#6](https://github.com/sourceplane/portfolio-starter-kit/pull/6); PK6: [#7](https://github.com/sourceplane/portfolio-starter-kit/pull/7), [#8](https://github.com/sourceplane/portfolio-starter-kit/pull/8)), then `baseline-v4` (PK7: [#9](https://github.com/sourceplane/portfolio-starter-kit/pull/9), no domain asked), proven offline (Baseline CI); PK8 ([#10](https://github.com/sourceplane/portfolio-starter-kit/pull/10)) untagged |

## Read order

1. `design.md` — what maps to what, the build, what is out of scope
2. `implementation-plan.md` — the milestones and what "done" means for each
3. `risks-and-open-questions.md` — what could go wrong and what was decided
4. `IMPLEMENTATION-STATUS.md` — what actually shipped (kept distinct from intent)

## Milestones at a glance

| Milestone | What it lands | Done when |
|---|---|---|
| PK0 — the spec | this doc set and the task contracts | merged on `main` |
| PK1 — the portfolio on Workers | `apps/web` built by OpenNext, `tests/web`, green checks | `wrangler dev` serves every route incl. `/og` as PNG; Checks green |
| PK2 — ready to instantiate | README, as-built status | a reader can run, test, preview and deploy it |
| PK3 — a baseline | card, build document, rename, bootstrap tooling, tests | a new site goes from nothing to live in three phases; Baseline CI green |
| PK4 — proven live | what the first live bootstrap found, fixed, and the tests that missed it | a site bootstrapped from the registered tag is live on stage and prod |
| PK5 — one landing | the site in one landing, each bootstrap landing checked by `plan` alone (cirrus-baseline baseline-v22's shape) | a site bootstrapped from the next tag is live faster than baseline-v2's 8m43s |
| PK6 — the cirrus standard | no kiox, generated component docs, the context pack, status that agrees with the tags; the subdomain read from the Cloudflare connection | Baseline CI green with the docs check; the card asks for no subdomain |
| PK7 — the domain is set later | the console asks for no domain; an empty `productdomain` brands the placeholder `<reponame>.example.com` for an owner to replace | Baseline CI green on a fixture with no domain |
| PK8 — the build reads true | every build-panel line short and true, landings labelled, the docs re-probe quiet; a site ships `AGENTS.md`; local `.env` and Terraform state never placed | Baseline CI green; a site carries `AGENTS.md`, branded |
