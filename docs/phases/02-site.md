# 02-site — the site, live

**Places** `apps/web` (the Next.js site, its OpenNext build and its deploy
contract) and `tests/web` (vitest).

**Requires** `01-scaffold` placed, and both connections live — GitHub (the
owner's App installation) and Cloudflare — probed, waited for up to ten
minutes, so the Cloudflare consent can be clicked while it waits.

## What runs

| hook | what it does |
|---|---|
| `task` (pre) | finds the phase's task and yields its key |
| `secret-workers-deploy` (pre) | `orun.integrations/reconcile@v1` — ensures `CLOUDFLARE_API_TOKEN`, brokered from the Cloudflare connection with the `workers-deploy` scope |
| `secret-account-id` (pre) | ensures `CLOUDFLARE_ACCOUNT_ID`, the connection fact |
| `retouch` | the redeploy marker on `apps/web/component.yaml` and `tests/web/component.yaml` (`.baseline/tasks/02-site.TaskContract.yaml`'s `affects`) |
| `stage`, `rebrand`, `restage`, `rebrand-verify` | brands what this phase placed |
| `pnpm-lockfile-seed`, `pnpm-lockfile` | the lockfile from the baseline's complete one, pruned |
| `land` | one PR, merged without waiting on its checks (`wait: false`) — the convergence is the gate |
| `converge` (await) | `orun.run/watch@v1` on the merge commit's run; resumes it up to three times |
| `verify` (await) | `orun.http/probe@v1` on both workers.dev URLs |

## What the convergence does

`orun plan --changed` plans `web` on stage and prod (deploy) and — dev's push
activation being deferred — nothing on dev. Each deploy lane installs the
workspace, builds with `NEXT_PUBLIC_SITE_URL` set to the environment's
`SITE_URL` or its workers.dev URL, checks the build output, deploys
`<reponame>-web-<env>` with `wrangler deploy`, and smoke-tests it: the home
page must carry the nav's `/blog` link and `/rss` must be a feed. Stage and
prod deploy side by side (`01-scaffold` deferred the promotion gate).

## Verified

The convergence run for the merge commit is green, and
`https://<reponame>-web-{stage,prod}.<subdomain>.workers.dev` answer.

## Troubleshooting

| symptom | cause → fix |
|---|---|
| parks on the `providers` probe | Cloudflare is not connected to the workspace. Connect it (console → Integrations → Cloudflare, paste the Account API token) |
| deploy lane: `secret resolution failed … CLOUDFLARE_API_TOKEN` | the reconcile did not run or minted against a revoked connection. Re-connect and re-run the phase; the reconcile re-mints only what is missing |
| deploy lane: Authentication error (10000) | the connection's token lacks Workers Scripts Write. Re-issue it with the permission groups the console's Connect recipe lists |
| smoke fails right after the FIRST deploy | workers.dev route propagation; the composition retries the first deploy and the smoke with backoff (stack-tectonic ≥ 0.19.0). A convergence resume clears what is left |
| `build-app` fails: `Symlink apps/web/node_modules/next is invalid, it points out of the filesystem root` | the site's `intent.yaml` pins stack-tectonic ≥ 0.20.0 (lane-scoped install). Pin 0.19.0 — `intent.yaml`'s comment says why |
| the watch says green, the probe says 404 | another workflow ran on the push and the watch took its run. Only `ci.yml` may run on a push to main |
| re-run lands nothing | the hooks did not run (`--run-hooks`), or the contract names no component — `node tooling/bootstrap/retouch.mjs --check --affects .baseline/tasks/02-site.TaskContract.yaml` in the site's tree says which |
