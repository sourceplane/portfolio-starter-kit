# portfolio-starter-kit (PK) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template.

| Milestone | State | PR |
|---|---|---|
| PK0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/portfolio-starter-kit/pull/1) |
| PK1 — the portfolio on Workers | ✅ Shipped | [#2](https://github.com/sourceplane/portfolio-starter-kit/pull/2) |
| PK2 — ready to instantiate | ✅ Shipped | [#3](https://github.com/sourceplane/portfolio-starter-kit/pull/3) |

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

## Verified

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
