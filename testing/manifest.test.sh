#!/usr/bin/env bash
# The manifest must state what THE BLUEPRINT does (saas-bootstrap-console
# BC2/BC3; repointed from the flows by saas-bootstrap-engine BE4).
#
# `blueprint.yaml` is the contract the platform's bootstrap door reads and the
# console renders screen for screen. A manifest that drifts is a console that
# lies — showing an operator secrets that will not be created, or a programme
# that will not be laid out, with nothing failing until a customer's build is
# already running.
#
# Every check compares the manifest to THE THING THAT DOES THE WORK, never to
# another copy of the same claim. `spec.source.tag` sat at `baseline-v1` against
# a live `baseline-v4` for three releases (and `baseline-v17` against
# `baseline-v27` in lumen — ten) because nothing compared it to anything that
# moved. A drift test between two files catches nothing.
#
# ## What the thing that does the work IS, now
#
# It used to be shell: `flows/common/create-secrets.sh`'s `create` calls, and
# the umbrella's `ensure-milestone` lines, grepped out of scripts. BE4 deleted
# those, and the work moved into `repo-blueprint.yaml` — so this file now reads
# the blueprint's own hooks.
#
# That is a STRONGER comparison, not a weaker one. Grepping a shell script for
# `create FOO cloudflare … workers-deploy` matched a line's shape; reading
# `orun.integrations/reconcile@v1`'s `with:` reads the declaration orun actually
# executes. The action's own documentation says as much — "a script walks that
# table calling create for each … it is a reconcile written out longhand, and
# this is the verb it was reaching for".
#
# TWO SHAPES OF REPO, one test. A repo may carry more than one baseline: stratus
# serves both the `stratus` and `stratus-coolify` registry rows from one tree.
# So every `blueprint*.yaml` at the root is checked.
#
# And a baseline need not have every mechanism. Stratus mints no secrets and
# lays out no milestones, so it declares neither block. That is allowed — but
# only BOTH-OR-NEITHER, checked in both directions: if the mechanism exists the
# block must match it, and if the block exists the mechanism must be there to
# realize it. "Absent" is never permission to skip a check silently; it is a
# fact that must agree with the other side.
#
# bash + python3 + PyYAML. No network, no fakes, no credential.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

echo "── blueprint manifests against the blueprint that realizes them"
python3 - "$root" <<'PY'
import pathlib, re, sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required for the manifest contract test (pip install pyyaml)")

root = pathlib.Path(sys.argv[1])
problems = []
def bad(m): problems.append(m)

manifests = sorted(root.glob("blueprint*.yaml"))
if not manifests:
    sys.exit("no blueprint*.yaml at the repo root — this check has gone blind")

# ── what the blueprint actually mints, and what it actually lays out ──────
#
# One read of `repo-blueprint.yaml`, shared across a repo's baselines. A repo
# with no blueprint at the root has no mechanism to compare against, and that
# is a fact the both-or-neither rule below handles rather than a reason to skip.
bp_path = root / "repo-blueprint.yaml"
bp = yaml.safe_load(bp_path.read_text()) if bp_path.exists() else None
bp_phases = (bp or {}).get("phases") or []

def hooks_of(phase):
    """Every hook a phase declares, in the order orun runs them."""
    h = phase.get("hooks") or {}
    if isinstance(h, list):
        return list(h)
    return [x for slot in ("pre", "post", "await") for x in (h.get(slot) or [])]

def uses(phase, action):
    for hook in hooks_of(phase):
        if (hook.get("uses") or "").startswith(action):
            yield hook

# THE SECRETS THE BOOTSTRAP MINTS. `orun.integrations/reconcile@v1` is what
# `create-secrets.sh` was written out longhand as: one connection, one scope
# template, the keys it ensures. Read per key so a hook minting two keys under
# one template is three facts rather than one.
blueprint_secrets = {}
for phase in bp_phases:
    for hook in uses(phase, "orun.integrations/reconcile@v1"):
        w = hook.get("with") or {}
        for key in (w.get("keys") or []):
            blueprint_secrets[key] = (w.get("provider"), w.get("template"))

if bp is not None and not bp_phases:
    bad("repo-blueprint.yaml declares no phases — this check has gone blind")

