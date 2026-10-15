# apps/web — the site

A portfolio site with a blog, from Vercel's
[Portfolio Blog Starter](https://github.com/vercel/examples/tree/main/solutions/blog)
(MIT), running on Cloudflare Workers + Static Assets:

- MDX and Markdown posts (`app/blog/posts`), with syntax highlighting
- SEO: sitemap, robots, JSON-LD schema
- RSS feed (`/rss`)
- Dynamic Open Graph images (`/og?title=…`)
- Tailwind v4, Geist font
- Cloudflare Web Analytics (set `NEXT_PUBLIC_CF_BEACON_TOKEN`)

The site's name and the repository its nav links to are in `app/site.ts`.

```bash
pnpm dev        # next dev on http://localhost:3000
pnpm build      # next build + opennextjs-cloudflare build → .open-next/
pnpm preview    # wrangler dev over the built Worker
```

How it is deployed — per environment, on merge to `main` — is the
repository's README and `component.yaml` beside this file.
