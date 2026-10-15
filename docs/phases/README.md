# The phases — one blueprint, two selections

`repo-blueprint.yaml` declares two phases that take a site from **nothing**
to **live on stage and prod, documented**: one landing builds the whole site,
one records it. Run them one at a time with
`--phase <name>`, or the whole sequence unattended with `--resume`. There is
no umbrella workflow and no per-phase document: a phase is a selection on one
artifact, which is what makes running one alone, months later, from a fresh
container the same operation as running them all.

Each phase follows the same contract:

> **place its modules → brand them → land them as one pull request → watch
> the convergence that merge triggers (auto-resumed) → verify the outcome
> over HTTP.**

Run from the baseline checkout (the blueprint's source is `path: .`); the
site's repository is wherever `--out` points.

## Execution order

The phase number is the EXECUTION order, and each phase's `requires.phases`
states it in the document: the engine refuses a phase whose predecessor is not
placed, and names it.

Every landing is a pull request on a branch named for its task
(`orun/BASE-<n>-<phase>`). On those branches `ci.yml` runs `plan` only — the
intent, every component and every composition resolve — and skips the lanes,
because the merge runs them on main a minute later, for real, and that
convergence is what the phase watches. `checks.yml` (install, typecheck, lint,
test, build) skips its job on those branches for the same reason — the
convergence builds and tests the site — and runs on every other pull request.
So each landing waits for `plan` alone, a few seconds, and merges.

| phase | lands | verified by |
|---|---|---|
| [`01-product`](01-product.md) | **the GitHub repo created**, then the WHOLE site in one PR: intent, CI, tooling, identity, `apps/web` + `tests/web` — one convergence deploys it to stage and prod side by side | repo workspace-linked, convergence green (build, deploy, smoke) + both URLs answer |
| [`03-docs`](03-docs.md) | the live-deployment record; the promotion gate and dev lanes put back | committed manifest matches probed reality |

There is no custom-domain phase. Attaching a domain to a Worker needs zone
permissions the platform's brokered `workers-deploy` token does not carry, so
it is an owner's step after the bootstrap — the site's README, "Custom
domain", says how, and `SITE_URL` in `intent.yaml` makes the build use it.

## Inputs

`01-product` takes the site's identity once and writes it into the repo
(`.rebrand/values.json`); every later phase reads it back from the placed
tree. But the blueprint's **required** inputs — `reponame`, `productname`,
`productdomain`, `githuborg` — are validated before any phase runs, so they
must be supplied on every invocation, single-phase ones included. A
`--values` file is easier than repeating `--set`.

- `subdomain` — the workers.dev subdomain of the Cloudflare account. It is
  in every URL the phases probe and in the origin the site is built with.
- `orunWorkspace` — workspace id (`ws_…`). Unset, it is the workspace the
  build runs in (`from: workspace`); with none anywhere, a placeholder that
  fails loudly rather than silently claiming another tenant's workspace.
- `epicSlug` (default `portfolio-baselining`) — the epic every phase clubs
  its task under. Found by slug, so a fresh run and a resumed run find the
  same work.
- `repoPrivate` (default `true`) — the repository's visibility at creation.

```bash
orun new --blueprint repo-blueprint.yaml \
  --out $HOME/sites/acme-notes --run-hooks --phase 01-product \
  --values ~/acme-notes.values.yaml
```

Drop `--run-hooks` (or add `--status`) to preview. Without it a phase places
files and stops: no repo, no landing, no convergence watch, and no probe —
which is exactly what makes a dry instantiation of this baseline possible in
CI with no workspace and no provider (`testing/placement.test.sh`,
`testing/e2e.test.sh`).

## What 01-product does after it places

Placement writes the baseline's files as they are here. Before the phase
lands, its `post` hooks make them the site's:

1. `retouch` — one `# orun: redeploy <phase> <stamp>` line
   at the end of each component.yaml its task contract names, so a re-run
   after a failed convergence still has a diff to land and redeploys exactly
   those components.
2. `rebrand` → `rebrand --verify` — the identity rename over the whole tree,
   then a sweep that fails on any of this baseline's identity left behind.
3. `pnpm install --lockfile-only` over the baseline's complete lockfile —
   the whole tree is placed, so it only confirms it and `--frozen-lockfile`
   installs pass.

## When a phase fails

- **Before it lands** (a probe that timed out, a rebrand residue, a refused
  link): nothing was merged. Fix what the message names and re-run the phase.
- **After it lands** (the convergence went red): the files are on main.
  `orun.run/watch@v1` has already resumed the run up to three times. Re-run
  the phase (`--phase 01-product`, `--redo 01-product` under `--resume`, or the
  console's Retry): its `retouch` hook gives the landing a diff and the
  component redeploys.
