/**
 * manifest.mjs: every rule about .wp-create.json, in one place.
 *
 * There is deliberately no JSON Schema file. A schema interpreted only by our own
 * checker would be a second definition to keep in step -- the drift this module
 * exists to remove. What "shared" has to mean here is one definition every consumer
 * reaches through, and a module delivers that without adding a dependency.
 *
 * These functions are pure: callers do the I/O and pass the parsed values in.
 */

export const MANIFEST_NAME = '.wp-create.json';
export const LOCAL_NAME = '.wp-create.local.json';

// An absent manifest_version means the project predates versioning. /wp-audit already
// treats absence that way; this keeps the two readings identical.
//
// A PRESENT but malformed one is a different thing entirely, and used to be read as
// absent: `Number.isInteger("99")` is false, so a manifest declaring version "99" as a
// string was treated as legacy version 1 and offered for migration. That defeats the
// future-version guard below with nothing more than a pair of quotes -- the guard exists
// so a newer plugin's manifest is left untouched rather than downgraded, and a quoted
// number is exactly what a hand-edit or a JSON writer that stringifies numbers produces.
// versionProblem() is what callers check; detectVersion() keeps its old meaning for the
// absent case and is only reached once the version is known to be well-formed.
export function versionProblem(manifest) {
  const v = manifest?.manifest_version;
  if (v === undefined) return null;
  if (!Number.isInteger(v) || v < 1) {
    return `manifest_version must be a positive integer, found ${JSON.stringify(v)}`;
  }
  return null;
}

export function detectVersion(manifest) {
  const v = manifest?.manifest_version;
  return Number.isInteger(v) ? v : 1;
}

// Every decision the generated block in .claude/CLAUDE.md asserts, in render order.
// This table is the single owner of three things that used to be spelled separately
// and drifted apart: what the block renders, which of those fields validateManifest
// requires, and what an absent field means. The block is the first thing every agent
// reads, so a field rendered into it with no value puts a blank where a decision
// belongs -- which is why REQUIRED below is DERIVED from this list rather than kept
// beside it. A row with a `fallback` has a documented absent-value meaning and is
// therefore optional; every other row is required, and cannot be rendered without
// also being validated.
const CONTEXT_FIELDS = [
  {
    label: 'Project',
    paths: ['project.name', 'project.slug'],
    render: (m) => `${at(m, 'project.name') ?? ''} (\`${at(m, 'project.slug') ?? ''}\`)`,
  },
  { label: 'Theme slug', paths: ['theme.slug'] },
  { label: 'i18n strategy', paths: ['i18n strategy'], fallback: 'suffix' },
  { label: 'demo mode', paths: ['demo mode'], fallback: 'plain' },
  { label: 'Primary language', paths: ['languages.primary'] },
  { label: 'Plugin profile', paths: ['plugins.profile'], fallback: 'none' },
  // `scope: 'adopted'` rows are rendered only for a site registered by `wp-config.mjs adopt` -- one this plugin did not
  // build, whose theme it did not scaffold and whose plugins it did not choose. A created
  // project's block is byte-identical to what it was before these rows existed, so no
  // existing project reads as drifted. Every agent reads the block first; these rows are
  // how it learns which code it may change and which plugin owns SEO or security here.
  { label: 'Origin', paths: ['origin'], fallback: 'created', scope: 'adopted' },
  { label: 'Function prefix', paths: ['project.prefix'], scope: 'adopted' },
  { label: 'Industry', paths: ['project.industry'], fallback: 'unknown', scope: 'adopted' },
  { label: 'Editable code', paths: ['code_scope.editable'], scope: 'adopted', list: true },
  { label: 'Read-only code', paths: ['code_scope.read_only'], scope: 'adopted', list: true },
  {
    label: 'Stack',
    paths: ['stack'],
    scope: 'adopted',
    object: true,
    render: (m) => STACK_KEYS.map((k) => `${k}=${at(m, `stack.${k}`) ?? 'none'}`).join(', '),
  },
];

// `origin` absent means created: every manifest written before adoption existed came from
// /wp-create, and reading absence any other way would re-scope every existing project.
export function isAdopted(manifest) {
  return manifest?.origin === 'adopted';
}

