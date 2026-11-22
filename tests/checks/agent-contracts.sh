#!/usr/bin/env bash
# Agent contracts: First Action everywhere but the documented exceptions, a BLOCKED line in the
# agents that read the project file, writer notes on the two installers, FAQ and GSAP wording.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
inc() { grep >/dev/null -c -F -- "$2" "$1" || fail "$1 lacks: $2"; }
grep_count() { grep -c -F -- "$2" "$1" || true; }

# First Action: every agent, except the documented list (each says so in its own text).
EXCEPTIONS=" wp-context wp-normalize "
for f in agents/*.md; do
  n=$(basename "$f" .md)
  if [[ "$EXCEPTIONS" == *" $n "* ]]; then
    inc "$f" 'First Action exception'
  else
    inc "$f" '## First Action (MANDATORY)'
  fi
done

# BLOCKED line in the agents that read the project file or tokens.
for n in wp-template wp-css wp-acf wp-cf7 wp-cinematic wp-tailwind \
         wp-audit-a11y wp-audit-seo wp-audit-geo wp-audit-performance wp-audit-practices; do
  inc "agents/$n.md" 'BLOCKED: <reason>'
done
for n in wp-audit-a11y wp-audit-seo wp-audit-geo wp-audit-performance wp-audit-practices; do
  inc "agents/$n.md" '"blocked": "<reason>"'
done
inc agents/wp-tailwind.md 'Demo Conversion Mode'
inc agents/wp-tailwind.md 'Its absence is not a'

# Conventions documented once.
c=skills/wp-contributing/SKILL.md
for t in '### Agent contracts' 'BLOCKED: <reason>' 'wp-context' 'wp-normalize' 'wp-audit-aios' 'wp-audit-rankmath' 'do not rename them'; do
  inc "$c" "$t"
done
for n in wp-audit-aios wp-audit-rankmath; do inc "agents/$n.md" 'This agent writes.'; done

# FAQ schema: visible Q&A only, no rich-result promise.
inc agents/wp-audit-rankmath.md 'visible in its rendered'
inc agents/wp-audit-rankmath.md 'no one should expect a rich result'
inc skills/wp-audit-seo-standards/SKILL.md 'visible in the rendered'
inc skills/wp-audit-seo-standards/SKILL.md 'do not promise a rich result'

# GSAP provenance and license pointer.
inc skills/wp-demo-craft/references/devices.md 'Where GSAP comes from, and its license'
inc skills/wp-demo-craft/references/devices.md 'https://gsap.com/licensing'
echo PASS
