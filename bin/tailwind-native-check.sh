#!/usr/bin/env bash
# Validates a Tailwind theme against the tailwind-native CSS convention.
# Usage: bin/tailwind-native-check.sh <theme-dir>
# Safe to run against the starter (uncompiled) or a built theme; the
# markup rule only applies once assets/css/dist/main.css exists.
set -euo pipefail

theme="${1:?usage: tailwind-native-check.sh <theme-dir>}"
# Trailing slashes stripped once, here. Every rule below builds a path as
# "$theme/…" and rule 5 compares one of those against a `grep -rl` result, which
# never carries a double slash — so `./my-theme/` made the sanctioned
# performance.php look like an offender.
while [ "${theme%/}" != "$theme" ] && [ "${theme%/}" != "" ]; do
  theme="${theme%/}"
done
src="$theme/assets/css/src/tailwindcss"
main="$src/main.css"
fail=0

err() { echo "FAIL: $1"; fail=1; }

[ -f "$main" ] || { echo "FAIL: $main not found"; exit 1; }

# Every rule below uses `if`, never `[ … ] && err …` — under `set -e` a false
# test as the last command of a line aborts the script instead of continuing.

# 1. No plain-CSS output file from the basic path.
if [ -f "$theme/assets/css/styles.css" ]; then
  err "assets/css/styles.css exists — that is the template=basic output surface"
fi

# 2. Only the four sanctioned directories, and nothing nested inside them.
# `find`, not a `"$src"/*/` glob, for two reasons. The glob only inspected depth 1, so
# `components/parts/` — a NEW directory in the Tailwind tree, which is precisely what
# this rule exists to forbid — sailed through; and on the common theme whose CSS all
# lives in main.css the glob did not expand at all and the unexpanded pattern was
# reported as a directory literally named `*`. `find` yields nothing when there is
# nothing, and the path it yields is compared WHOLE against the sanctioned set, so a
# nested directory fails on its `base/…` / `components/…` path.
while IFS= read -r d; do
  reldir="${d#"$src"/}"
  case "$reldir" in
    base|components|layouts|utilities) ;;
    *) err "unexpected directory $reldir under $src" ;;
  esac
done < <(find "$src" -mindepth 1 -type d | sort)

# 3. Every .css file has at least one rule, and 4. is imported by main.css.
# Process substitution, not a pipe — a pipe would run the loop in a subshell
# and every `fail=1` would be lost.
while IFS= read -r f; do
  # main.css is the entry point: it imports the others, so it cannot import itself,
  # and the `@import "tailwindcss"` it opens with is a rule. Everything ELSE is
  # judged, at any depth. `-mindepth 2` used to do the exempting, which quietly
  # exempted every .css SIBLING of main.css too — so a comment-only, un-imported
  # `legacy.css` dropped straight into assets/css/src/tailwindcss/ passed both
  # rules, while the identical file one directory down failed both. That is the
  # shape of the five comment-only stubs this branch deleted from the starter, and
  # depth 1 is the easiest place to put one back. Compared as a whole path rather
  # than filtered with `-name main.css`, so a `components/main.css` is still judged.
  if [ "$f" = "$main" ]; then
    continue
  fi
  rel="${f#"$src"/}"
  # Drop comments and whitespace; anything left is a rule. Newlines are folded to
  # spaces FIRST because sed works one line at a time: the single-line-only
  # `s|/\*.*\*/||g` this replaces let every MULTI-line comment stub through, and a
  # header comment written across three lines is the natural way to write one. The
  # BRE is the standard non-greedy C-comment match, so `/* a */ .x{} /* b */` loses
  # both comments and keeps the rule instead of collapsing to nothing.
  body=$(tr '\n' ' ' < "$f" | sed 's|/\*[^*]*\*\+\([^/*][^*]*\*\+\)*/||g' | tr -d '[:space:]')
  if [ -z "$body" ]; then
    err "$rel is empty or comment-only"
  fi
  # Anchor on a REAL import. A plain `grep -Fq "$rel"` matched the path anywhere in
  # main.css, so `/* @import "./components/hero.css"; disabled */` satisfied the rule
  # and the file shipped unbuilt — the exact state this rule exists to catch. The path
  # is regex-escaped before it goes into an ERE so a `.` in a filename cannot match a
  # different character. Ceiling: a line that begins with `@import` INSIDE a multi-line
  # block comment still counts; only the one-line comment shape is excluded.
  rel_re=$(printf '%s' "$rel" | sed 's%[][\\.^$*+?(){}|]%\\&%g')
  if ! grep -Eq "^[[:space:]]*@import[^;]*$rel_re" "$main"; then
    err "$rel has no @import in main.css"
  fi
done < <(find "$src" -mindepth 1 -name '*.css')