// The rows that apply to THIS manifest. A row with a `scope` exists only for the projects it
// names; everywhere else it is neither rendered, validated nor allowed to supersede prose.
// A row names its scope as data, not as a function reference: identity comparison against
// a predicate broke silently the moment someone inlined an equivalent arrow function.
function contextFieldsFor(manifest) {
  return CONTEXT_FIELDS.filter((f) => !f.scope || (f.scope === 'adopted' && isAdopted(manifest)));
}

// The concerns a site's own plugins can already own. /wp-audit used to assume Rank Math and
// AIOS and offered to install them; on a site that runs Yoast and Wordfence that is a
// second SEO plugin and a second firewall, not a fix. `none` means nothing was detected.
export const STACK_KEYS = ['seo', 'security', 'fields', 'multilingual', 'builder', 'cache'];

// Required fields by dotted path. Anything not listed is optional and preserved.
// The tail is derived, not typed: see CONTEXT_FIELDS above.
const REQUIRED = [...new Set([
  'project.name', 'project.slug', 'project.path',
  'environment.type', 'environment.engine',
  'wordpress.url',
  'wp_cli.wrapper',
  ...CONTEXT_FIELDS.filter((f) => f.fallback === undefined && !f.scope).flatMap((f) => f.paths),
])];

// Required only when the manifest is an adopted one. Same derivation, other half of the table.
const REQUIRED_ADOPTED = CONTEXT_FIELDS
  .filter((f) => f.fallback === undefined && f.scope === 'adopted' && !f.list && !f.object)
  .flatMap((f) => f.paths);

function fallbackFor(path) {
  const field = CONTEXT_FIELDS.find((f) => f.paths[0] === path);
  return field?.fallback;
}

function at(obj, dotted) {
  // Own properties only. Plain bracket access walks the prototype chain, so a
  // suffixed key answered with a JS intrinsic instead of reporting an unknown
  // key: `get toString.length` printed 0. getKey's object/function guard catches
  // `constructor.prototype` (Object.prototype is an object) but not a primitive
  // one, and the secret-subtree refusal only covers a secret's own paths. Every
  // path this walks is a plain JSON leaf, so nothing legitimate needs the chain.
  return dotted.split('.').reduce((o, k) => (o == null || !Object.hasOwn(o, k) ? undefined : o[k]), obj);
}

// The categories /wp-audit offers. Exported because Step 2.5d's coverage diff names the
// same ones in prose, and two lists that must agree and live apart drift -- which is the
// defect the diff itself exists to catch, so it would be a poor place to reproduce it.
//
// `usability` is last and was added last, which matters to a manifest written before it
// existed: an absent category is never-run, not passed, so an older project reports it as
// a category it has yet to be audited against rather than as a clean one.
export const AUDIT_CATEGORIES = ['security', 'seo', 'a11y', 'performance', 'best-practices', 'geo', 'usability'];

// SEC-036, WP-049, SEO-054, A11Y-012, PERF-054, GEO-A11 -- a letter-and-digit prefix, then
// an optional letter before the number. This validates the SHAPE of an id and deliberately
// not its membership in any catalog: the catalogs live in the six agent files, they are the
// thing a project is diffed against, and a second copy here would be one more list to keep
// true. A typo'd-but-well-shaped id is caught by that diff, reported as never measured.
//
// The optional `@<n>` tail is a check REVISION (`SEC-036@2`). An id is an address, not a
// version: a project holding `SEC-036` stayed "covered" after SEC-036 was rewritten to look
// for something else, so its coverage read green for a rule it had never been measured
// against. An id with no tail means revision 1, which is what every id written before this
// existed means -- so no history is invalidated and nothing has to be re-tagged. Revision 0
// is refused because "@0" almost always means a counter that started in the wrong place.
const CHECK_ID = /^[A-Z][A-Z0-9]*-[A-Z]?\d+(@[1-9]\d*)?$/;

