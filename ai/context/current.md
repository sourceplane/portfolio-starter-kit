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
| Latest tag | `baseline-v3` — PK5, one landing ([#6](https://github.com/sourceplane/portfolio-starter-kit/pull/6), PK-6; the first tag of that shape), and PK6, the cirrus standard (no kiox, generated component docs, this context pack, and the workers.dev subdomain read from the Cloudflare connection instead of asked) |
| Before it | `baseline-v2` (PK4 — proven live); `baseline-v1` is PK3 |
| Proven live | `baseline-v2`: yes — a console bootstrap on 2026-10-15 (`portfolio-live`, `bst_R3SZP8S4`) came up in 8m43s end to end, over three landings. `baseline-v1`'s first live bootstrap stopped at `02-site`'s probe (risks PK-J, PK-K). `baseline-v3`'s one-landing shape: not yet (risk PK-G) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/portfolio-starter-kit/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/portfolio-starter-kit/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/portfolio-starter-kit/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What each component is | `apps/web/docs/`, `tests/web/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one site from `baseline-v3` against a workspace, and record its
   timings against `baseline-v2`'s 8m43s and PK5's 6-minute estimate
   (closes PK-G).