checked = []
for path in manifests:
    name = path.name
    spec = (yaml.safe_load(path.read_text()) or {}).get("spec") or {}
    def B(m): bad(f"{name}: {m}")

    # ── the field that cannot be true ─────────────────────────────────────
    if "tag" in (spec.get("source") or {}):
        B("spec.source.tag is back. The registry pins the tag; this file is fetched at it.")

    # ── blocks every baseline must carry ──────────────────────────────────
    for key in ("source", "overview", "requires", "inputs", "bootstrap"):
        if key not in spec:
            B(f"spec.{key} is missing — the console renders it")

    # ── inputs v3: every input is collected by the console (BE3) ──────────
    #
    # `askedBy` is gone with the agent. It split inputs into ones a form
    # collects and ones asked for in a session, and the second half no longer
    # exists — so the field could only ever hold one value.
    #
    # The exemption it carried is what these checks replace: an `askedBy:
    # agent` input needed no `pattern`, because prose asked for it and prose
    # does not validate.
    input_keys = {f.get("key") for f in (spec.get("inputs") or [])}
    ACTION_ID = re.compile(r"^[a-z][a-z0-9.]*/[a-z][a-z0-9-]*@v[0-9]+$")
    REBRAND = "tooling/rebrand/rebrand.mjs"
    # THE KEY CHARSET THE PLATFORM'S PARSER ENFORCES, mirrored here.
    #
    # `INPUT_KEY_RE = /^[a-z][a-z0-9_]{0,38}$/` in orun-cloud's
    # `blueprint-manifest.ts`. Nothing in this repository ran that parser: the
    # `blueprint-parses` job reads `repo-blueprint.yaml` with ORUN, which
    # accepts camelCase happily, and this file is a hand-rolled reader of the
    # card. So a card key orun likes and the platform refuses passed every
    # check here and failed at the pin:
    #
    #     line 98: input key "githubOrg" must be lowercase letters, digits
    #              and underscores
    #
    # It cost a baseline tag — v6 was already cut and a baseline tag is never
    # moved — which is the whole argument for mirroring the rule rather than
    # trusting that the two readers agree.
    #
    # It also constrains `repo-blueprint.yaml`: a card key must be an input the
    # blueprint accepts (checked below), so any input the CARD declares must be
    # named in this charset on BOTH sides. The blueprint's own camelCase
    # inputs — `epicSlug`, `orunWorkspace`, `pascalName` — are untouched,
    # because the card does not declare them.
    INPUT_KEY = re.compile(r"^[a-z][a-z0-9_]{0,38}$")
    for i, field in enumerate(spec.get("inputs") or []):
        key = field.get("key", f"#{i}")
        if not INPUT_KEY.match(str(key)):
            B(f"inputs[{key}] is not a key the platform's parser accepts — it "
              f"must match ^[a-z][a-z0-9_]{{0,38}}$ (lowercase letters, digits "
              f"and underscores). The console would refuse the whole manifest.")
        if "askedBy" in field:
            B(f"inputs[{key}] declares askedBy — there is no agent to ask, so "
              f"every input is collected by the console")
        if not field.get("pattern"):
            B(f"inputs[{key}] declares no pattern — it is collected in a form "
              f"and validated before Continue, so it must say what a valid "
              f"value looks like")

        # from / derive / probe each answer "where does this value come from
        # when nobody types it". Two of them is two answers.
        sources = [k for k in ("from", "derive", "probe") if k in field]
        if len(sources) > 1:
            B(f"inputs[{key}] declares {' and '.join(sources)} — an input has "
              f"one source")

        # A derivation must name inputs this manifest actually declares.
        derive = field.get("derive")
        if derive is not None:
            refs = re.findall(r"\{([a-z][a-z0-9_]*)\}", derive)
            if not refs:
                B(f"inputs[{key}].derive has no {{key}} reference — a constant "
                  f"is a default, not a derivation")
            for ref in refs:
                if ref == key:
                    B(f"inputs[{key}].derive references itself")
                elif ref not in input_keys:
                    B(f"inputs[{key}].derive references {{{ref}}}, which is not "
                      f"a declared input")

        # A DERIVATION HAS A SECOND IMPLEMENTATION, and they must agree.
        #
        # `rebrand.mjs` has computed this value since long before the manifest
        # could say so:
        #
        #     const apibaseurl = values.apibaseurl ?? `https://api.${productdomain}`;
        #
        # Both paths are live. The console resolves `derive` and the flow hands
        # it down, so on a console bootstrap the manifest's rule wins; a phase
        # run by hand passes nothing and rebrand's fallback wins. One rule, two
        # implementations — which is the thing this file's header warns about,
        # unless something holds them equal. This does.
        if derive is not None and (root / REBRAND).exists():
            js = (root / REBRAND).read_text(errors="replace")
            for m in re.finditer(r"const (\w+) = values\.\w+ \?\? `([^`]+)`", js):
                # `${productdomain}` there is `{productdomain}` here.
                want = re.sub(r"\$\{([A-Za-z]+)\}", lambda g: "{" + g.group(1).lower() + "}", m.group(2))
                if m.group(1).lower() == key and want != derive:
                    B(f"inputs[{key}].derive is {derive!r} and {REBRAND} falls back "
                      f"to {want!r} — one value, two rules, and which one a "
                      f"product gets depends on whether the console resolved it")

        # A probe names an orun action. Shape only — this repository does not
        # own the registry and cannot know which ids a runner has. The id being
        # WELL-FORMED is what it can check; whether it is REGISTERED is the
        # runner's answer, at parse time, where the real list lives.
        probe = field.get("probe")
        if probe is not None:
            uses = (probe or {}).get("uses")
            if not uses or not ACTION_ID.match(uses):
                B(f"inputs[{key}].probe.uses is {uses!r} — not an action id "
                  f"(<namespace>/<verb>@v<major>)")

        # `from` says the CONSOLE already holds this value, so it renders no
        # field for it (saas-bootstrap-console BC-K5). Two ways to get it
        # wrong, and the platform refuses both — check them here too, so the
        # mistake is caught in this repo rather than at a live bootstrap.
        #
        # A `connection.<provider>.<fact>` source is read from the connection
        # the build is bound to, so the provider must be one the manifest
        # requires — the platform's parser refuses it otherwise.
        sources_known = ("repo.name", "repo.owner", "repo.fullName",
                         "connection.cloudflare.workersSubdomain")
        src = field.get("from")
        if src is not None and src not in sources_known:
            B(f"inputs[{key}].from is {src!r} — must be one of {', '.join(sources_known)}")
        if isinstance(src, str) and src.startswith("connection."):
            provider = src.split(".")[1]
            if provider not in ((spec.get("requires") or {}).get("integrations") or []):
                B(f"inputs[{key}].from is {src!r} but spec.requires.integrations "
                  f"does not list {provider} — there is no connection to read it from")

    # ── secrets: BOTH or NEITHER, checked both ways ───────────────────────
    declared = {s.get("key"): (s.get("provider"), s.get("template")) for s in (spec.get("secrets") or [])}
    if bp is None:
        if declared:
            B(f"declares {len(declared)} secret(s) but the repo has no "
              f"repo-blueprint.yaml to mint them")
    elif not blueprint_secrets:
        if declared:
            B(f"declares {len(declared)} secret(s) and repo-blueprint.yaml has no "
              f"orun.integrations/reconcile@v1 hook to mint any")
    else:
        if "secrets" not in spec:
            B("repo-blueprint.yaml mints keys and the manifest declares no secrets")
        for k in sorted(set(blueprint_secrets) - set(declared)):
            B(f"repo-blueprint.yaml mints {k} and the manifest does not declare it")
        for k in sorted(set(declared) - set(blueprint_secrets)):
            B(f"declares secret {k} and repo-blueprint.yaml never mints it")
        for k in sorted(set(blueprint_secrets) & set(declared)):
            if blueprint_secrets[k] != declared[k]:
                B(f"{k}: manifest says provider/template {declared[k]}, "
                  f"repo-blueprint.yaml mints it as {blueprint_secrets[k]}")

    # ── bootstrap: what is left of it, and what BE4 removed ───────────────
    #
    # `umbrella` and `agentBrief` named two files BE4 deleted. orun-cloud
    # BE-K1c made both OPTIONAL in the manifest contract for exactly this, so
    # this file no longer declares them — and must not, because a path that
    # does not exist is the drift this whole test is about.
    boot = spec.get("bootstrap") or {}
    for field in ("umbrella", "agentBrief"):
        rel = boot.get(field)
        if rel is None:
            continue
        B(f"bootstrap.{field} is back, naming {rel}. The shell layer is gone "
          f"(BE4): every phase is declared in repo-blueprint.yaml and orun runs "
          f"it, so there is no umbrella to name and no session to brief.")
    if not boot.get("expectedMinutes"):
        B("bootstrap.expectedMinutes is missing — the console renders it")

    # ── …and what BE-K1e added in their place ─────────────────────────────
    #
    # With no umbrella and no brief, `blueprint` is the ONLY entry point: it
    # names the document whose phases a runner places after fetching this repo
    # at its pinned tag. The registry row's `manifestPath` names the console
    # CARD — this file — so without this key a runner has nothing to run.
    #
    # Checked the way everything else here is checked: against the thing that
    # does the work, not against another copy of the claim. The file must
    # exist, and it must be the one that actually declares the phases — a path
    # to some other YAML would satisfy a mere existence check and fail a real
    # bootstrap at the only moment that matters.
    build = boot.get("blueprint")
    if not build:
        B("bootstrap.blueprint is missing. This baseline has no umbrella and "
          "no agentBrief (BE4), so nothing else names the document a runner "
          "places — a fetch at the pinned tag would find no entry point.")
    else:
        target = root / build
        if not target.is_file():
            B(f"bootstrap.blueprint names {build}, which does not exist")
        else:
            try:
                doc = yaml.safe_load(target.read_text()) or {}
            except yaml.YAMLError as exc:
                doc = {}
                B(f"bootstrap.blueprint names {build}, which does not parse: {exc}")
            if doc and not (doc.get("phases") or (doc.get("spec") or {}).get("phases")):
                B(f"bootstrap.blueprint names {build}, which declares no phases. "
                  f"A runner would fetch it and place nothing.")
            if doc and doc.get("kind") != "Blueprint":
                B(f"bootstrap.blueprint names {build}, whose kind is "
                  f"{doc.get('kind')!r} rather than Blueprint")

    # ── every declared input is one the BLUEPRINT accepts ─────────────────
    #
    # This used to check the manifest's keys against the UMBRELLA's inputs,
    # because a flow was what consumed them and orun's flow engine fails closed
    # on an undeclared `--set`. The blueprint is what consumes them now, and it
    # fails closed the same way:
    #
    #     ✕ unknown input "reponame" (not declared in blueprint inputs)
    #
    # That equivalence is why open question 10 had to be settled in the same
    # commit that deleted the flows: the umbrella's lowercase input names were
    # the ONLY thing translating this file's keys into the blueprint's
    # camelCase ones, so deleting it without renaming would have left every key
    # refused.
    #
    # ONE DIRECTION ONLY. The blueprint declares more than this file does —
    # `githuborg`, `epicSlug`, `domain`, `orunWorkspace` and the identity
    # defaults are how a BUILD is driven, not what a product is configured
    # with. What must hold is that nothing this file declares arrives at an
    # engine that cannot take it.
    if bp is not None:
        bp_inputs = set((bp.get("inputs") or {}).keys())
        if not bp_inputs:
            B("repo-blueprint.yaml declares no inputs — this check has gone blind")
        for key in [f.get("key") for f in (spec.get("inputs") or [])]:
            if key and key not in bp_inputs:
                B(f"inputs[{key}] is not an input of repo-blueprint.yaml — the "
                  f"console would resolve it and the engine would refuse it "
                  f"(orun fails closed on an undeclared --set)")

    # ── …AND THE OTHER DIRECTION, for REQUIRED inputs only ───────────────
    #
    # The check above is one-directional on purpose: the blueprint declares
    # more than this card does, because `epicSlug`, `domain` and the identity
    # defaults are how a BUILD is driven rather than what a product is
    # configured with. That tolerance had no floor, and `githuborg` fell
    # through it — `required: true` in the blueprint, absent from this card,
    # so a platform build resolved the card's inputs, handed them to the
    # runner and died on its first step:
    #
    #     ✕ input "githuborg" is required
    #
    # An input the blueprint REQUIRES and gives no default to is one somebody
    # must supply, and the only things that supply inputs to a hosted build
    # are this card's fields and its `from`/`derive` sources. So "more" may
    # not include one of those.
    #
    # Defaulted inputs stay out of it: a default IS the supply.
    if bp is not None:
        for key, spec_in in (bp.get("inputs") or {}).items():
            if not isinstance(spec_in, dict):
                continue
            if not spec_in.get("required"):
                continue
            if "default" in spec_in:
                continue
            if key not in input_keys:
                B(f"repo-blueprint.yaml requires input {key!r} and gives it no "
                  f"default, and this card does not declare it — a hosted build "
                  f"would collect every field it shows and still die with "
                  f'\'input "{key}" is required\'')

    # ── programme: BOTH or NEITHER, against the blueprint's own hooks ─────
    #
    # A milestone is what a phase CLUBS ITS TASK UNDER, which the phase states
    # as `orun.task/ensure@v1`'s `milestone:`, which is why a phase that is
    # the second landing of one unit of work would name its predecessor's
    # milestone rather than one of its own (`04-workers-restore` did, before
    # the bootstrap folded it into `05-edge`).
    #
    # Distinct, in phase order. The old check grepped the umbrella's
    # `ensure-milestone` lines for the same list.
    ensured, seen = [], set()
    for phase in bp_phases:
        for hook in uses(phase, "orun.task/ensure@v1"):
            # Not `name`: that is the manifest's file name, which the summary
            # line below prints (it printed the last milestone instead).
            ms_name = ((hook.get("with") or {}).get("milestone") or "")
            ms_name = ms_name.replace("{{ .phase.name }}", phase.get("name", "")).strip()
            if ms_name and ms_name not in seen:
                seen.add(ms_name)
                ensured.append(ms_name)

    # A phase's `when:` is what made a milestone conditional; the umbrella
    # carried the same fact as a shell `[ != "true" ] ||` guard.
    conditional = {
        p_["name"] for p_ in bp_phases
        if p_.get("when") and p_.get("name") in seen
    }

    prog = spec.get("programme")
    if not ensured:
        if prog:
            B("declares a programme but repo-blueprint.yaml opens no milestones")
    else:
        if not prog:
            B(f"repo-blueprint.yaml opens {len(ensured)} milestone(s) and the "
              f"manifest declares no programme")
        else:
            ms = prog.get("milestones") or []
            if any(not isinstance(m, dict) or "name" not in m for m in ms):
                B("every programme.milestones entry must be a mapping with a `name` "
                  "(so a conditional one can carry its `when`)")
            else:
                names = [m["name"] for m in ms]
                dcond = {m["name"] for m in ms if m.get("when")}
                if names != ensured:
                    B(f"programme.milestones {names} != repo-blueprint.yaml's {ensured}")
                if dcond != conditional:
                    B(f"conditional milestones disagree: manifest says {sorted(dcond) or '[]'}, "
                      f"the blueprint guards {sorted(conditional) or '[]'}")
            slug = ((bp.get("inputs") or {}).get("epicSlug") or {}).get("default")
            if slug and prog.get("epicSlug") != slug:
                B(f"programme.epicSlug {prog.get('epicSlug')!r} != the blueprint's "
                  f"default {slug!r}")

    # ── verify is optional, but must not name an input that is not there ──
    input_keys = {f.get("key") for f in (spec.get("inputs") or [])} | {"env"}
    for url in ((spec.get("verify") or {}).get("urls") or []):
        for ph in re.findall(r"\{([a-zA-Z0-9_]+)\}", url):
            if ph not in input_keys:
                B(f"verify url interpolates {{{ph}}}, which is not an input")

    checked.append((name, len(declared), len((prog or {}).get("milestones") or [])))

if problems:
    print("FAIL: a manifest and the blueprint disagree:", file=sys.stderr)
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    sys.exit(1)

for name, ns, nm in checked:
    print(f"   {name}: {ns} secret(s), {nm} milestone(s) agree with repo-blueprint.yaml")
PY

echo "manifest.test.sh: ok"
