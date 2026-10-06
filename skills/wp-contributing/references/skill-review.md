# Skill review — the judgment half of the audit

`tests/checks/skill-authoring.sh` and `tests/checks/frontmatter-yaml.sh` check what a grep can
see: the frontmatter parses, the description has a "Use when" clause, the body is under 500
lines, long references carry a contents list, every reference file and script is named. This
file is what they cannot see. It follows Anthropic's
[skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices),
adapted to this repository. `/wp-contribute review <skill>` hands it to a reviewer with a fresh
context, because the author's own context fills the gaps the written skill leaves.

Read the whole skill directory — SKILL.md, every file under `references/`, the list of
`scripts/` — then go through each rule. Cite a line for every finding.

## The rules

1. **The description finds the skill.** It is the only text Claude reads before choosing among
   every installed skill. It names the concrete things a request would mention (file names,
   commands, plugin names, the project setting that selects it), states what the skill does in
   the third person, and ends with "Use when …". Write three requests that should load it and
   three nearby requests that should not, and judge the description against all six.
2. **Every paragraph earns its tokens.** Cut what Claude already knows: what BEM, a media query
   or WP-CLI is, how a library works in general. Keep the *why* of a non-obvious rule — Claude
   cannot know this project's history, and a rule without its reason gets "simplified" away.
3. **Freedom matches fragility.** Database writes, migrations, secrets, deploys and anything
   with a fixed order get exact commands or a script ("run exactly this"). Judgment work —
   layout, copy, review — gets heuristics and a default, not a script.
4. **One default, not a menu.** "Use X; for case Y use Z" — never a list of equal options.
5. **One term per concept.** List any concept named two ways (field / control, page / post,
   section / block) and pick one.
6. **Examples are concrete and real for this repo.** Input → output pairs where style matters.
   Code uses the `prefix_` placeholder and `${CLAUDE_PLUGIN_ROOT}/…` paths, never a real
   project's slug or a relative plugin path.
7. **Workflows are steps.** A multi-step process is numbered; a long one opens with a checklist
   to copy; where a validator exists, the steps loop — validate, fix, validate again — and say
   when to stop.
8. **Scripts are run, not reimplemented.** Each bundled script says whether to run it (the
   usual case) or read it, with its arguments and exit codes. Scripts handle their own errors
   and carry no unexplained constants. Dependencies are stated, not assumed installed.
9. **Nothing goes stale with the calendar.** No "currently", "as of", "until version N" or
   dated conditionals in the rules. History belongs in an "Old patterns" section or in the
   CHANGELOG.
10. **Progressive disclosure, one level deep.** SKILL.md is the overview an agent needs on every
    run; templates, long samples and catalogs live in `references/`, each named in SKILL.md with
    a "read when" line. A reference never sends the reader on to another reference for the
    content itself.
11. **Skills inform; they never act.** A skill whose body is a procedure an agent executes end
    to end is an action skill: it needs a runner command (`tests/checks/skill-runner-commands.sh`)
    and stays `user-invocable: false`. Anything that should be decided per project reads the
    recorded decision (`i18n strategy`, `demo mode`, `template`, `store.tier`) instead of
    guessing it.
12. **The contract is pinned.** Every rule a later edit could silently drop has a check under
    `tests/checks/` that fails when its wording disappears, in both directions where a wrong old
    form existed.

## Report

Return exactly this, and edit nothing:

```
| # | Level | Rule | Where | Finding | Fix |
|---|-------|------|-------|---------|-----|
| 1 | should | 3 | SKILL.md:42 | "Run the migration" gives no command for a fragile write | Name the script and its flags; say "run exactly" |

Should load:     <three requests>
Should not load: <three requests>
Verdict: PASS | FIX
```

Mark each finding **must** (the skill will not be found, loads wrong, or breaks a house rule —
rules 1, 8, 10, 11, 12) or **should** (the guide's quality rules). The verdict is `FIX` while
any **must** finding stands. An empty table is a valid answer; do not invent findings to fill it.
