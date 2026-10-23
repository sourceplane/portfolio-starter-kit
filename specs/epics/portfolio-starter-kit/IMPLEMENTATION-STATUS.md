# portfolio-starter-kit (PK) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template.

| Milestone | State | PR |
|---|---|---|
| PK0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/portfolio-starter-kit/pull/1) |
| PK1 — the portfolio on Workers | ✅ Shipped | [#2](https://github.com/sourceplane/portfolio-starter-kit/pull/2) |
| PK2 — ready to instantiate | ✅ Shipped | [#3](https://github.com/sourceplane/portfolio-starter-kit/pull/3) |
| PK3 — a baseline | ✅ Shipped | [#4](https://github.com/sourceplane/portfolio-starter-kit/pull/4) (PK-4), tagged `baseline-v1` |
| PK4 — proven live | ✅ Shipped | [#5](https://github.com/sourceplane/portfolio-starter-kit/pull/5) (PK-5), tagged `baseline-v2`; proven by a console bootstrap on 2026-10-15 (below) |
| PK5 — one landing | ✅ Shipped | [#6](https://github.com/sourceplane/portfolio-starter-kit/pull/6) (PK-6), tagged `baseline-v3` — the first tag of the one-landing shape; not yet proven by a live bootstrap (risk PK-G) |
| PK6 — the cirrus standard | ✅ Shipped | [#7](https://github.com/sourceplane/portfolio-starter-kit/pull/7) (PK-7), [#8](https://github.com/sourceplane/portfolio-starter-kit/pull/8) (PK-8), tagged `baseline-v3` |
| PK7 — the domain is set later | ✅ Shipped | [#9](https://github.com/sourceplane/portfolio-starter-kit/pull/9) (PK-9), tagged `baseline-v4` |
| PK8 — the build reads true | ✅ Shipped | [#10](https://github.com/sourceplane/portfolio-starter-kit/pull/10) (PK-10), not yet tagged |

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

### The site's name and source link come from `app/site.ts` (PK3)

`SITE_NAME` replaces the template's two names — "My Portfolio" (heading, Open
Graph, RSS, JSON-LD author) and "Next.js Portfolio Starter" (the default
`<title>` and the `/og` fallback) — with one; `SOURCE_URL` replaces the
repository link in the nav and the footer. They are the seam the baseline's
rename rewrites. The RSS channel title is XML-escaped.

### `apps/web/README.md` is the app's, not the template's (PK3)

The upstream README advertised "Deploy with Vercel" and a Vercel demo, and it
ships into every site. It now describes the app and credits the template (MIT).

## Departures from the port (PK3)

| What | Before | After | Why |
|---|---|---|---|
| `apps/web` build origin | `${WORKERS_DEV_SUBDOMAIN}` | the subdomain literal, behind `${SITE_URL:-…}` | the composition exports the subdomain to the smoke step only (risks PK-I) |
| `apps/web` smoke | `grep 'My Portfolio'` | the nav's `/blog` link, and `/rss` is a feed | the name is the owner's, and HTML-escaped when it carries `&` or `'` |
| `ci.yml` gate | `vars.ORUN_CI == 'true'` | skip only while `intent.yaml` names `ws_CHANGE_ME` | a bootstrap cannot set a repository variable |
| stack-tectonic | 0.18.2 | 0.20.0 | first-deploy retry (0.19.0), one install per lane (0.20.0) — cirrus-baseline's pin |
| orun lane pin | v2.78.0 | v2.78.4 | cirrus-baseline's pin |
| `intent.yaml` | terraform `parameterDefaults`; docs pages under `specs/` | neither; docs pages `ai/context/*` | no terraform component; the pages must exist in a site |
| `tasks/PK-1..3` | no `metadata` | `metadata.name` and `title` | `orun work check` (≥ v2.79) refused them |

## The cirrus standard (PK6)

Nothing about the site changed. What changed is the baseline around it:

| What | Before | After | Why |
|---|---|---|---|
| orun pin | `kiox.yaml` (v2.15.0) + `kiox.lock`, shipped to every site | gone; orun is pinned where it runs, the `orun-action` `version:` in each workflow | nothing ran the kiox pin, and it disagreed with the lanes (v2.78.4) |
| `root-kiox`, `root-kiox-lock` modules | in `01-product` | removed (`testing/phases.test.sh`, the rebrand's skip list and `docs/phases/01-product.md` follow) | a site is placed with 65 − 2 + 6 = 69 files: no kiox, plus the docs below |
| component docs | none | `apps/web/docs/` and `tests/web/docs/` — `overview.md`, `architecture.md`, `runbook.md` | cirrus-baseline documents every component; the workspace Docs library renders `docs/` beside each `component.yaml` |
| how the docs stay true | — | `tooling/catalog/gen-component-docs.py` derives them from the manifest, the Worker config, Terraform, migrations and package scripts; Baseline CI runs it with `--check` | a hand-written copy of a manifest drifts silently |
| context pack | `operations.md`, `deployment.md` | plus `current.md`, `decisions.md`, `open-risks.md` | cirrus-baseline's shape; the three new pages are this repository's own and no module places them (the leak gate still allows exactly two) |
| status | PK5 "in progress, this PR, to be tagged `baseline-v3`"; risk PK-G "no live bootstrap yet", planning the `02-site` merge; no PK4 or PK5 in the plan | PK5 shipped, on `main`, untagged; PK-G says `baseline-v2` went live and the one-landing shape has not; the plan has PK4–PK6 | the documents had not caught up with the tags and the live run |

### The subdomain from the Cloudflare connection (PK-8)

The card's `subdomain` input was typed by hand, though it belongs to the
Cloudflare account the same way its id does and has exactly one right
answer; a wrong value surfaced only after deploy, in the origin the site is
built with (its sitemap, feed and Open Graph links) and `01-product`'s
probes. It now declares `from: connection.cloudflare.workersSubdomain`, as
cirrus-baseline's card does since baseline-v23: the Cloudflare integration
reads the subdomain at connect and on its hourly health check, the bootstrap
door fills the input from the connection the build is bound to (the one
`CLOUDFLARE_ACCOUNT_ID` and the deploy token come from), the console renders
no field for it, and an account with no workers.dev subdomain is refused at
the door. Nothing a site runs changes.

- `blueprint.yaml`: the `from:` source and the reason, at the input; key,
  label, pattern, help and example unchanged.
- `testing/manifest.test.sh`: cirrus-baseline's rule, byte for byte — the
  source is accepted, and a `connection.<provider>.…` source whose provider
  `spec.requires.integrations` does not list fails (the card lists
  `cloudflare`).
- `repo-blueprint.yaml`, `BOOTSTRAP.md`, `docs/phases/README.md`: a console or
  `--from bst_…` build reads it from the connection; only a hand-run build
  passes `--set subdomain`. The default is unchanged.

`baseline-v3` carries this, PK6 and PK5: it is the first tag of the
one-landing shape, so the first bootstrap from it is also the one that
closes PK-G.

Verified:

- `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer}.test.sh`
  green; `gen-component-docs.py --check` green (2 components).
- Mutation: `cloudflare` removed from `spec.requires.integrations` →
  `manifest.test.sh` fails with exactly one finding, `inputs[subdomain].from
  is 'connection.cloudflare.workersSubdomain' but spec.requires.integrations
  does not list cloudflare`; restored, green.
- `orun new --status` (v2.58.11): `01-product` pending (69 files), `03-docs`
  hook-only. `testing/leak.test.sh` (v2.58.11): 69 files derived; ai/context
  still exactly the two declared pages.
- `testing/placement.test.sh` (v2.58.11, as `baseline.yml` runs it): 69
  files placed, both landings, `--resume` changes nothing.
- `orun task check PK-8` complete.

## The domain is set later (PK7, PK-9)

The console asked for the site's domain, with help text that said it did not
need to exist — and nothing in the build needed one. The site answers on
workers.dev from its first deploy. Its sitemap, RSS, Open Graph and JSON-LD
links are absolute, but their origin was never the domain input: it is the
environment's `SITE_URL` in `intent.yaml`, which nothing sets until an owner
does, else the environment's workers.dev URL (`apps/web/component.yaml`'s
`buildCommand`, and the same rule in `hooks/render-deployment-docs.sh`). The
places the repository names the domain are `BASE_DOMAIN` in `intent.yaml`
(dev, stage and prod) and the `SITE_URL` example in the README's "Custom
domain". A domain is an owner's step after the bootstrap, so the form no
longer asks for it.

- `blueprint.yaml` declares no `productdomain` input; the console's Product
  step asks for the site's name alone.
- `repo-blueprint.yaml`'s `productdomain` is optional, default empty. A
  hand-run build may still pass `--set productdomain=` for a site that
  already has its domain. Nothing else in the build reads it: no hook, probe
  or `when:` names it, only the `.rebrand/values.json` template, which
  writes `""`.
- `rebrand.mjs` no longer requires it. Empty, it brands the reserved
  placeholder `<reponame>.example.com` (RFC 2606 — never someone else's
  domain) where the domain goes, so setting it later is replacing one
  string; the product README ("Custom domain", step 2) and
  `ai/context/operations.md` say so.
- The origin logic is unchanged: a site born without a domain builds its
  absolute links on its workers.dev URL, as it always did until `SITE_URL`
  is set — never on the placeholder.
- `testing/fixtures/acme.json` carries no domain, so the leak gate and the
  offline bootstrap exercise exactly what a console build supplies;
  `testing/rebrand.test.sh` pins the placeholder for an absent and an empty
  domain; `baseline.yml`'s blueprint read sets no domain.

Nothing that needs a domain was removed — it waits for one.

Verified:

- `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer}.test.sh`
  green (`rebrand.test.sh`: 25 checks, two of them new — and those two fail
  against the old `rebrand.mjs`); `gen-component-docs.py --check` green (2
  components).
- `orun new --status` (v2.58.11) with no `productdomain`: `01-product`
  pending (69 files). `testing/leak.test.sh` (v2.58.11): 69 files derived;
  ai/context still exactly the two declared pages.
- `testing/placement.test.sh` (v2.58.11, as `baseline.yml` runs it): 69
  files placed, both landings, branded, the site's own `orun plan` green
  (origin, Worker, smoke and secrets the site's own), `--resume` changes
  nothing.
- The offline bootstrap's site, kept and read: `.rebrand/values.json` has
  `"productdomain": ""`; `intent.yaml`'s `BASE_DOMAIN` is
  `acme-portfolio.example.com` in all three environments and sets no
  `SITE_URL`; the README's example and `ai/context/operations.md` name that
  same string (6 lines, 3 files); `rebrand --verify` finds no leftover.
- `orun task check PK-9` complete.

## The build reads true (PK8, PK-10)

orun-cloud's build panel (epic `saas-build-panel`) now prints each hook's
`narrate:` line verbatim as the build's progress and a phase's waiting
line as what it is waiting on, and ends by handing the site to
the person's agent (`…Then clone <repo> and start building on it.`). This is
the baseline's share of that epic's BV4: every line true whenever it is
shown, short, and a site an agent can start in.

| Line | Before | After | Why |
|---|---|---|---|
| `repo` | "The repository exists at `<org>/<repo>`." | `fullName` from the action, "— created for this build" when it was | true for a repository found and one created |
| `land` (both) | "The site is merged into main." / "The deployment record is merged into main." | "PR #`<n>` is merged into main.", or "Nothing new to land; main already has it." | names the pull request, and a re-run that lands nothing no longer claims a merge |
| `link`, `secret-*`, `render`, `epic` | no line | a line each; the secrets' are static (a hook id with `-` cannot be named in a template) | each made something a reader should see |
| `converge` | "…the convergence run came back green." (long) | "The convergence run on main is green: …", or "There is no convergence run on main to watch." | with nothing landed the watch takes main's newest run, or finds none |
| phase `await` (both) | "The site is building and deploying…" / "Probing the live endpoints…" | none authored: the engine writes "`<title>`: `<what it waits on>`" from the waiting event's reason ("`<title>` is waiting." on an engine that carries none) | a waiting event is also what `requires.probe` sends while it waits on a provider connection, when "building" is false, so no fixed sentence is true for every wait |
| phase `start` | 01-product's was 294 characters, with a time estimate | one clause each | the console draws the timing itself |
| phase `done`, `failed` | elapsed time; "the failing lane above names the step"; "the site is still live" | the outcome only; "the step that stopped says why" | a failure in the landing or the link has no lane, and a failed re-probe means the site is not answering |

And, for the engine's facts (orun with saas-build-panel BV3; older orun
ignores both keys): `label: Site` and `label: Docs` on the landings, and
`quiet: true` on 03-docs's re-probe, whose addresses 01-product already
reported.

- `testing/phases.test.sh` still requires `start`, `done` and `failed`, and
  lets a phase leave `await` to the engine.
- **`AGENTS.md`.** A site ships one (`.baseline/product/AGENTS.md`, module
  `root-agents`): what the site is; what to read first (README →
  `ai/context/operations.md` → `ai/context/deployment.md` →
  `apps/web/docs/overview.md` → `apps/web/app/site.ts`); how a change lands
  (desired state, `orun plan --changed`, one task one pull request, the
  merge's run is the deployment); what not to touch. The site's README links
  it, and links Orun at github.com/sourceplane/orun rather than an unrelated
  site. The leak gate requires it and reads it for provenance prose; the
  offline bootstrap checks it is branded and that every page it links exists
  in the site. A site is placed with 70 files.
- **`ignore`.** It kept `.env`, `.env.local` and `.env.*.local` out, but not
  `.env.production`, `.env.development`, `.env.test` or Terraform state:
  `**/.env.[^e]*` (every `.env.<x>` but `.env.example`), `.terraform`,
  `**/*.tfstate` and `**/*.tfstate.*` now do, and the leak gate fails a tree
  that would ship one.
- `testing/manifest.test.sh` no longer names a `domain` input; the inputs
  the card leaves to the build are `productdomain`, `repoPrivate`,
  `orunWorkspace` and `epicSlug`.
- Unchanged, and checked: `expectedMinutes` is 6 on the card, 5 + 1 across
  the phases, and "about six minutes" in its description.

Verified:

- `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer}.test.sh`
  green; `gen-component-docs.py --check` green (2 components).
- `orun new --status` with the CI's inputs at v2.58.11 (the bootstrap
  floor), at orun main and at orun with BV3: `01-product` pending (70
  files), `03-docs` hook-only.
- Every narration line rendered through BV3's own `hookNarration` and
  `renderNarration` over each outcome its hook reports (repository found and
  created, landed and nothing to land, run green and none): each renders, and
  none falls back. Each phase's waiting event, with no line authored, reads
  "`<title>`: `<reason>`" (e.g. "The site, built in one landing: waiting for
  github, cloudflare to be connected in workspace …"), and "`<title>` is
  waiting." when the event carries no reason.
- `testing/leak.test.sh` (v2.58.11, main, BV3): 70 files derived. With a
  canary `.env`, `.env.local`, `.env.production`, `.env.development`,
  `.env.test`, `.env.staging`, `.env.production.local`, `.dev.vars`,
  `.dev.vars.stage`, `terraform.tfstate`, `terraform.tfstate.backup`,
  `.terraform/…` and `terraform.tfstate.d/…/terraform.tfstate` in the
  working tree, none is derived; with the old `ignore` the leak gate fails
  on eight of them.
- `testing/placement.test.sh` (v2.58.11, main, BV3): 70 files placed, both
  landings, `AGENTS.md` branded with every linked page present, the site's
  own `orun plan` green, `--resume` changes nothing. In the bootstrapped
  site, `orun plan --changed` (the command `AGENTS.md` names) plans `web`'s
  verify on dev, stage and prod for a change under `apps/web`.
- `testing/e2e.test.sh` (orun main, and v2.78.4 — the lane pin) green.
- `orun task check PK-10` complete.

## Verified (PK6)

- `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer}.test.sh`
  green; `gen-component-docs.py --check` green (2 components, 6 pages).
- `testing/leak.test.sh` (v2.58.11): 69 files derived (65 − 2 kiox + 6 docs
  pages); ai/context still exactly the two declared pages; nothing of the
  factory, nothing local or built, no provenance prose.
- `testing/placement.test.sh` (v2.58.11, as `baseline.yml` runs it): 69
  files placed, both landings, branded, re-tenanted; the site's own `orun
  plan` for the 01-product merge deploys `web` to stage and prod side by
  side; `--resume` changes nothing.
- `pnpm install --frozen-lockfile`, `wire:fixture`, `typecheck`, `lint`,
  `test` (5 tests, 2 files), `build` green.
- `testing/e2e.test.sh` (v2.78.4) green: the finished site under the Checks
  sequence, the stage lane's planned steps in a staged job tree, `wrangler
  dev` over the built Worker, the component's own smoke, and `/`, `/blog`, a
  post, a 404, `/rss`, `/sitemap.xml`, `/robots.txt` and `/og` on the stage
  origin.
- `orun task check PK-7` complete.

## One landing (PK5)

cirrus-baseline's baseline-v22 builds its whole product in one landing
(`01-product`) and checks each bootstrap pull request with `plan` alone. This
baseline now does the same (PK-6):

| Before (baseline-v2) | Now | Why |
|---|---|---|
| three phases: `01-scaffold`, `02-site`, `03-docs` | two: `01-product` (every module), `03-docs` (hooks only; its name kept, the gap kept, as Cirrus kept `08-docs`) | a landing has a fixed cost (place, PR, checks, merge, convergence start); nothing in the scaffold/site split was order the plan could not carry |
| `01-scaffold` waited on Checks (install, typecheck, lint, test, build) and `plan`; `02-site` merged without waiting (`wait: false`); `03-docs` waited on both | every landing waits on its PR's CI, which on `orun/BASE-…` is `plan` alone: `ci.yml` skips the lanes and `checks.yml` now skips its job | the convergence on main installs, builds, deploys and smoke-tests the site for real, and this baseline's own CI runs the Checks over a bootstrapped tree at the tag being built (e2e); Checks on the PR was the same build twice, and most of each landing's wait |
| the brokered secrets minted in `02-site`'s `pre` | minted in `01-product`'s `post`, after `repo` and `link`, before `land` | the repository exists and is linked before a secret is written for its project — Cirrus's order |
| `02-site` seeded the lockfile from the baseline's, then pruned | `pnpm install --lockfile-only` only confirms the placed lockfile | the whole tree is placed at once, so the complete lockfile is already the right one |
| `.baseline/tasks/01-scaffold`, `02-site` | `.baseline/tasks/01-product` (`affects: [web, web-tests]` — the retouch set) | one landing, one task |
| the offline bootstrap committed one landing per phase from an empty repository | the repository's empty first commit, then one per phase | on the platform the first pull request opens against an empty "Initial commit" by `orun`; it is the base the one landing's push is planned against (`testing/placement.test.sh` §4, `testing/e2e.test.sh` §2) |
| e2e ran the Checks at the scaffold's landing and at the finished site | at the finished site only | there is no scaffold landing, and no landing waits on Checks |

Measured on `baseline-v2` from the console's Build, 2026-10-15
(`portfolio-live`, `bst_R3SZP8S4`): 8m43s end to end — about 1m50s of build
sandbox start, `01-scaffold` 1m5s, `02-site` 4m7s, `03-docs` 1m40s (its
landing waited 52s on Checks). The estimate here is 6 minutes (5 + 1), to be
replaced by the first bootstrap from `baseline-v3`.

## The first live bootstrap (PK4)

`baseline-v1`, registered unlisted, built in workspace
`test-portfolio-starter-kit`: `01-scaffold` landed; `02-site` stopped at its
final probe (404 on both workers.dev URLs). Two findings, both fixed here
(risks PK-J, PK-K):

| Finding | Cause | Fix |
|---|---|---|
| both deploy lanes failed `build-app` | stack-tectonic 0.20.0's lane-scoped install links each job's `node_modules` out of its staged tree; Next 16's Turbopack refuses it | pin stack-tectonic 0.19.0 (the job installs inside its own tree) |
| the watch reported the convergence green | `orun.run/watch@v1` took `checks.yml`'s run for the commit | `checks.yml` on pull requests only; a gate that only `ci.yml` runs on push |
| the tests passed anyway | e2e replayed the lane in a plain checkout | e2e stages the job as orun does (`testing/lib/stage-job.py`), with the planned install layout: red on 0.20.0, green on 0.19.0 |

## Verified (PK3)

- `orun new --status` reads the blueprint at v2.58.11 (the bootstrap floor),
  v2.78.4 (the lane pin) and v2.79.0.
- `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer}.test.sh`
  green; `orun work check` clean.
- `testing/leak.test.sh`: 65 files derived; nothing of the factory, nothing
  local or built; no provenance prose.
- `testing/placement.test.sh` (offline bootstrap, fixture "Sam's Notes &
  Links" / `acme-inc/acme-portfolio`): three landings; rebrand `--verify`
  clean; workspace re-tenanted, `work:` stripped, promotion and dev lanes
  restored; deployment record rendered; the site's own `orun plan` for the
  02-site merge deploys `web` to stage and prod side by side with the site's
  origin, Worker name, smoke and secret refs; `--resume` changes nothing.
- `testing/e2e.test.sh`: the scaffold's landing and the finished site pass
  the Checks sequence; the stage lane's `build-app`, `verify-build-output` and
  `deploy-dry-run` pass; `wrangler dev` serves the built Worker; the
  component's own smoke passes; `/`, `/blog`, a post, a 404, `/rss` (well-formed
  with the escaped name), `/sitemap.xml` (absolute on the stage origin),
  `/robots.txt` and `/og` (PNG) are the site's own.
- Not verified: a live bootstrap against a workspace (risks PK-G).

## Verified (PK1–PK2)

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
