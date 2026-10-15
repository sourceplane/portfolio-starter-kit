# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`portfolio-starter-kit/`](./portfolio-starter-kit/) | **PK** | 🟡 PK5 in progress | Vercel's Portfolio Blog Starter, equivalent in code and function, running on Cloudflare Workers + Static Assets via OpenNext — and an Orun baseline that instantiates it (PK3), proven by a live bootstrap (PK4) |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