export function validateManifest(manifest) {
  const problems = [];
  if (manifest === null || typeof manifest !== 'object' || Array.isArray(manifest)) {
    return ['the manifest is not a JSON object'];
  }
  // A pointer, and it has to stay one. The findings ledger is audit history and grows
  // without bound -- one check found 70 orphan ids on a real site -- while this manifest is
  // parsed by every command on every run to find a WP-CLI wrapper and a theme slug. An
  // array here means the ledger has been inlined, which is the shape this refuses.
  const ledger = at(manifest, 'audit.findings_ledger');
  if (ledger !== undefined) {
    if (ledger === null || typeof ledger !== 'object' || Array.isArray(ledger)) {
      problems.push('audit.findings_ledger must be an object with a "path" -- it points at the ledger, it does not contain it');
    } else {
      if (typeof ledger.path !== 'string' || ledger.path === '') {
        problems.push('audit.findings_ledger.path must be a non-empty string');
      } else if (ledger.path.startsWith('/') || ledger.path.includes('..')) {
        // The path is read and written by the audit. An absolute path or one that climbs
        // out of the project is not a project artifact, and a manifest copied between
        // projects would carry it to a machine where it addresses something else.
        problems.push(`audit.findings_ledger.path must be relative to the project and must not climb out of it, found ${JSON.stringify(ledger.path)}`);
      }
      for (const key of Object.keys(ledger)) {
        if (key !== 'path' && key !== 'written') {
          problems.push(`audit.findings_ledger has an unknown key: ${key} -- it is a pointer, not the ledger`);
        }
      }
    }
  }

  const checksRun = at(manifest, 'audit.checks_run');
  if (checksRun !== undefined) {
    if (checksRun === null || typeof checksRun !== 'object' || Array.isArray(checksRun)) {
      problems.push('audit.checks_run must be an object keyed by audit category');
    } else {
      for (const [category, ids] of Object.entries(checksRun)) {
        if (!AUDIT_CATEGORIES.includes(category)) {
          problems.push(`audit.checks_run has an unknown category: ${category}`);
        }
        // A hand-edited "security": "SEC-036" is a string, and `for...of` over a string
        // iterates characters -- so the coverage diff would silently compare single
        // letters against check ids and report every check as never measured. Refuse it
        // here, where the message can say what the shape should be.
        if (!Array.isArray(ids)) {
          problems.push(`audit.checks_run.${category} must be an array of check IDs`);
          continue;
        }
        for (const id of ids) {
          if (typeof id !== 'string' || !CHECK_ID.test(id)) {
            problems.push(`audit.checks_run.${category} has an invalid check ID: ${JSON.stringify(id)}`);
          }
        }
      }
    }
  }
  const badVersion = versionProblem(manifest);
  if (badVersion) problems.push(badVersion);

  // Presence AND type. Checking only presence let `wp_cli.wrapper: []` and
  // `wordpress.url: {}` through: neither is undefined, null or '', so both satisfied the
  // old test and both are useless to every command that reads them. The wrapper is
  // interpolated straight into a shell command and the url into a search-replace, so the
  // failure surfaces later as a mangled command rather than here as a bad manifest --
  // which is the whole reason this file exists. Every required field is a scalar string;
  // an array or an object in any of them is a hand-edit or a bad writer, not a value.
  for (const key of REQUIRED) {
    const v = at(manifest, key);
    if (v === undefined || v === null || v === '') {
      problems.push(`${key} is required and is missing or empty`);
    } else if (typeof v !== 'string') {
      problems.push(`${key} must be a string, found ${Array.isArray(v) ? 'an array' : `a ${typeof v}`}`);
    }
  }

  // The optional CONTEXT_FIELDS rows are rendered into the generated block the same way,
  // so a non-string there puts "[object Object]" where a decision belongs.
  for (const key of contextFieldsFor(manifest).filter((f) => !f.list && !f.object).flatMap((f) => f.paths)) {
    if (REQUIRED.includes(key)) continue;
    const v = at(manifest, key);
    if (v !== undefined && v !== null && typeof v !== 'string') {
      problems.push(`${key} must be a string, found ${Array.isArray(v) ? 'an array' : `a ${typeof v}`}`);
    }
  }
  const mode = manifest['demo mode'];
  if (mode !== undefined && mode !== 'craft' && mode !== 'plain') {
    problems.push(`"demo mode" must be "craft" or "plain", found ${JSON.stringify(mode)}`);
  }
  const i18n = manifest['i18n strategy'];
  // `none` is an adopted site's answer only: it has no ACF suffix fields and no Polylang
  // groups -- it is monolingual, or a plugin this one does not build for (WPML, TranslatePress)
  // owns translation, which `stack.multilingual` records. A created project always chose one
  // of the two strategies this plugin builds, so `none` there is a hand-edit.
  const i18nAllowed = isAdopted(manifest) ? ['suffix', 'polylang', 'none'] : ['suffix', 'polylang'];
  if (i18n !== undefined && !i18nAllowed.includes(i18n)) {
    problems.push(`"i18n strategy" must be ${i18nAllowed.map((v) => `"${v}"`).join(' or ')}, found ${JSON.stringify(i18n)}`);
  }
  const origin = manifest.origin;
  if (origin !== undefined && origin !== 'created' && origin !== 'adopted') {
    problems.push(`origin must be "created" or "adopted", found ${JSON.stringify(origin)}`);
  }
  if (isAdopted(manifest)) problems.push(...validateAdopted(manifest));
  return problems;
}

