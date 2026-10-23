# portfolio-starter-kit — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | OpenNext on Workers + Static Assets (`cloudflare-workers-assets-turbo`), the static-assets incremental cache + `populateCache` | The blog-starter port's build shape; the posts, the feed and the sitemap are pre-rendered at build | `specs/epics/portfolio-starter-kit/README.md`, design.md |
| 2 | Posts pre-rendered, `dynamicParams = false`; `/rss` `force-static` | A Worker has no filesystem at request time | risks PK-E, PK-F |
| 3 | `next/og`'s `ImageResponse` runs inside the Worker | The one request-time render; verified under `wrangler dev`, pre-rendering at build is the fallback | risk PK-A |
| 4 | The origin is `NEXT_PUBLIC_SITE_URL`, baked in by the Orun build: the environment's `SITE_URL`, else its workers.dev URL with the subdomain written in the command | The template hard-coded its Vercel origin; the composition exports the subdomain to the smoke step only | IMPLEMENTATION-STATUS, risk PK-I |
| 5 | The Cloudflare Web Analytics beacon, opt-in by token, in place of Vercel's two scripts; Tailwind 4 stable in place of the alpha | Speed Insights has no Cloudflare twin; the template pinned `4.0.0-alpha.13` | risks PK-D, PK-B |
| 6 | No domain phase; a custom domain is the owner's step (`SITE_URL`) | `workers-deploy` has no zone scope, and `dns-edit` needs zone ids a build does not have | risk PK-H, design.md §6 |
| 7 | Three phases, `01-scaffold`, `02-site`, `03-docs` — **superseded by #8** | The first baseline (PK3, `baseline-v1` and `baseline-v2`) | design.md §6 |
| 8 | One landing (`01-product`) then the record (`03-docs`), each bootstrap landing checked by `plan` alone | A landing has a fixed cost (cirrus-baseline since baseline-v22); the convergence on main builds and tests for real (PK5) | IMPLEMENTATION-STATUS (PK5) |
| 9 | stack-tectonic 0.19.0, not 0.20.0, and `checks.yml` on pull requests only | What the first live bootstrap found: Turbopack refuses 0.20.0's lane-shared install; the convergence watch took any workflow's run for the commit | risks PK-J, PK-K |
| 10 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME` (replaced the `ORUN_CI` gate) | A bootstrap cannot set a repository variable | design.md §6 |
| 11 | orun is pinned only where it runs (the `orun-action` `version:` in each workflow); no kiox | `kiox.yaml` pinned a version nothing ran | IMPLEMENTATION-STATUS (PK6) |
| 12 | Component docs are generated from the manifests and checked in CI | A hand-written copy of the dependency graph and bindings drifts silently | `tooling/catalog/gen-component-docs.py` |
| 13 | The workers.dev subdomain is read from the Cloudflare connection (`from: connection.cloudflare.workersSubdomain`), not asked; only a hand-run build passes `--set subdomain` | It belongs to the account like its id and has one right answer; a typed one could only be wrong, and wrong showed up after deploy in the build origin and the probes (cirrus-baseline since baseline-v23) | IMPLEMENTATION-STATUS (PK-8) |
| 14 | The console asks for no domain; an empty `productdomain` brands the placeholder `<reponame>.example.com` | The site goes live on workers.dev and nothing in the build needs a domain (its absolute links use `SITE_URL`, else the workers.dev URL); attaching one is an owner's step, and the placeholder keeps every place the domain goes in the repository, ready to replace | `repo-blueprint.yaml`, `tooling/rebrand/rebrand.mjs`, IMPLEMENTATION-STATUS (PK-9) |
| 15 | Every narration line is written for the console's build panel, which prints it verbatim: true for each outcome its hook can report (found or created, landed or nothing to land), read from outputs where the hook has them; every `await` is `Waiting on {{ .meta.waitingOn }}.` | An `await` line is also what shows while `requires.probe` waits on a provider connection, and a line that is false in one outcome is false in front of the person it was written for | `repo-blueprint.yaml`, IMPLEMENTATION-STATUS (PK-10) |
| 16 | A site ships `AGENTS.md`, from `.baseline/product/AGENTS.md` | The console's hand-off ends `Then clone <repo> and start building on it.`; the agent needs to know what to read first, how a change lands and what not to touch | IMPLEMENTATION-STATUS (PK-10) |
