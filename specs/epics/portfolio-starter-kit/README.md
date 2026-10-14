# Epic: portfolio-starter-kit (PK)

**Vercel's Portfolio Blog Starter is the blog-starter's bigger sibling: MDX instead of Markdown, an RSS feed, a sitemap, JSON-LD and dynamic Open Graph images. Three of those lean on Vercel-specific things — the analytics scripts, a hard-coded `vercel.app` origin, and `next/og` rendering images at request time — and all three have a Cloudflare answer: Cloudflare Web Analytics, the environment's Worker URL threaded into the build, and the same `ImageResponse` running inside the OpenNext Worker.**

The upstream code stays the code: the MDX components, the posts loader, the feed, the sitemap, the OG route. The port adds the Workers build, the monorepo wrapper, a test package for the loader and the sitemap, and the deploy contract. Departures are small and recorded: `params` is awaited (Next 15+), unknown slugs are a 404 (no filesystem on a Worker), the analytics component is Cloudflare's, the site origin comes from the environment, and the template's "deploy on Vercel" links point at this repository.

## Status

| Field | Value |
|-------|-------|
| Status | ✅ Shipped — PK0–PK2 landed (#1, #2, #3) |
| Cluster | **PK** (PK0–PK2) |
| Owner(s) | `apps/web` (the site) · `tests/web` (loader, date and sitemap tests) |
| Builds on | `cirrus-baseline` conventions; the `blog-starter` port's build shape (static-assets incremental cache + `populateCache`) |
| Upstream | [vercel/examples `solutions/blog`](https://github.com/vercel/examples/tree/main/solutions/blog) (the "Portfolio Starter Kit" template) |
| Changes | Adds the Workers build, the monorepo wrapper, tests and the deploy contract; swaps two Vercel scripts for one Cloudflare beacon; makes the origin an env var |
| Decisions locked | (1) OpenNext on Workers + Static Assets. (2) Posts pre-rendered, `dynamicParams = false`. (3) `baseUrl` = `NEXT_PUBLIC_SITE_URL`, set by the Orun build to the environment's Worker URL. (4) Tailwind 4 stable instead of the alpha the template pinned. |
| Gate | PK1 is the first user-visible rung. |
| Shipped as | `main` after [#3](https://github.com/sourceplane/portfolio-starter-kit/pull/3); verified locally under `wrangler dev`, deploy gated until a workspace is linked |

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
