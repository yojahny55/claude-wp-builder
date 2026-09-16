#!/usr/bin/env bash
# CF7 had no grep gate at all before this check, despite `agents/wp-cf7.md` already
# forbidding utility classes in form markup — a documented rule nothing enforced.
# Three more gaps a real bilingual build's contact section turned up:
#
# 11. An `[acceptance]` tag with no `acceptance_as_validation:on` disables the submit
#     button on an unchecked box, with no error shown anywhere.
# 12. CF7's own wrappers defeat plain sizing: a control needs its OWN width:100% (the
#     wrap alone does not stretch it), the AJAX spinner's default margin caused 20px of
#     horizontal scroll on a phone, and a padding-right loading-state override loses to
#     an @apply px-* utility's logical padding-inline no matter how specific it is.
# 13. The live form is the `_form` post meta; a `cf7/*.html` edit alone reaches nobody,
#     and a fix pushed to one language's post and not the other's is a bilingual bug.
set -euo pipefail
cd "$(dirname "$0")/../.."
f=agents/wp-cf7.md
fail() { echo "FAIL: $*"; exit 1; }

[ -f "$f" ] || fail "$f missing"

# Pre-existing rule, never gated: no utility classes in form markup.
grep -Eiq "never write utility classes into the form|no utility classes" "$f" \
  || fail "$f no longer forbids utility classes in CF7 form markup"
grep -Fq 'contact-form__input' "$f" \
  || fail "$f lost its one-hook-class-per-element example"

# 11. acceptance_as_validation.
grep -Fq 'acceptance_as_validation:on' "$f" \
  || fail "$f does not require acceptance_as_validation:on on [acceptance] tags"

# 12. Control width, spinner containment, padding-inline-end.
grep -Fq 'width: 100%' "$f" \
  || fail "$f does not require width:100% on the control itself"
grep -Eiq 'wpcf7-form-control-wrap' "$f" \
  || fail "$f lost the wrap-vs-control distinction"
grep -Eiq "spinner.*margin|margin.*spinner" "$f" \
  || fail "$f does not address the AJAX spinner's margin causing horizontal scroll"
grep -Fq 'padding-inline-end' "$f" \
  || fail "$f does not require padding-inline-end for the loading-state override"

# 13. _form post meta is the live form.
grep -Fq '_form' "$f" || fail "$f does not name the _form post meta as the live form"
grep -Eiq 'push every language' "$f" \
  || fail "$f does not require pushing every language's form together"

echo PASS
