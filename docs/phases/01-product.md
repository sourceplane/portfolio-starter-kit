# 01-product — the site, built in one landing

**Places** the whole tree: the root manifests (`intent.yaml`, `package.json`,
the pnpm workspace and lockfile, `turbo.json`),
`.github/workflows` (`ci.yml` and `checks.yml` — the baseline's own
`baseline.yml` and `tag.yml` are ignored), the shared TypeScript/ESLint
config and the wrangler renderer, the site's README, its `AGENTS.md` (the
page a coding agent starts from) and its two context pages, the identity
file `.rebrand/values.json`, `.gitkeep` files for the four discovery roots,
`apps/web` (the Next.js site, its OpenNext build and its deploy contract)
and `tests/web` (vitest).

**Requires** both connections live — GitHub (the App installation on
`githuborg`) and Cloudflare — probed, waited for up to ten minutes each, so a
consent can be clicked while it waits. The platform sees a pull request only
through the installation on the account that owns the repository, so the
probe runs before anything is created.

## What runs

| hook | what it does |
|---|---|
| `task` (pre) | finds the phase's task (opened by the run-level list) and yields its key |
| `retouch` | the redeploy marker on `apps/web/component.yaml` and `tests/web/component.yaml` (`.baseline/tasks/01-product.TaskContract.yaml`'s `affects`) |
| `git-init`, `git-stage` | the rebrand enumerates with `git ls-files`, so the tree is a staged repo first |
| `rebrand` | renames the baseline's identity to the site's over the whole tree (`tooling/rebrand/rebrand.mjs`) |
| `orun-workspace` | writes the site's workspace into `intent.yaml` (`ws_SET_ME` if there is none — loud, not silent) |
| `work-tree` | removes the baseline's own `work:` block from `intent.yaml` — `specs/` and `tasks/` do not ship |
| `promotion` | defers prod's wait on stage until `03-docs` (both environments deploy side by side) |
| `dev-lanes` | keeps dev's verify lanes off main's convergences until `03-docs` |
| `git-restage`, `rebrand-verify` | refuses the landing if any baseline identity is left |
| `pnpm-lockfile` | confirms the baseline's complete lockfile against the placed tree (a no-op) |
| `repo` | `orun.repo/ensure@v1` — creates `githuborg/reponame` (private unless `repoPrivate=false`) |
| `link` | `orun cloud link` (best effort) then `orun cloud check` — an unlinked repo stops here |
| `secret-workers-deploy` | `orun.integrations/reconcile@v1` — ensures `CLOUDFLARE_API_TOKEN`, brokered from the Cloudflare connection with the `workers-deploy` scope |
| `secret-account-id` | ensures `CLOUDFLARE_ACCOUNT_ID`, the connection fact |
| `land` | one PR, checked by `plan` alone (a bootstrap branch skips the lanes and Checks) and merged on green; its pull request is labelled `Site` in the console |
| `converge` (await) | `orun.run/watch@v1` on the merge commit's run; resumes it up to three times |
| `verify` (await) | `orun.http/probe@v1` on both workers.dev URLs |

## What the convergence does

`orun plan --changed` plans `web` on stage and prod (deploy) and — dev's push
activation being deferred — nothing on dev. Each deploy lane installs the
workspace, builds with `NEXT_PUBLIC_SITE_URL` set to the environment's
`SITE_URL` or its workers.dev URL, checks the build output, deploys
`<reponame>-web-<env>` with `wrangler deploy`, and smoke-tests it: the home
page must carry the nav's `/blog` link and `/rss` must be a feed. Stage and
prod deploy side by side (this phase deferred the promotion gate).

## Verified

The repository exists and is linked to the workspace, the convergence run for
the merge commit is green, and
`https://<reponame>-web-{stage,prod}.<subdomain>.workers.dev` answer.

## Troubleshooting

| symptom | cause → fix |
|---|---|
| parks on `waiting for github for <org>` | the workspace's GitHub connection is to another account. Connect the App installation on `<org>` (console → Integrations → GitHub), then `--resume` |
| parks on the `providers` probe for cloudflare | Cloudflare is not connected to the workspace. Connect it (console → Integrations → Cloudflare, paste the Account API token) |
| `link` fails: `… is not linked to workspace` | the credential cannot write links and the platform has not linked the repo. Allow-list it (console → Settings → Git repos) and re-run the phase |
| `rebrand-verify` lists leftovers | a file carries an identity form no rule renames. Add a rule to `tooling/rebrand/rebrand.mjs` (and a case to `testing/rebrand.test.sh`) |
| `intent.yaml` says `workspace: ws_SET_ME` | `orunWorkspace` was empty and the build ran outside a workspace. Set it and re-run |
| deploy lane: `secret resolution failed … CLOUDFLARE_API_TOKEN` | the reconcile did not run or minted against a revoked connection. Re-connect and re-run the phase; the reconcile re-mints only what is missing |
| deploy lane: Authentication error (10000) | the connection's token lacks Workers Scripts Write. Re-issue it with the permission groups the console's Connect recipe lists |
| smoke fails right after the FIRST deploy | workers.dev route propagation; the composition retries the first deploy and the smoke with backoff (stack-tectonic ≥ 0.19.0). A convergence resume clears what is left |
| `build-app` fails: `Symlink apps/web/node_modules/next is invalid, it points out of the filesystem root` | the site's `intent.yaml` pins stack-tectonic ≥ 0.20.0 (lane-scoped install). Pin 0.19.0 — `intent.yaml`'s comment says why |
| the watch says green, the probe says 404 | another workflow ran on the push and the watch took its run. Only `ci.yml` may run on a push to main |
| re-run lands nothing | the hooks did not run (`--run-hooks`), or the contract names no component — `node tooling/bootstrap/retouch.mjs --check --affects .baseline/tasks/01-product.TaskContract.yaml` in the site's tree says which |
