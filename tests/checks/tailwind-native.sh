#!/usr/bin/env bash
# The __tailwind__ starter must obey the tailwind-native CSS convention:
# no comment-only CSS files, every file imported, no stray directories.
set -euo pipefail

bin/tailwind-native-check.sh starter-theme/__tailwind__ >/dev/null \
  || { echo "FAIL: starter-theme/__tailwind__ violates the tailwind-native convention"; \
       bin/tailwind-native-check.sh starter-theme/__tailwind__ || true; exit 1; }

# A comment-only file must be caught in BOTH comment shapes. The rule's original
# stripper was single-line-only, so the multi-line header — the more natural way to
# write one, and the shape of the five stubs this branch deleted from the starter —
# sailed through. Fixtures are built here rather than asserted on the sed, so a
# future rewrite of the stripper is judged on behaviour.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkfixture() { # mkfixture <name>; body on stdin
  d="$tmp/$1/assets/css/src/tailwindcss/layouts"
  mkdir -p "$d"
  printf '@import "tailwindcss";\n@import "./layouts/header.css";\n.x{color:red}\n' \
    > "$tmp/$1/assets/css/src/tailwindcss/main.css"
  cat > "$d/header.css"
}

mkfixture single_only <<'CSS'
/* Header layout - add rules here. */
CSS
mkfixture multi_only <<'CSS'
/*
 * Header layout - add rules here.
 */
CSS
# The false-fail case: a legitimately documented stylesheet. A stripper that eats
# too much (a greedy `/\*.*\*/`) would reject this and the two-comments line below.
mkfixture multi_plus_rule <<'CSS'
/*
 * Header layout.
 * Owns the sticky bar and the mobile drawer.
 */
.site-header { @apply sticky top-0 z-50; }
CSS
mkfixture two_comments_one_line <<'CSS'
/* lead */ .site-header{color:red} /* trail */
CSS

for name in single_only multi_only; do
  if bin/tailwind-native-check.sh "$tmp/$name" >/dev/null 2>&1; then
    echo "FAIL: a comment-only .css written in the $name shape passes the no-empty-file rule"; exit 1
  fi
done
for name in multi_plus_rule two_comments_one_line; do
  if ! bin/tailwind-native-check.sh "$tmp/$name" >/dev/null 2>&1; then
    echo "FAIL: $name holds a real rule and must pass — the comment stripper is eating the rule with it"
    bin/tailwind-native-check.sh "$tmp/$name" || true; exit 1
  fi
done

# ---------------------------------------------------------------------------
# Directory, @import and utility rules, all judged on BEHAVIOUR: each fixture is the
# `mktheme` baseline plus one deliberate mutation, and the baseline is asserted GREEN
# first — otherwise a fixture could "fail as expected" for a reason that has nothing
# to do with its mutation.
mktheme() { # mktheme <name> — a minimal, correct, COMPILED tailwind theme
  local d="$tmp/$1"
  mkdir -p "$d/assets/css/src/tailwindcss/components" "$d/assets/css/dist" "$d/template-parts"
  printf '@import "tailwindcss";\n@import "./components/hero.css";\n' \
    > "$d/assets/css/src/tailwindcss/main.css"
  printf '.hero { @apply flex items-center; }\n' \
    > "$d/assets/css/src/tailwindcss/components/hero.css"
  printf '/* built */\n.flex{display:flex}\n' > "$d/assets/css/dist/main.css"
  printf '<header class="flex gap-4">x</header>\n'  > "$d/header.php"
  printf '<footer class="px-4 py-2">y</footer>\n'   > "$d/footer.php"
  printf '<main class="grid gap-6">z</main>\n'      > "$d/front-page.php"
  printf '<section class="bg-white px-6">h</section>\n' > "$d/template-parts/section-hero.php"
}
expect_pass() { # expect_pass <name> <why it must stay green>
  if ! bin/tailwind-native-check.sh "$tmp/$1" >/dev/null 2>&1; then
    echo "FAIL: $2"
    bin/tailwind-native-check.sh "$tmp/$1" || true
    exit 1
  fi
}
expect_fail() { # expect_fail <name> <ERE the finding must match> <what must be caught>
  local out
  if out=$(bin/tailwind-native-check.sh "$tmp/$1" 2>&1); then
    echo "FAIL: $3 — the check passed instead"; exit 1
  fi
  # A non-zero exit alone is not proof: an unrelated rule, or `set -e` killing the
  # script with no output at all, would both read as a false confirmation. The ERE
  # names the fixture's own paths/counts, not the wording, so a reworded message
  # still passes.
  if ! printf '%s\n' "$out" | grep -Eq "$2"; then
    echo "FAIL: $3 — it did exit non-zero, but not on that finding. Output was:"
    printf '%s\n' "$out"; exit 1
  fi
}

