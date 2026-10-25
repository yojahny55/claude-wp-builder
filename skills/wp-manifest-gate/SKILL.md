---
name: wp-manifest-gate
description: The single source for what a command does with each exit code of wp-config.mjs validate, and the named policy that decides what exit 3 (no manifest) means for each command — stop, adopt-or-stop, adopt-or-bare-wp, bare-wp-fallback, scaffold or register. Use when writing or changing the manifest-validation prologue of a command, deciding what a command does on a site with no .wp-create.json, or checking that the commands agree.
user-invocable: false
---

# The manifest gate: exit codes and exit-3 policies

Every command that reads `.wp-create.json` opens with the same validation block, run through
`wp-config.mjs validate`. The block is byte-identical in every command
(`tests/checks/wp-config-gate.sh` diffs it) and its table says what each exit code means. This
skill owns the rest: the one place where **exit `3`** (no manifest) is given a meaning per
command, so eight commands do not each carry their own paragraph that can drift from the others.

A command does not copy a policy. Right after the block it names one in a single line:

```
**Exit `3` policy:** `bare-wp-fallback` — read `${CLAUDE_PLUGIN_ROOT}/skills/wp-manifest-gate/SKILL.md`.
```

Read that file when the validator exits `3`, not before: on exits `0`, `1` and `2` the block's
own table is the whole answer.

## Exit codes of `validate`

| Exit | Meaning | Every command |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | **the policy the command names**, below |

Exit `3` is a stop by default, which is what the table row in the block says. A policy is an
*amendment* to that row, so the command still reads "stop and say so" first and the policy then
widens it; a command that names no policy stops.

## The policies

### `stop` (default)

Say that the project was not created by `/wp-create` and stop. Nothing is written. Use it for a
command that cannot do its job without a manifest.

### `adopt-or-stop`

A site this plugin did not build has no manifest, and working on it is legitimate, not a
misconfiguration. Ask with `AskUserQuestion`:

```
No .wp-create.json: this site was not created by /wp-create.
  [A] Adopt it now — read-only detection, writes .wp-create.json and .claude/CLAUDE.md only (recommended)
  [B] Stop
```

On A, run `${CLAUDE_PLUGIN_ROOT}/commands/wp-adopt.md` Steps 2 to 5 against `${PROJECT_PATH}`, run
the validator again (it must exit `0`) and continue with the adopted manifest. On B, stop. A site
that is only files, with no running WordPress for WP-CLI to probe, cannot be adopted: say so and
stop.

Missing `.claude/CLAUDE.md` follows the same fork, not a blanket "run `/wp-init`": with no manifest
and no WordPress to adopt it is `/wp-init` (a new project); on an existing site it is `/wp-adopt`.
`/wp-init` scaffolds a starter theme and would be the wrong answer for a site that already has
one.

### `adopt-or-bare-wp`

As `adopt-or-stop`, but option B (and a failed adoption) does not stop: take the command's
bare-`wp` fallback. A command that diagnoses a broken site must never make that diagnosis wait on
the site's registration, because a WordPress that does not boot cannot be probed for adoption. Adoption is the right
choice for a Docker, DDEV or Lando site, where bare `wp` reaches the wrong PHP or none at all.
Offer `[A] Adopt it` / `[B] Diagnose without registering`.

### `bare-wp-fallback`

Exit `3` is not a stop: the command targets any WordPress root, not only one created by
`/wp-create`. Do not offer adoption. Continue with the command's own resolution order for the
target root and use a bare `wp --path=<wp-root>` in place of `wp_cli.wrapper`.

### `scaffold`

Exit `3` means "no manifest to read configuration from" and falls through to the command's
"no manifest" branch, which is the legitimate path for a command that creates the project's
files (`/wp-init` on an install that was never run through `/wp-create`).

### `register`

Exit `3` is the one outcome this command continues on: it is the unregistered site the command
exists for. Every other outcome stops: exit `0` or `2` means the site is already registered (say
so; registering never overwrites a manifest and a migration is not its job), and exit `1` is
reported verbatim.

### `destination-adopt` (clone only)

The manifest is missing at the destination because the step before neither created nor adopted
it. Run `${CLAUDE_PLUGIN_ROOT}/commands/wp-adopt.md` Steps 2 to 5 against the destination if it
runs WordPress, then validate again; if it does not, or adoption fails, stop. Never import a
database into a destination the command has no manifest for.

## Which command uses which

| Command | Policy |
|---|---|
| `/wp-audit` | `adopt-or-stop` |
| `/wp-debug` | `adopt-or-bare-wp` |
| `/wp-adopt` | `register` |
| `/wp-init` | `scaffold` |
| `/wp-seed`, `/wp-robin`, `/wp-s3`, `/wp-update` | `bare-wp-fallback` |
| `/wp-clone` (Path A and B, destination) | `destination-adopt` |
| every other gated command | `stop` |

`tests/checks/wp-config-gate.sh` pins the table: a command that keeps its own "Amending the
exit `3` row above" paragraph, or names a policy this file does not define, fails it. To change
what a command does on exit `3`, change its policy name and this file; never re-write the
paragraph in the command.