// An adopted manifest carries the one thing a created project never needs: which code is
// the site's own. The fix phase of /wp-audit edits files, and on a site built on a commercial
// theme the active theme's parent is vendor code an update will overwrite -- so the list of
// what may be edited is a required, validated field, never a default.
function validateAdopted(manifest) {
  const problems = [];
  for (const key of REQUIRED_ADOPTED) {
    const v = at(manifest, key);
    if (v === undefined || v === null || v === '') {
      problems.push(`${key} is required on an adopted site and is missing or empty`);
    } else if (typeof v !== 'string') {
      problems.push(`${key} must be a string, found ${Array.isArray(v) ? 'an array' : `a ${typeof v}`}`);
    }
  }
  const industry = at(manifest, 'project.industry');
  if (industry !== undefined && typeof industry !== 'string') {
    problems.push('project.industry must be a string');
  }
  const scope = at(manifest, 'code_scope');
  if (scope === undefined || scope === null || typeof scope !== 'object' || Array.isArray(scope)) {
    problems.push('code_scope is required on an adopted site: an object with "editable" and "read_only" path arrays');
  } else {
    const seen = new Map();
    for (const list of ['editable', 'read_only']) {
      const paths = scope[list];
      if (!Array.isArray(paths)) {
        problems.push(`code_scope.${list} must be an array of paths relative to the WordPress root`);
        continue;
      }
      for (const p of paths) {
        if (typeof p !== 'string' || p === '') {
          problems.push(`code_scope.${list} has a non-string or empty entry: ${JSON.stringify(p)}`);
        } else if (p.startsWith('/') || p.split('/').includes('..')) {
          // Same rule as the ledger path: a manifest copied between machines must not carry
          // an address that means something else there, and the fix phase writes to these.
          problems.push(`code_scope.${list} must hold paths relative to the WordPress root that do not climb out of it, found ${JSON.stringify(p)}`);
        } else if (seen.has(p)) {
          problems.push(`code_scope lists ${JSON.stringify(p)} in both ${seen.get(p)} and ${list}`);
        } else {
          seen.set(p, list);
        }
      }
    }
    if (Array.isArray(scope.editable) && scope.editable.length === 0) {
      problems.push('code_scope.editable is empty: an adopted site with no code of its own has nothing to audit or fix -- list at least the active theme or a plugin');
    }
    for (const key of Object.keys(scope)) {
      if (key !== 'editable' && key !== 'read_only') problems.push(`code_scope has an unknown key: ${key}`);
    }
  }
  const stack = at(manifest, 'stack');
  if (stack !== undefined) {
    if (stack === null || typeof stack !== 'object' || Array.isArray(stack)) {
      problems.push('stack must be an object keyed by concern');
    } else {
      for (const [k, v] of Object.entries(stack)) {
        if (!STACK_KEYS.includes(k)) problems.push(`stack has an unknown key: ${k}`);
        else if (typeof v !== 'string' || v === '') problems.push(`stack.${k} must be a non-empty string ("none" when nothing owns it)`);
      }
    }
  }
  return problems;
}

// The prose line in .claude/CLAUDE.md is the ONLY record of a legacy project's i18n
// strategy, so migration reads it rather than re-deciding. Where it is absent the
// documented fallbacks apply unchanged: no line means suffix, no mode means plain.
export function readProseDecision(claudeMd, label) {
  const re = new RegExp(`^\\s*-\\s*\\*\\*${label}:\\*\\*\\s*\`?([A-Za-z_-]+)\`?\\s*$`, 'm');
  const m = re.exec(claudeMd ?? '');
  return m ? m[1] : null;
}