mktheme ok
expect_pass ok "the baseline fixture theme is correct — every mutation below is judged against it, so a red baseline invalidates all of them"

# The user's binding constraint on this branch: no NEW directory in the Tailwind CSS
# tree, only the four a Tailwind install already makes. The rule used to glob one level
# deep, so a nested directory — the easiest way to create one — was invisible to it.
mktheme nested_dir
mkdir -p "$tmp/nested_dir/assets/css/src/tailwindcss/components/parts"
printf '.x { @apply flex; }\n' > "$tmp/nested_dir/assets/css/src/tailwindcss/components/parts/x.css"
printf '@import "./components/parts/x.css";\n' >> "$tmp/nested_dir/assets/css/src/tailwindcss/main.css"
expect_fail nested_dir 'components/parts' "a new directory NESTED under components/ is still a new directory in the Tailwind tree"

# A directory that is stray at depth 1 must keep failing — the positive control for the
# main_only fixture below.
mktheme stray_dir
mkdir -p "$tmp/stray_dir/assets/css/src/tailwindcss/pages"
printf '.p { @apply flex; }\n' > "$tmp/stray_dir/assets/css/src/tailwindcss/pages/p.css"
printf '@import "./pages/p.css";\n' >> "$tmp/stray_dir/assets/css/src/tailwindcss/main.css"
expect_fail stray_dir 'pages' "a stray top-level directory under the Tailwind tree"

# The common theme: rung 1 of the ladder says most sections write no CSS file at all, so
# everything lives in main.css and there are no subdirectories. The `"$src"/*/` glob did
# not expand there and reported a directory literally named `*`.
mkdir -p "$tmp/main_only/assets/css/src/tailwindcss" "$tmp/main_only/assets/css/dist"
printf '@import "tailwindcss";\n.hero { @apply flex; }\n' \
  > "$tmp/main_only/assets/css/src/tailwindcss/main.css"
printf '/* built */\n' > "$tmp/main_only/assets/css/dist/main.css"
printf '<header class="flex gap-4">x</header>\n' > "$tmp/main_only/header.php"
printf '<footer class="px-4 py-2">y</footer>\n'  > "$tmp/main_only/footer.php"
printf '<main class="grid gap-6">z</main>\n'     > "$tmp/main_only/front-page.php"
expect_pass main_only "a theme whose CSS lives entirely in main.css has no subdirectories at all and must pass — an unexpanded glob must never be reported as a directory named '*'"

# A commented-out @import leaves the file unbuilt, which is exactly the state rule 4
# exists to catch; a substring match on the path was satisfied by the comment itself.
mktheme commented_import
printf '@import "tailwindcss";\n/* @import "./components/hero.css"; disabled for now */\n' \
  > "$tmp/commented_import/assets/css/src/tailwindcss/main.css"
expect_fail commented_import 'hero\.css' "a commented-out @import ships the file unbuilt and must not satisfy the import rule"

# The other half of that widening: real imports come in more shapes than the bare one,
# and none of them may be mistaken for a comment.
mktheme import_shapes
printf '@import "tailwindcss";\n  @import url("./components/hero.css") layer(components);\n' \
  > "$tmp/import_shapes/assets/css/src/tailwindcss/main.css"
expect_pass import_shapes "an indented @import written in the url()+layer() form is a real import and must pass"

# The utility floor scales to the theme. A fixed floor of 3 rejected a correct
# two-template theme permanently, and told it "build produced no utilities" while both
# of its templates carried them.
mkdir -p "$tmp/two_ok/assets/css/src/tailwindcss" "$tmp/two_ok/assets/css/dist"
printf '@import "tailwindcss";\n' > "$tmp/two_ok/assets/css/src/tailwindcss/main.css"
printf '/* built */\n' > "$tmp/two_ok/assets/css/dist/main.css"
printf '<header class="flex gap-4">x</header>\n' > "$tmp/two_ok/header.php"
printf '<footer class="px-4 py-2">y</footer>\n'  > "$tmp/two_ok/footer.php"
expect_pass two_ok "a two-template theme whose templates BOTH carry utilities is correct and must be deliverable"

