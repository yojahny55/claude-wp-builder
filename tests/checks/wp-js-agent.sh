#!/usr/bin/env bash
# /wp-section had no JavaScript step: a single-section build rendered a carousel that did
# nothing. agents/wp-js.md ports a section's script, and /wp-section Step 6.4 dispatches it.
# This pins the contract that keeps the port safe on a WordPress page: no-op without its
# markup, data- hooks rather than the CSS's classes, guarded lookups, no second copy of a
# module the theme has, no CDN and no npm install, the bundle rebuilt.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

agent=agents/wp-js.md
cmd=commands/wp-section.md
[ -f "$agent" ] || fail "$agent is missing"

grep >/dev/null -c '^name: wp-js$' "$agent" || fail "$agent has no name: wp-js"
grep >/dev/null -c '^model: sonnet$' "$agent" || fail "$agent is not on sonnet"
grep >/dev/null -c '^tools: Read, Write, Edit, Grep, Glob, Bash$' "$agent" || fail "$agent tools are not in the house order"
need_token "$agent" '## First Action (MANDATORY)'
need_token "$agent" 'BLOCKED: <reason>'
need_token "$agent" 'assets/js/src/sections/<slug>.js'
need_token "$agent" '**No-op without its markup.**'
need_token "$agent" '**Hooks are `data-` attributes**'
need_token "$agent" '**Guard every lookup.**'
need_token "$agent" '**Never write a second implementation of a behaviour the theme'
need_token "$agent" 'do not add a CDN `<script>` and do not run `npm install`'
need_token "$agent" 'npm run buildwp'
need_token "$agent" 'prefers-reduced-motion'
need_token "$agent" '`<PREFIX>_data`'

need_token "$cmd" '## Step 6.4: Behaviour (`wp-js`)'
need_token "$cmd" 'Skip this step under `--transcribe`'
need_token "$cmd" 'dispatch **wp-js**'
need_token "$cmd" 'Behaviour: assets/js/src/sections/<slug>.js (wp-js)'
need_token README.md '| `wp-js` |'
need_token BACKLOG.md 'tests/checks/wp-js-agent.sh'

# What the agent relies on in the starter it targets.
starter="starter-theme/__tailwind__"
need_token "$starter/assets/js/src/index.js" 'const startWidgets'
need_token "$starter/package.json" '"buildwp"'
need_token "$starter/functions.php" "wp_localize_script( '__starter__-main', '__STARTER___data'"
echo "PASS: wp-js ports a section's script under a guarded, no-op-without-markup contract, and /wp-section dispatches it"