// Each step is explicit and additive. Unknown keys are carried through untouched:
// a key this version does not understand is not a key it may delete.
const STEPS = {
  1: (m, ctx) => ({
    ...m,
    manifest_version: 2,
    'i18n strategy': m['i18n strategy'] ?? readProseDecision(ctx.claudeMd, 'i18n strategy') ?? fallbackFor('i18n strategy'),
    'demo mode': m['demo mode'] ?? fallbackFor('demo mode'),
  }),
  2: (m) => ({ ...m, manifest_version: 3 }),
};

// Derived, not typed: CURRENT_VERSION and STEPS are one fact, and bumping the
// constant without writing the step used to produce an uncaught Error and a raw
// Node stack trace instead of a refusal in this module's style. A version with no
// step can no longer be expressed. (A non-contiguous table -- steps 1 and 3, no 2 --
// still would be, which is what the guard in migrateManifest remains for.)
export const CURRENT_VERSION = Math.max(...Object.keys(STEPS).map(Number)) + 1;

export function migrateManifest(manifest, { claudeMd = '' } = {}) {
  let current = { ...manifest };
  const notes = [];
  let version = detectVersion(current);
  while (version < CURRENT_VERSION) {
    const step = STEPS[version];
    if (!step) throw new Error(`no migration step from version ${version}`);
    current = step(current, { claudeMd });
    notes.push(`migrated ${version} -> ${detectVersion(current)}`);
    version = detectVersion(current);
  }
  return { manifest: current, notes };
}

export const SECRETS = {
  db_password: { env: 'WP_CREATE_DB_PASSWORD', manifestPath: 'database.password' },
  admin_password: { env: 'WP_CREATE_ADMIN_PASSWORD', manifestPath: 'wordpress.admin_password' },
};

// A value is "present" if it is neither absent (undefined/null) nor an object -- an
// empty string or 0 is a real, explicit value (an empty local-dev DB password is a
// real configuration) and must resolve as itself rather than cascade to the next
// rung, while an object at a secret's path (a manifest typo, a copy-paste slip) is
// not a bare string a caller piping `get` into `$(...)` can use, so it is treated
// the same as absent rather than printed via whatever rendering a template literal
// gives it.
function present(v) {
  return v !== undefined && v !== null && typeof v !== 'object';
}

// environment -> local file -> manifest. The manifest rung is kept so a project that
// has not migrated still works; the caller warns that it is legacy every time it wins.
export function resolveSecret(name, { env = {}, local = {}, manifest = {} } = {}) {
  const spec = SECRETS[name];
  if (!spec) return null;
  if (present(env[spec.env])) return { value: env[spec.env], source: 'env' };
  const fromLocal = at(local, spec.manifestPath);
  if (present(fromLocal)) return { value: fromLocal, source: 'local' };
  const fromManifest = at(manifest, spec.manifestPath);
  if (present(fromManifest)) return { value: fromManifest, source: 'manifest' };
  return null;
}

// Two manifest keys are spelled with a space ("demo mode", "i18n strategy"), which a
// dotted path cannot address, so lookup goes through an alias table -- derived from
// the same CONTEXT_FIELDS rows that define what those keys mean when absent. The
// alias used to be typed here and the absent-value default typed again inside
// getKey as a two-entry ternary, which silently handed 'plain' to any third alias
// and left "absent i18n strategy means suffix" unguarded on the get path.
const KEY_ALIASES = new Map(
  CONTEXT_FIELDS
    .filter((f) => f.paths[0].includes(' '))
    .map((f) => [f.paths[0].replace(/ /g, '-'), f]),
);