# …and the small theme is still gated: one converted template out of two is not enough.
\cp -rf "$tmp/two_ok" "$tmp/two_half"
printf '<footer class="site-footer">y</footer>\n' > "$tmp/two_half/footer.php"
expect_fail two_half 'utilit' "a two-template theme with one template still on plain-CSS class names is a half-migrated theme"

# The worst case of all — a compiled theme with no utilities anywhere — used to die on
# `set -e` (`grep`'s zero-match exit 1 through `pipefail`) and print NOTHING. expect_fail
# requires a finding, so a silent exit fails this gate.
mktheme none_at_all
for f in header footer front-page; do
  printf '<div class="site-%s">x</div>\n' "$f" > "$tmp/none_at_all/$f.php"
done
printf '<section class="section-hero">h</section>\n' > "$tmp/none_at_all/template-parts/section-hero.php"
expect_fail none_at_all 'utilit' "a compiled theme whose markup carries no Tailwind utility at all — and it must say so, not exit silently"

# Zero class attributes anywhere is not "0 of 0, floor 0, pass".
mkdir -p "$tmp/no_classes/assets/css/src/tailwindcss" "$tmp/no_classes/assets/css/dist"
printf '@import "tailwindcss";\n' > "$tmp/no_classes/assets/css/src/tailwindcss/main.css"
printf '/* built */\n' > "$tmp/no_classes/assets/css/dist/main.css"
printf '<?php echo esc_html( "x" ); ?>\n' > "$tmp/no_classes/index.php"
expect_fail no_classes 'class attribute|utilit' "a compiled theme whose templates carry no class attribute at all"

# Ceiling: rule 6 only runs on a COMPILED theme, so the uncompiled starter is exempt.
mkdir -p "$tmp/uncompiled/assets/css/src/tailwindcss"
printf '@import "tailwindcss";\n' > "$tmp/uncompiled/assets/css/src/tailwindcss/main.css"
printf '<?php echo esc_html( "x" ); ?>\n' > "$tmp/uncompiled/index.php"
expect_pass uncompiled "with no assets/css/dist/main.css there is no build to judge — rule 6 must stay skipped"

# ---------------------------------------------------------------------------
# Rules 3 and 4 at DEPTH 1 — the siblings of main.css.
#
# `find … -mindepth 2` used to do the main.css exempting, which silently exempted
# every OTHER .css sitting next to it as well: a comment-only, un-imported
# `legacy.css` dropped straight into assets/css/src/tailwindcss/ passed both rules,
# while the identical file one directory down failed both. That is the shape of the
# five comment-only stubs this branch deleted from the starter, and depth 1 is the
# easiest place to put one back. Behavioural, not a grep on the script's source.
mktheme depth1_stub
printf '/*\n * Legacy overrides - add rules here.\n */\n' \
  > "$tmp/depth1_stub/assets/css/src/tailwindcss/legacy.css"
printf '@import "./legacy.css";\n' >> "$tmp/depth1_stub/assets/css/src/tailwindcss/main.css"
expect_fail depth1_stub 'legacy\.css is empty or comment-only' \
  "a comment-only .css sitting NEXT TO main.css is the same stub as one under components/ and must fail rule 3"

mktheme depth1_unimported
printf '.legacy { @apply text-sm; }\n' \
  > "$tmp/depth1_unimported/assets/css/src/tailwindcss/legacy.css"
expect_fail depth1_unimported 'legacy\.css has no @import' \
  "a .css sitting NEXT TO main.css with no @import ships unbuilt exactly as one under components/ does, and must fail rule 4"

# The other half of that widening: a depth-1 sibling that is CORRECT — a real rule and
# a live @import — must pass. A rule tightened until correct work fails just moves the
# false result to the other side.
mktheme depth1_ok
printf '.legacy { @apply text-sm; }\n' > "$tmp/depth1_ok/assets/css/src/tailwindcss/legacy.css"
printf '@import "./legacy.css";\n' >> "$tmp/depth1_ok/assets/css/src/tailwindcss/main.css"
expect_pass depth1_ok "a .css beside main.css that holds a real rule and is really imported is correct — only main.css itself is exempt from rules 3 and 4"

