# /wp-finalize — Check 2: Bilingual Coverage

`commands/wp-finalize.md` sends the run here at Check 2: Bilingual Coverage. Follow it in order; nothing in it is optional background.

Branch on the project's `i18n strategy` (read it from `.claude/CLAUDE.md`):

1. **Field files check — `suffix` only.** Under `suffix`, glob `fields/*.php`,
   and for each file search for field names ending in `_en`. Verify corresponding
   `_es` (or other language) variants exist. Under `polylang`, skip this item:
   field files carry ONE set of fields with no `_<lang>` duplicates (one post
   per language carries its own values), so there are no `_es` variants to
   verify — running it would fail every correct Polylang project.

2. **Template helper check — both strategies.** Search all template `.php` files for `get_field(` calls that are NOT wrapped in `prefix_get_field()`. The raw `get_field()` bypasses bilingual logic.
   - Search pattern: `get_field\(` but NOT `prefix_get_field\(`
   - Exclude: files in `vendor/`, `node_modules/`, `inc/i18n.php` (the helper itself)

3. **Translation coverage — `polylang` only.** Under `polylang`, bilingual
   coverage means every page has a counterpart per language, which is
   `/wp-polylang`'s contract, not a field-suffix one. Run the same verifier the
   retrofit runs, and treat a non-zero exit exactly like the demo-parity gate —
   report it and stop rather than declaring the delivery finished:

   ```bash
   $WP eval-file ${CLAUDE_PLUGIN_ROOT}/skills/wp-polylang/scripts/pll-verify.php <primary_lang> <secondary_lang>
   ```

4. **Every `t()` / `e()` key resolves — both strategies.** The helper's last
   fallback is to return the key itself, so an undefined key does not error: it
   **prints its own name on the page**, in both languages, and looks like content
   nobody wrote. A real delivery shipped six of them, one of which put
   `contact_map_office` on the contact page.

   Collect every key the templates call and diff it against the ones `inc/i18n.php`
   defines:

   ```bash
   grep -rhoE "(prefix_t|prefix_e)\(\s*'[^']+'" --include='*.php' . \
     | grep -oE "'[^']+'" | tr -d "'" | sort -u > /tmp/keys-used.txt
   $WP eval 'foreach (array_keys(prefix_get_translations()) as $k) echo $k . "\n";' \
     | sort -u > /tmp/keys-defined.txt
   comm -23 /tmp/keys-used.txt /tmp/keys-defined.txt
   ```

   Any line of output is a key that will render as itself. Substitute the project's
   real prefix in both the grep and the eval. **FAIL** with the list.

5. **A field whose demo value carries inline markup is not `esc_html()`.** Sweep the
   rendered output rather than the source — the defect is visible only once a value
   is in place:

   ```bash
   curl -fsSk "$($WP option get home)" | grep -oE '&lt;/?(b|strong|em|i|br|span|a)[^&]*&gt;' | head
   ```

   A hit means a template escaped markup the demo meant to render: `Every <b>24</b>
   hours` printed with its tags showing, on both language versions of a page. The fix
   belongs in the template (`wp_kses` with an allowlist — `agents/wp-template.md` owns
   the rule), never in the field value. Run it against each page template at least
   once, not only the home page.

**PASS** if the strategy's own coverage holds, no raw `get_field()` in templates,
every `t()`/`e()` key resolves, and no escaped markup reaches the page. **FAIL** with
details.