export function getKey(manifest, key) {
  const aliased = KEY_ALIASES.get(key);
  if (aliased) {
    return { ok: true, value: String(manifest[aliased.paths[0]] ?? aliased.fallback) };
  }
  // A secret's own manifest path (e.g. "database.password") -- or anything under
  // it, such as "database.password.length" or "database.password.constructor.name"
  // -- must not be reachable through the generic dotted-path fallback below. The
  // exact-match refusal alone missed this: at() happily keeps walking past the
  // string onto its own JS properties, so a suffixed path read the secret's
  // character count or its constructor, still bypassing env -> local -> manifest
  // with no legacy warning. Refuse the whole subtree and name the alias instead.
  const secretName = Object.keys(SECRETS).find((n) => {
    const p = SECRETS[n].manifestPath;
    return key === p || key.startsWith(`${p}.`);
  });
  if (secretName) return { ok: false, secret: secretName };
  const value = at(manifest, key);
  // A function is never a legitimate config value either -- reject it the same
  // way an object already is, so a suffixed non-secret path (e.g. a typo'd key
  // that happens to walk onto a JS prototype method) can't print one.
  if (value === undefined || value === null || typeof value === 'object' || typeof value === 'function') return { ok: false };
  return { ok: true, value: String(value) };
}

const PLUGIN_KEYS = new Set(['slug', 'required', 'requires', 'conflicts', 'source', 'tested']);

// `tested` was an allowed key with no defined meaning and no validation, so `tested: 42`
// passed and nothing read it -- a compatibility claim that could say anything and bound
// nobody. It holds the WordPress version, or inclusive version range, the entry is known
// good against: "6.4", "6.4.2", or "6.0 - 6.6". A range is the shape a profile author
// reaches for when a plugin's own readme declares one, so refusing it would push people
// back to the unvalidated free-for-all this replaces.
const WP_VERSION = /^\d+\.\d+(\.\d+)?$/;
const TESTED = /^\d+\.\d+(\.\d+)?( - \d+\.\d+(\.\d+)?)?$/;

// Compare two dotted WordPress versions. Missing segments are 0, so "6.4" === "6.4.0".
function cmpVersion(a, b) {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) return d < 0 ? -1 : 1;
  }
  return 0;
}

// A profile that cannot be satisfied should say so before anything is installed, not
// halfway through Step 4.10 with three plugins already active.
export function validateProfile(profile) {
  const problems = [];
  if (!profile || typeof profile !== 'object') return ['the profile is not a JSON object'];
  if (!profile.name) problems.push('name is required');
  if (!Array.isArray(profile.plugins)) return [...problems, 'plugins must be an array'];

  const seen = new Set();
  const slugs = new Set(profile.plugins.map((p) => p?.slug).filter(Boolean));

  for (const entry of profile.plugins) {
    if (!entry || typeof entry !== 'object') { problems.push('every plugins entry must be an object'); continue; }
    if (!entry.slug || typeof entry.slug !== 'string') { problems.push('every plugins entry needs a slug'); continue; }
    if (seen.has(entry.slug)) problems.push(`duplicate plugin slug: ${entry.slug}`);
    seen.add(entry.slug);
    // A profile author who typed a capital or stray whitespace should see it -- silent
    // normalisation is how "contact-form-7" and "Contact-Form-7" end up as two entries
    // that resolve to the same (or a colliding) WP-CLI install.
    const canonical = entry.slug.trim().toLowerCase();
    if (entry.slug !== canonical) {
      problems.push(`${entry.slug}: slug must already be lowercase and trimmed (did you mean "${canonical}"?)`);
    }
    for (const key of Object.keys(entry)) {
      if (!PLUGIN_KEYS.has(key)) problems.push(`unknown key on ${entry.slug}: ${key}`);
    }
    if (entry.required !== undefined && typeof entry.required !== 'boolean') {
      problems.push(`${entry.slug}: required must be a boolean`);
    }
    if (entry.source !== undefined && entry.source !== 'wordpress.org' && entry.source !== 'supplied') {
      problems.push(`${entry.slug}: source must be "wordpress.org" or "supplied"`);
    }
    if (entry.tested !== undefined) {
      if (typeof entry.tested !== 'string' || !TESTED.test(entry.tested)) {
        problems.push(`${entry.slug}: tested must be a WordPress version or range like "6.4", "6.4.2" or "6.0 - 6.6", found ${JSON.stringify(entry.tested)}`);
      } else if (entry.tested.includes(' - ')) {
        const [lo, hi] = entry.tested.split(' - ');
        if (cmpVersion(lo, hi) > 0) {
          problems.push(`${entry.slug}: tested range "${entry.tested}" runs backwards -- the low bound must come first`);
        }
      }
    }
    // A user-authored profile with "requires": 5 or "requires": {"x":1} is not an array,
    // and `for...of` on a non-iterable throws an uncaught TypeError -- a raw Node stack
    // trace naming this module's own path, the opposite of what this function exists to
    // produce. Refuse it as a validation problem instead of iterating it.
    if (entry.requires !== undefined && !Array.isArray(entry.requires)) {
      problems.push(`${entry.slug}: requires must be an array`);
    } else {
      for (const need of entry.requires ?? []) {
        if (!slugs.has(need)) problems.push(`${entry.slug} requires ${need}, which this profile does not list`);
      }
    }
    if (entry.conflicts !== undefined && !Array.isArray(entry.conflicts)) {
      problems.push(`${entry.slug}: conflicts must be an array`);
    } else {
      for (const bad of entry.conflicts ?? []) {
        if (slugs.has(bad)) problems.push(`${entry.slug} conflicts with ${bad}, which this profile also lists`);
      }
    }
  }
  return problems;
}

