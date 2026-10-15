#!/usr/bin/env python3
"""Stage a job's private tree the way orun's runner does.

    stage-job.py <source-tree> <work-dir> [--shared-deps]

orun runs every job of a run in an isolated copy of the source checkout,
`.orun/runs/<exec>/<job>/work` (orun internal/runner/workspace.go,
`materializeTree`). What it does with installed dependencies depends on the
composition the component's lane runs:

  default         the job installs them itself, so `node_modules` is left out
                  at every level and the job's install step recreates it
                  INSIDE the work tree (stack-tectonic < 0.20.0, or a
                  composition with no lane-scoped install);
  --shared-deps   a `scope: lane` install ran once in the source checkout
                  (stack-tectonic >= 0.20.0, orun >= 2.78.2): the TOP-LEVEL
                  `node_modules` is a SYMLINK to the source tree's, and every
                  nested one is COPIED with its pnpm symlinks intact — so they
                  resolve up through that link, OUT of the work tree.

Either way `.git` and `.orun` are left out, and so are build outputs and
caches (.next, .nuxt, .turbo, .svelte-kit, dist, build, target, .venv, venv,
__pycache__, .terraform, .pytest_cache, .mypy_cache).

Why a test builds here rather than in a plain checkout: the first live
bootstrap of this baseline died in the --shared-deps layout — Next.js 16's
Turbopack refuses a dependency that resolves outside its project root
("Symlink … points out of the filesystem root") — in a lane that
testing/e2e.test.sh had run green over a plain checkout.
"""
import os
import shutil
import sys

OUTPUT_DIRS = {".next", ".nuxt", ".turbo", ".svelte-kit", "dist", "build", "target",
               ".venv", "venv", "__pycache__", ".terraform", ".pytest_cache", ".mypy_cache"}
SKIP = {".git", ".orun"}


def stage(src: str, dst: str, top: bool, shared_deps: bool) -> None:
    os.makedirs(dst, exist_ok=True)
    for entry in os.scandir(src):
        name = entry.name
        s, d = entry.path, os.path.join(dst, name)
        if name in SKIP:
            continue
        if entry.is_symlink():
            os.symlink(os.readlink(s), d)
            continue
        if entry.is_dir():
            if name in OUTPUT_DIRS:
                continue
            if name == "node_modules":
                if not shared_deps:
                    continue  # the job installs its own
                if top:
                    os.symlink(os.path.abspath(s), d)  # the lane's one install
                else:
                    shutil.copytree(s, d, symlinks=True)  # copied, links intact
                continue
            stage(s, d, False, shared_deps)
            continue
        shutil.copy2(s, d)


def main() -> int:
    args = sys.argv[1:]
    shared = "--shared-deps" in args
    paths = [a for a in args if a != "--shared-deps"]
    if len(paths) != 2:
        print("usage: stage-job.py <source-tree> <work-dir> [--shared-deps]", file=sys.stderr)
        return 2
    src, dst = (os.path.abspath(p) for p in paths)
    if os.path.exists(dst):
        print(f"stage-job: {dst} exists", file=sys.stderr)
        return 2
    stage(src, dst, True, shared)
    return 0


if __name__ == "__main__":
    sys.exit(main())
