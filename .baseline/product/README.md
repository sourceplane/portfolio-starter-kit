# portfolio-starter-kit

A portfolio and blog — MDX posts with syntax highlighting, an RSS feed, a
sitemap, JSON-LD and dynamic Open Graph images — on **Cloudflare Workers +
Static Assets** through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare).

Working on it with a coding agent? [AGENTS.md](AGENTS.md) says what to read
first, how a change lands and what not to touch.

## Live deployment

<!-- 03-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the site uses into
[ai/context/deployment.md](ai/context/deployment.md); how the site deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 03-docs:end -->

## What is here

| Surface | Where |
|---|---|
| The site's name and source link | `apps/web/app/site.ts` |
| Home, `/blog`, `/blog/[slug]` | `apps/web/app` |
| Posts (MDX with front matter) | `apps/web/app/blog/posts` |
| RSS, sitemap, robots, OG images | `apps/web/app/rss/route.ts`, `app/sitemap.ts`, `app/robots.ts`, `app/og/route.tsx` |
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

Write a post by dropping an `.mdx` file with front matter (`title`,
`publishedAt`, `summary`) into `apps/web/app/blog/posts/`. Make the site
yours in `apps/web/app/page.tsx` (the home page) and `apps/web/app/site.ts`
(its name and the repository the nav links to).

Two optional build-time variables (`apps/web/.env.example`):

| Variable | What it does |
|---|---|
| `NEXT_PUBLIC_SITE_URL` | The site's public origin for sitemap, RSS, OG and JSON-LD links. The deploy sets it per environment (see below). Defaults to `http://localhost:3000`. |
| `NEXT_PUBLIC_CF_BEACON_TOKEN` | Cloudflare Web Analytics token (dashboard → Web Analytics → add a site). Unset, no script is rendered. |

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. The site deploys to `stage`, then to
`prod` once stage has converged on the same commit; `dev` only verifies. The
Worker is `portfolio-starter-kit-web-<env>` on your account's workers.dev
subdomain, and every deploy is smoke-tested over HTTP. A pull request runs
the same pipeline's verify lanes: the site built and dry-deployed for each
environment, with nothing deployed. They do not lint or run the tests, so
run `pnpm typecheck`, `pnpm lint` and `pnpm test` before you push. (A push
to `main` builds, deploys and smoke-tests.)

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare token and account id are brokered per run from the workspace's
Cloudflare connection; nothing provider-shaped is stored in the repository
or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after rotating a
secret, say. A component with nothing to run in that environment (a test
suite in `prod`) is left out with a notice.

## Custom domain

The site answers on workers.dev from its first deploy. To serve it on your
own domain:

1. Add the domain to the Cloudflare account the site deploys into, and attach
   it to the Worker (dashboard → Workers & Pages →
   `portfolio-starter-kit-web-prod` → Settings → Domains & Routes → Add →
   Custom domain). Do the same for stage with a subdomain if you want one.
2. Set the environment's public origin in `intent.yaml`, so sitemap, RSS,
   Open Graph and JSON-LD links use it (until then they use the workers.dev
   URL):

   ```yaml
   environments:
     prod:
       env:
         SITE_URL: https://portfolio-starter-kit.example.com
   ```

   The site was born with the reserved placeholder
   `portfolio-starter-kit.example.com` where its domain goes: that example,
   and `BASE_DOMAIN` under each environment (dev, stage and prod) in
   `intent.yaml`. Replace it with your domain in the same change.

3. Merge. The next deploy of `apps/web` builds with the new origin. (A change
   to `intent.yaml` alone deploys nothing — touch `apps/web` in the same pull
   request, or let the next change to the site carry it.)