// What a profile's `tested` claims say about the WordPress actually installed. Returns one
// line per entry that has something to report, so Step 4.10 can print them; an entry with
// no `tested` yields "untested", which is deliberately visible rather than silent -- an
// absent compatibility claim is the common case and the operator should see that it is
// absent, not read a clean run as a tested one.
export function testedVerdicts(profile, wpVersion) {
  if (!WP_VERSION.test(wpVersion ?? '')) return [`cannot compare: ${JSON.stringify(wpVersion)} is not a WordPress version`];
  const out = [];
  for (const entry of profile?.plugins ?? []) {
    if (!entry?.slug) continue;
    if (entry.tested === undefined) { out.push(`${entry.slug}: untested against any WordPress version`); continue; }
    if (typeof entry.tested !== 'string' || !TESTED.test(entry.tested)) continue; // validateProfile reports it
    const [lo, hi] = entry.tested.includes(' - ') ? entry.tested.split(' - ') : [entry.tested, entry.tested];
    if (cmpVersion(wpVersion, lo) < 0) out.push(`${entry.slug}: WordPress ${wpVersion} is BELOW its tested ${entry.tested}`);
    else if (cmpVersion(wpVersion, hi) > 0) out.push(`${entry.slug}: WordPress ${wpVersion} is ABOVE its tested ${entry.tested}`);
  }
  return out;
}

export const MARK_BEGIN = '<!-- wp-create:begin -->';
export const MARK_END = '<!-- wp-create:end -->';

// Rendered from the manifest, so the two files cannot disagree. Every line here is
// a decision some command branches on; guidance an operator writes lives OUTSIDE
// the markers and is never touched.
function renderField(f, manifest) {
  if (f.render) return f.render(manifest);
  const v = at(manifest, f.paths[0]);
  if (f.list) return Array.isArray(v) && v.length ? v.map((p) => `\`${p}\``).join(', ') : '(none)';
  return v ?? f.fallback ?? '';
}

export function renderContext(manifest) {
  const lines = [
    MARK_BEGIN,
    '<!-- Generated from .wp-create.json by bin/wp-config.mjs. Edits inside these markers are reported, not kept. -->',
    '',
    ...contextFieldsFor(manifest).map((f) => `- **${f.label}:** ${renderField(f, manifest)}`),
    '',
    MARK_END,
  ];
  return lines.join('\n');
}

