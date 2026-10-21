# portfolio-starter-kit — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/portfolio-starter-kit/risks-and-open-questions.md`; this page
lists only what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| PK-G | The one-landing shape (PK5: `01-product` then `03-docs`, first tagged `baseline-v3`) has not been bootstrapped live; `baseline-v2`'s three-landing shape was, on 2026-10-15 | OPEN | One bootstrap from `baseline-v3` against a workspace, with its timings recorded |
| PK-A | `next/og` renders inside the Worker, the one place its CPU and size limits could bite | WATCH (mitigated) | Holds while the image stays small; pre-rendering at build is the fallback |

Accepted, and worth knowing before you change them: PK-D (Speed Insights has
no one-to-one twin), PK-H (a custom domain is the owner's step).