# 5. No inline <style> blocks in templates.
#
# One exception, and it is the same category as the sanctioned dynamic `style=""`
# attribute: a `<style>` that sits inside `<noscript>` and is emitted by
# inc/performance.php. That file's deferred-background helper holds each declaration in a
# data attribute and repeats all of them in a `<noscript><style>` block, because the
# fallback has to carry an uploads URL chosen at runtime — a value no build step can know,
# which is exactly why the dynamic style attribute is allowed too. The exception is keyed
# to `<noscript>` on the same line AND to that one file, so a `<style>` block anywhere in
# a template, or a bare one in performance.php, still fails: the rule is about CSS that
# escapes the Tailwind build, and a rule with a wide exception stops being one.
style_files=$(grep -rl '<style' "$theme" --include='*.php' 2>/dev/null || true)
offenders=""
for f in $style_files; do
  case "$f" in
    "$theme"/inc/performance.php)
      # Every `<style` line in this file must also carry `<noscript>`. Counted as
      # the lines that do NOT, rather than by comparing two totals: a single line
      # holding two `<style` occurrences makes `grep -c '<style'` and
      # `grep -c '<noscript>.*<style'` diverge while every block is still inside a
      # <noscript>, and that comparison then failed a file that was correct.
      if [ "$(grep '<style' "$f" | grep -vc '<noscript>' || true)" = "0" ]; then
        continue
      fi
      ;;
  esac
  offenders="$offenders$f "
done
if [ -n "$offenders" ]; then
  err "inline <style> block(s) in: $offenders"
fi

# 6. A compiled theme must actually use utilities in its markup.
# The floor scales to the theme instead of being a fixed 3. A fixed 3 rejected a
# correct TWO-template theme forever, and said "build produced no utilities" about a
# theme where both templates carried them — a message that was simply false.
# `markup` counts the PHP files that carry a literal class attribute at all: that, not
# the raw *.php count, is the set of templates this rule can speak about (functions.php
# and inc/*.php carry no markup, and a template with no class attribute has nothing to
# be Tailwind-native about). The floor is min(3, markup), so the rule is never stricter
# than it was — on a theme of three or more class-carrying templates it is the old
# rule, and on a smaller one it demands utilities in every one of them.
# `|| true` on the pipelines: `set -o pipefail` plus a zero-match `grep` (exit 1) made
# the whole assignment fail, and `set -e` then killed the script with exit 1 and NO
# message — in the worst case of all, a compiled theme with no utilities anywhere.
if [ -f "$theme/assets/css/dist/main.css" ]; then
  markup=$( { grep -rlE 'class="' "$theme" --include='*.php' 2>/dev/null || true; } | wc -l)
  # A utility is a whole class TOKEN, not a substring of one. The first form of this rule
  # was `class="[^"]*(flex|grid|px-|…)`, which matched anywhere inside the attribute — so
  # `services__grid`, `team-archive__grid` and `team-teaser__grid`, the BEM names this
  # repo's own fixtures and starter carry, all counted as Tailwind utilities. A theme in
  # which `wp-css` had written pure BEM — precisely the regression this whole branch exists
  # to catch — passed delivery with rule 6 green. So: an optional variant chain
  # (`md:`, `hover:`, `group-hover:`), then either a bare utility or a prefixed one, then a
  # token boundary. `hero__inner px-4` still counts; `hero__text-block` no longer does.
  # Ceiling, inherent and accepted: a hand-written class that opens with a real utility
  # prefix — `bg-image-holder` — is indistinguishable from a token utility like
  # `bg-brand-dark`. The BEM shapes `block__element` and `block--modifier` are what
  # `wp-css` actually emits, and those are now excluded. Second ceiling, same shape:
  # a bare token with a suffix — `flex-1`, `flex-col`, `grid-cols-3` — only counts when
  # a spaced companion utility sits in the same attribute (`flex flex-col` hits); the
  # door that reopens on letting the bare tokens take suffixes (`block-title` would
  # count) is the worse error, and every converted template carries prefixed utilities
  # (`px-4`, `text-lg`) anyway, so the under-count never rejects a correct theme.
  util_bare='flex|grid|block|hidden|contents|sticky|absolute|relative|fixed|static|truncate|italic|underline|uppercase|container'
  util_pfx='px|py|pt|pb|pl|pr|mx|my|mt|mb|ml|mr|gap|space|text|bg|border|rounded|shadow|font|leading|tracking|w|h|min-w|min-h|max-w|max-h|inset|top|left|right|bottom|z|opacity|items|justify|self|col|row|aspect|object|overflow|cursor|transition|duration|ease|scale|rotate|translate|order|basis|grow|shrink|divide|ring|outline|fill|stroke|list|whitespace|break|align|place|content|antialiased|backdrop|blur|from|via|to'
  util_re="class=\"([^\"]*[[:space:]])?([a-zA-Z0-9_-]+:)*(($util_bare)|($util_pfx)-[a-z0-9[][^[:space:]\"]*)([[:space:]]|\")"
  hits=$( { grep -rlE "$util_re" "$theme" --include='*.php' 2>/dev/null || true; } | wc -l)
  floor="$markup"
  if [ "$floor" -gt 3 ]; then
    floor=3
  fi
  if [ "$markup" -eq 0 ]; then
    err "assets/css/dist/main.css exists but no PHP template carries a class attribute — the build has nothing to style"
  elif [ "$hits" -lt "$floor" ]; then
    err "only $hits of $markup template(s) carrying class attributes use Tailwind utility classes — the rest are still on plain-CSS class names"
  fi
fi

[ "$fail" -eq 0 ] || exit 1
echo PASS