# …and the exemption is the entry point BY PATH, not by filename: a components/main.css
# is an ordinary file and is judged like any other.
mktheme nested_main
printf '/* nothing here yet */\n' > "$tmp/nested_main/assets/css/src/tailwindcss/components/main.css"
printf '@import "./components/main.css";\n' >> "$tmp/nested_main/assets/css/src/tailwindcss/main.css"
expect_fail nested_main 'components/main\.css is empty or comment-only' \
  "components/main.css is not the entry point — exempting it by NAME would leave a comment-only stub anywhere a directory is called main.css"

# ---------------------------------------------------------------------------
# Rules 1 and 5, which had no behavioural fixture at all: both looked correct by
# inspection and neither was judged on what it does.
#
# Rule 1 — assets/css/styles.css is the template=basic output surface. Its presence in
# a Tailwind theme is the wp-css regression this whole branch removes: the theme's
# markup was written for a stylesheet the Tailwind starter never enqueues.
mktheme leftover_styles
mkdir -p "$tmp/leftover_styles/assets/css"
printf '/* ====== Section: Hero ====== */\n.hero { color: red; }\n' \
  > "$tmp/leftover_styles/assets/css/styles.css"
expect_fail leftover_styles 'styles\.css' \
  "a leftover assets/css/styles.css means part of the build fell back to the plain-CSS path"

# Rule 5 — an inline <style> block moves styling out of the Tailwind build entirely,
# where nothing compiles it and nothing can audit it.
mktheme inline_style
printf '<section class="grid gap-6">\n<style>.hero{color:red}</style>\n</section>\n' \
  > "$tmp/inline_style/template-parts/section-hero.php"
expect_fail inline_style '<style' \
  "an inline <style> block in a template is CSS outside the build and must fail rule 5"

# The other half: the skill allows a DYNAMIC style="" attribute driven by an ACF value
# (a background image URL is the standard case). Rule 5 is about `<style` blocks, and a
# widened form that also caught the attribute would fail every correct hero template.
mktheme dynamic_style_attr
printf '<section class="grid gap-6" style="background-image:url(<?php echo esc_url( $bg ); ?>)">h</section>\n' \
  > "$tmp/dynamic_style_attr/template-parts/section-hero.php"
expect_pass dynamic_style_attr "a dynamic style=\"\" attribute fed by an ACF field is the one sanctioned inline style and must not read as a <style> block"

# The second sanctioned form, and the same justification as the attribute above: the
# deferred-background helper in inc/performance.php repeats every held-back declaration
# inside a <noscript><style> block, so a visitor with JavaScript disabled still gets the
# background. The URLs are runtime values, so no build step can carry them.
mktheme noscript_bg_style
mkdir -p "$tmp/noscript_bg_style/inc"
printf '<?php\necho %s<noscript><style>%s . $css . %s</style></noscript>%s;\n' "'" "'" "'" "'" \
  > "$tmp/noscript_bg_style/inc/performance.php"
expect_pass noscript_bg_style "a <noscript><style> block emitted by inc/performance.php is the deferred-background fallback and must not fail rule 5"

# The exception is keyed to <noscript> AND to that file, both halves. A bare <style> block
# in performance.php is CSS outside the build like any other, and widening the exception to
# the whole file would let one in through the back door.
mktheme bare_style_in_perf
mkdir -p "$tmp/bare_style_in_perf/inc"
printf '<?php\necho %s<style>.hero{color:red}</style>%s;\n' "'" "'" \
  > "$tmp/bare_style_in_perf/inc/performance.php"
expect_fail bare_style_in_perf '<style' \
  "a bare <style> block in inc/performance.php is not the noscript fallback and must still fail rule 5"

# Every documented invocation of this script must be rooted at ${CLAUDE_PLUGIN_ROOT}.
# Commands, agents and skills all run with the working directory set to the user's
# WordPress project, where a bare `bin/…` resolves to nothing and exits 127 — the
# delivery gate then silently never runs. Prose that merely NAMES the script is
# backticked, so a backtick straight before `bin/` is exempt. Nothing else is: an
# earlier form of this gate exempted any `/` before `bin/`, which let `./bin/…`
# through — rooted at the CWD, not at the plugin, so the same defect wearing a
# prefix. Only ${CLAUDE_PLUGIN_ROOT}/ counts as rooted, braced or not.
# Ceiling: these filters are line-based, so a single line carrying BOTH a correct
# invocation and a bare one would be exempted. No line in this repo does.
bare=$(grep -rn 'bin/tailwind-native-check\.sh' \
         commands agents skills --include='*.md' 2>/dev/null \
       | grep -v '`bin/tailwind-native-check\.sh' \
       | grep -v 'CLAUDE_PLUGIN_ROOT}\?/bin/tailwind-native-check\.sh' || true)