// The one place spliceContext and contextDrift agree on where the block is, or
// whether it can be found at all. Three outcomes, no others: absent (append),
// present (exactly one BEGIN before exactly one END -- replace), or malformed
// (refuse). Guessing at anything else is what used to be destructive: a lone BEGIN
// with no END used to take the append branch, stacking a second block after the
// orphan instead of refusing, and the very next render-context then paired that
// orphan BEGIN with the real END and deleted everything an operator had written
// between them -- including their own prose. Refusing beats guessing.
//
// Markers are found by literal indexOf, not by parsing Markdown, so a fenced code
// block that *documents* this feature by showing both markers as an example is
// indistinguishable from a file that actually uses them -- it produces two BEGINs
// and two ENDs, which this correctly refuses rather than corrupting. A fence
// containing exactly one marker is not caught by this and is a real ceiling: there
// is no way to tell "an operator wrote one marker for real" from "an operator wrote
// one marker as an example" without parsing the fence, so it is refused too rather
// than guessed at either way.
function markerState(text) {
  const begins = [];
  for (let i = text.indexOf(MARK_BEGIN); i !== -1; i = text.indexOf(MARK_BEGIN, i + 1)) begins.push(i);
  const ends = [];
  for (let i = text.indexOf(MARK_END); i !== -1; i = text.indexOf(MARK_END, i + 1)) ends.push(i);

  if (begins.length === 0 && ends.length === 0) return { ok: true, present: false };
  if (begins.length === 1 && ends.length === 1 && begins[0] < ends[0]) {
    return { ok: true, present: true, start: begins[0], end: ends[0] };
  }
  const reason = begins.length === 1 && ends.length === 1
    ? 'malformed wp-create markers: wp-create:end appears before wp-create:begin'
    : `malformed wp-create markers: found ${begins.length} wp-create:begin and ${ends.length} wp-create:end marker(s), want exactly one of each or neither`;
  return { ok: false, reason };
}

// Replaces the block if present, appends it if absent. Throws on a malformed marker
// state instead of writing anything -- the caller reports it and exits without
// touching the file; see markerState above for why guessing is the bug this fixes.
export function spliceContext(claudeMd, block) {
  const text = claudeMd ?? '';
  const state = markerState(text);
  if (!state.ok) throw new Error(state.reason);
  if (!state.present) {
    const sep = text.endsWith('\n') || text === '' ? '' : '\n';
    return `${text}${sep}\n${block}\n`;
  }
  return text.slice(0, state.start) + block + text.slice(state.end + MARK_END.length);
}

// Labels are prose and may one day carry `(` or `.`; a label is matched literally.
function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Migration hands ownership of the CONTEXT_FIELDS decisions to the generated block.
// The legacy prose lines that carried them until then sit OUTSIDE the markers, where
// contextDrift cannot see them, so leaving them alone is how a migrated project ends
// up stating `polylang` on line 4 and `suffix` on line 12 with `validate` exiting 0 --
// the exact disagreement this module exists to remove, reintroduced by its own
// migration. They are commented out rather than deleted: the pre-migration text is the
// only evidence of what the project used to say, and an operator reading the file is
// owed both the old value and where the answer moved to. A commented line no longer
// starts with the list bullet, so a second pass is a no-op.
//
// Lines inside the markers are the block's own and are left byte-identical -- they
// carry the same labels, so a marker-blind pass would comment out the very record it
// is protecting. A malformed marker state is returned untouched; the caller refuses.
//
// Only the rows that apply to `manifest` supersede prose: a created project's hand-written
// `Function prefix` line is its only record of the prefix, and the block never renders one.
export function supersedeProseDecisions(claudeMd, manifest) {
  const text = claudeMd ?? '';
  const rewrite = (chunk) => contextFieldsFor(manifest).reduce((acc, f) => acc.replace(
    new RegExp(`^([ \\t]*-[ \\t]*\\*\\*${escapeRegExp(f.label)}:\\*\\*.*)$`, 'gm'),
    (_, line) => `<!-- superseded by the wp-create:begin block below: ${line.trim()} -->`,
  ), chunk);

  const state = markerState(text);
  if (!state.ok) return text;
  if (!state.present) return rewrite(text);
  const stop = state.end + MARK_END.length;
  return rewrite(text.slice(0, state.start)) + text.slice(state.start, stop) + rewrite(text.slice(stop));
}

// Drift is a finding, not a repair: an operator who edited the block meant something,
// and silently reverting it is how the two files started disagreeing in the first
// place. A malformed marker state is a DIFFERENT finding from ordinary drift -- the
// block cannot even be located, let alone compared to what the manifest would
// render -- so it carries its own message rather than being folded into "no longer
// matches the manifest".
export function contextDrift(claudeMd, manifest) {
  const text = claudeMd ?? '';
  const state = markerState(text);
  if (!state.ok) return state.reason;
  if (!state.present) return null;
  const expected = renderContext(manifest);
  const found = text.slice(state.start, state.end + MARK_END.length);
  return found === expected ? null : 'the generated block between wp-create:begin and wp-create:end no longer matches the manifest';
}
