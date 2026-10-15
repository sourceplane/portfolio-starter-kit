#!/usr/bin/env python3
"""Run one phase's `run:` hooks EXACTLY as repo-blueprint.yaml declares them.

    run-hooks.py <blueprint> <phase> <slot> <tree> <baseline-dir> <values.json> [--skip id,id]

The offline bootstrap (testing/lib/bootstrap.sh) uses this so that what it
exercises is the blueprint's own hook list, not a transcription of it: a hook
added, removed or reordered in the blueprint is added, removed or reordered
here with no edit. Argv templates are rendered the way orun renders them for
the hooks this baseline uses — `{{ .baseline.dir }}`, `{{ .phase.name }}`,
`{{ .inputs.<key> }}` — and anything else left between braces is an error, so
a hook that starts using a template this cannot render fails loudly rather
than running with a literal `{{ … }}` in its argv.

`uses:` hooks are the platform's typed actions (task, repo, land, watch,
probe, reconcile). They need a workspace and the network, and are reported as
skipped; the caller stands in for the ones whose effect the tree needs (a
landing is a commit).
"""
import json
import pathlib
import re
import subprocess
import sys

import yaml


def main() -> int:
    args = sys.argv[1:]
    skip = set()
    if "--skip" in args:
        i = args.index("--skip")
        skip = {s for s in args[i + 1].split(",") if s}
        args = args[:i] + args[i + 2:]
    blueprint, phase_name, slot, tree, baseline_dir, values_path = args
    bp = yaml.safe_load(pathlib.Path(blueprint).read_text())
    phase = next((p for p in bp.get("phases") or [] if p.get("name") == phase_name), None)
    if phase is None:
        print(f"run-hooks: no phase {phase_name!r}", file=sys.stderr)
        return 2
    inputs = {k: v for k, v in json.loads(pathlib.Path(values_path).read_text()).items() if not k.startswith("_")}

    def render(arg: str) -> str:
        out = arg.replace("{{ .baseline.dir }}", baseline_dir).replace("{{ .phase.name }}", phase_name)
        out = re.sub(r"\{\{ \.inputs\.([A-Za-z0-9_]+) \}\}", lambda m: str(inputs.get(m.group(1), "")), out)
        if "{{" in out:
            raise SystemExit(f"run-hooks: cannot render {arg!r} — a template this harness does not know")
        return out

    for hook in ((phase.get("hooks") or {}).get(slot) or []):
        hid = hook.get("id")
        if "uses" in hook:
            print(f"   · {phase_name}/{slot}/{hid}: {hook['uses']} (platform action — skipped offline)")
            continue
        if hid in skip:
            print(f"   · {phase_name}/{slot}/{hid}: skipped by the caller")
            continue
        argv = [render(a) for a in hook.get("run") or []]
        print(f"   ▸ {phase_name}/{slot}/{hid}")
        r = subprocess.run(argv, cwd=tree, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in (r.stdout or "").splitlines()[-6:]:
            print(f"       {line}")
        if r.returncode != 0:
            print(f"run-hooks: {phase_name}/{slot}/{hid} exited {r.returncode}", file=sys.stderr)
            print(r.stdout, file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
