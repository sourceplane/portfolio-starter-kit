# Spec pack

Status: Normative index

| Tier | Directory | What it holds |
|------|-----------|---------------|
| **Epics** | [`epics/`](./epics/) | The work programs: one epic per capability, each a directory with its `epic.yaml` declaration and the doc set (`README.md`, `design.md`, `implementation-plan.md`, `risks-and-open-questions.md`, `IMPLEMENTATION-STATUS.md`). |
| **Tasks** | [`../tasks/`](../tasks/) | One `TaskContract.yaml` per task key the epics name; the ceiling on what each pull request may touch. |

Ground rule: trust code reality over stale docs. When a spec and the running
system disagree, the system is the source of truth and the spec is the bug.

Status legend: `Draft` → `Ready for implementation` → `In progress` →
✅ `Shipped` · ⛔ `Blocked` · `Closed`.
