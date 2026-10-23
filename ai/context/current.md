# portfolio-starter-kit — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a site built from it; the
two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Vercel's Portfolio Blog Starter — MDX posts, an RSS feed, a sitemap, JSON-LD
and dynamic Open Graph images — on Cloudflare Workers + Static Assets
(`@opennextjs/cloudflare`), packaged as an Orun baseline: `orun new
--blueprint repo-blueprint.yaml` builds a new site in its own repository and
takes it to live on stage and prod in one landing (`01-product`), then
records what went live (`03-docs`). One component, no infra.

## Release

| | |
|---|---|
| Latest tag | `baseline-v4` — PK7, the domain is set later ([#9](https://github.com/sourceplane/portfolio-starter-kit/pull/9), PK-9: the console asks for no domain, and a site is born with the placeholder `<reponame>.example.com` for an owner to replace) |
| On `main`, untagged | PK8, the build reads true ([#10](https://github.com/sourceplane/portfolio-starter-kit/pull/10), PK-10: every line the console's build panel prints is short and true, the landings are labelled, and a site ships an `AGENTS.md` for the agent the console hands it to) |
| Before it | `baseline-v3` — PK5, one landing ([#6](https://github.com/sourceplane/portfolio-starter-kit/pull/6), PK-6; the first tag of that shape), and PK6, the cirrus standard (no kiox, generated component docs, this context pack, and the workers.dev subdomain read from the Cloudflare connection instead of asked) |
| Before them | `baseline-v2` (PK4 — proven live); `baseline-v1` is PK3 |
| Proven live | `baseline-v2`: yes — a console bootstrap on 2026-10-15 (`portfolio-live`, `bst_R3SZP8S4`) came up in 8m43s end to end, over three landings. `baseline-v1`'s first live bootstrap stopped at `02-site`'s probe (risks PK-J, PK-K). The one-landing shape (`baseline-v3`, `baseline-v4`): not yet (risk PK-G) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/portfolio-starter-kit/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/portfolio-starter-kit/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/portfolio-starter-kit/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What each component is | `apps/web/docs/`, `tests/web/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |
| What a site's agent reads first | `.baseline/product/AGENTS.md` (ships as the site's `AGENTS.md`) |

## Next

1. Cut the next tag from `main` (PK8) and bootstrap one site from it
   against a workspace: read the console's panel line by line against what
   the build did, and record its timings against `baseline-v2`'s 8m43s and
   PK5's 6-minute estimate (closes PK-G). The landings' labels and the
   docs re-probe's `quiet` take effect with the orun release that carries
   orun-cloud saas-build-panel BV3; an older orun ignores them.
