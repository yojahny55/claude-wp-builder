# /wp-tailwind-migrate — Step 4

`commands/wp-tailwind-migrate.md` sends the run here at Step 4. Follow it in order; nothing in it is optional background.

Every dispatch prompt opens with this line, verbatim:

> Mode: **author**

`agents/wp-tailwind.md` selects Section Authoring Mode on that line and on nothing
else. It used to gate on a bare `author` token anywhere in the prompt, which an
ordinary input path (`demo/author.html`) supplies by accident, so the token is no
longer read: a prompt that only *describes* author mode in prose now runs Demo
Conversion Mode and writes a `.tmp` conversion of a template nobody asked to convert.

**Author mode takes its markup in two states, and every dispatch prompt must say which
one this is** — see *Input state* in `agents/wp-tailwind.md`. A migration is the
plain-CSS state: there is no converted demo anywhere in this chain, so the agent owes
the markup the declaration-to-utility translation before it authors anything, and it
only knows that from the prompt. Say nothing and it assumes the other state — already
Tailwind-native, nothing to translate — and applies the `@apply` ladder to untouched
BEM markup. Each dispatch prompt states:

- The literal line `Mode: **author**`, first in the prompt. That line is what selects
  Section Authoring Mode in `agents/wp-tailwind.md`; without it every other item in
  this list is handed to an agent running Demo Conversion Mode.
- The markup handed over is **plain-CSS, not converted**, so the agent owes it the
  translation its *Input state* section prescribes for that state.
- The template's own markup **and** the matching CSS rules from Step 1's audit. A rule
  in a stylesheet the agent was never given is a rule it cannot translate.
- Translate each declaration to the equivalent utility, and every `@media` query to
  the matching Tailwind breakpoint prefix rather than re-writing the query. Prefer the
  `@theme` tokens Step 3 extracted over a built-in colour scale.
- **When no built-in stop matches, name one — do not emit `max-[<n>px]:`.** A demo drawn
  in a design tool has its queries at frame widths (1599, 1023, 759), and translating
  them literally gives hundreds of arbitrary variants. Collect the widths the demo
  actually switches at, declare them once as `--breakpoint-*` in `@theme`, and use the
  named prefixes. See **Name the breakpoints** in `skills/wp-tailwind-system/references/breakpoints.md` for why: chief
  among them, markup that lives in the DATABASE rather than in a scanned file loses
  every arbitrary variant the day the theme normalizes them.
- All five inputs author mode's Inputs table declares — the `section HTML`,
  `--block <name>`, `--page <slug>`, the **theme path** and the project's function
  **prefix**. `--block` and `--page` are the two author mode requires outright; the
  theme path and the prefix are the two a dispatch most often forgets, and without
  them the agent has no theme root to write into and no prefix for the function names
  its markup calls. That `--page` names the template's `components/<slug>.css`; it is
  not this command's `--page` flag, which selects what gets migrated at all.
- **Write only the template and its `components/<slug>.css`.** Do **not** create or
  edit `utilities/site.css`, and do **not** edit `main.css`. Author mode's Procedure
  tells the agent to promote a cross-page group into `utilities/site.css` and to
  register its `@import` in `main.css` in the same step — correct for a single agent,
  a last-write-wins race for a parallel walk, where every agent creates the same two
  files at once and the last one to finish erases the rest. Its cross-page grep has
  the same defect from the other side: under a parallel walk the sibling templates
  are not converted yet, so it greps a corpus that does not exist and concludes
  "one page" every time. Have the agent **report** the groups it would have promoted
  instead. Step 4b promotes and registers, once, serially, over the finished corpus.
- **Do not run `bin/tailwind-native-check.sh` yourself.** This command owns the
  convention check and runs it once, in Step 6, after the old CSS is gone. Run from
  inside a Step 4 agent it fails by construction: `assets/css/styles.css` is still
  present until Step 5 deletes it, and the unconverted templates still carry
  plain-CSS class names until the walk finishes. An agent that runs it sees FAIL on a correctly
  progressing migration and either reports failure or starts "fixing" a half-migrated
  theme.

Each agent:

- Rewrites its template's markup with Tailwind utility classes.
- Puts a group local to one page in `components/<slug>.css` via `@apply`, creating
  that file with its first rule already in it — but only once that group is **repeated**
  in the sense `skills/wp-tailwind-system/SKILL.md` defines: the same group of utilities
  3+ times, or on 2+ distinct pages. A group used twice inside one section stays inline.
  Promoting below that threshold trades markup you can read for a class you have to look
  up.
- Reports — rather than writes — every group it judges worth promoting across pages,
  naming the utilities in it and the pages it saw it on.
- Keeps every `@apply` class named `<block>__<element>` so parallel agents cannot
  collide.

No agent creates a directory under `assets/css/src/tailwindcss/`. The four Step 2
directories are the entire layout; a new one fails the convention check in Step 6.