if [ -n "$bare" ]; then
  echo "FAIL: bare relative invocation(s) of bin/tailwind-native-check.sh — must be \${CLAUDE_PLUGIN_ROOT}/bin/tailwind-native-check.sh:"
  printf '%s\n' "$bare"; exit 1
fi

# /wp-finalize RUNS this script on the tailwind template and fails delivery on it, but
# its printed report listed only the seven numbered checks, so a tailwind theme could be
# finalized with a report that never mentions the one gate this whole path turns on —
# including the "Ready to deliver! All 7 checks passed." line. The report must name it.
# Only the presence is gated, not the arithmetic: the denominator is conditional (6, 7 or
# 8) and asserting a count would false-fail the next time a check is added.
report=$(awk '/^=== WP Finalize Report ===/,/^Result: Ready to deliver/' commands/wp-finalize.md)
if [ -z "$report" ]; then
  echo "FAIL: commands/wp-finalize.md has no '=== WP Finalize Report ===' line — the range below would be empty and the assertion after it would assert nothing"; exit 1
fi
# An awk range whose terminator never matches runs to EOF, so a non-empty result does NOT
# prove the range closed. Assert the terminator is really in there, or a renamed closing
# line silently turns the scan below into a file-wide grep.
if ! printf '%s' "$report" | grep -q '^Result: Ready to deliver'; then
  echo "FAIL: the /wp-finalize report block never closed on its 'Result: Ready to deliver' line; the awk range ran to EOF and the assertion below would degrade to a file-wide grep"; exit 1
fi
if ! printf '%s' "$report" | grep -Eqi 'tailwind convention|convention check'; then
  echo "FAIL: /wp-finalize's printed report never names the Tailwind convention check, so a tailwind theme is reported on without the one gate that decides whether its markup carries any utility classes at all"; exit 1
fi

# Rule 6 counts a template as Tailwind-native by looking for a utility in its class
# attribute. The first form of that grep matched a SUBSTRING — so `services__grid`,
# `team-archive__grid` and `team-teaser__grid`, the BEM names this repo's own fixtures and
# starter carry, all counted as utilities and a pure-BEM compiled theme passed delivery.
# That is exactly the regression this branch exists to catch, waved through by the gate
# meant to catch it. Judged on behaviour: a whole theme of BEM must fail, and the same
# theme wearing utilities must pass.
mktheme bem_only
# Every one of these four BEM names contains a utility SUBSTRING, so the superseded form of
# rule 6 scored this theme 4 of 4 and printed PASS. Keep it that way: a fixture where only
# some of them do would fail the floor for the wrong reason and prove nothing.
printf '<header class="hero__text-block">x</header>\n'            > "$tmp/bem_only/header.php"
printf '<footer class="site-footer__bg-panel">y</footer>\n'       > "$tmp/bem_only/footer.php"
printf '<main class="services__grid">z</main>\n'                  > "$tmp/bem_only/front-page.php"
printf '<section class="team-archive__grid">h</section>\n' > "$tmp/bem_only/template-parts/section-hero.php"
expect_fail bem_only '0 of 4' \
  'a compiled theme whose templates carry only BEM class names is the wp-css regression this branch removes, and rule 6 must not read services__grid as the utility grid'

# The other half of that widening: the variants and arbitrary values a real Tailwind
# template carries must still count. A boundary tightened until correct markup stops
# counting would just move the false result to the other side.
mktheme variants
printf '<header class="site-header sticky top-0 z-50">x</header>\n'      > "$tmp/variants/header.php"
printf '<footer class="bg-white hover:bg-brand px-4">y</footer>\n'       > "$tmp/variants/footer.php"
printf '<main class="grid grid-cols-1 md:grid-cols-3 gap-6">z</main>\n'  > "$tmp/variants/front-page.php"
printf '<section class="hero__inner max-w-[18ch] text-4xl">h</section>\n' > "$tmp/variants/template-parts/section-hero.php"
expect_pass variants 'responsive and state variants (md:, hover:), arbitrary values (max-w-[18ch]) and a BEM block sitting alongside utilities are all correct Tailwind markup and must count'

echo PASS
