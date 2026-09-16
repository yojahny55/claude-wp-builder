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

export const CURRENT_VERSION = 3;
export const MANIFEST_NAME = '.wp-create.json';
export const LOCAL_NAME = '.wp-create.local.json';

// An absent manifest_version means the project predates versioning. /wp-audit already
// treats absence that way; this keeps the two readings identical.
export function detectVersion(manifest) {
  const v = manifest?.manifest_version;
  return Number.isInteger(v) ? v : 1;
}

// Required fields by dotted path. Anything not listed is optional and preserved.
const REQUIRED = [
  'project.name', 'project.slug', 'project.path',
  'environment.type', 'environment.engine',
  'wordpress.url',
  'wp_cli.wrapper',
];

function at(obj, dotted) {
  return dotted.split('.').reduce((o, k) => (o == null ? o : o[k]), obj);
}

export function validateManifest(manifest) {
  const problems = [];
  if (manifest === null || typeof manifest !== 'object' || Array.isArray(manifest)) {
    return ['the manifest is not a JSON object'];
  }
  for (const key of REQUIRED) {
    const v = at(manifest, key);
    if (v === undefined || v === null || v === '') problems.push(`${key} is required and is missing or empty`);
  }
  const mode = manifest['demo mode'];
  if (mode !== undefined && mode !== 'craft' && mode !== 'plain') {
    problems.push(`"demo mode" must be "craft" or "plain", found ${JSON.stringify(mode)}`);
  }
  const i18n = manifest['i18n strategy'];
  if (i18n !== undefined && i18n !== 'suffix' && i18n !== 'polylang') {
    problems.push(`"i18n strategy" must be "suffix" or "polylang", found ${JSON.stringify(i18n)}`);
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
    'i18n strategy': m['i18n strategy'] ?? readProseDecision(ctx.claudeMd, 'i18n strategy') ?? 'suffix',
    'demo mode': m['demo mode'] ?? 'plain',
  }),
  2: (m) => ({ ...m, manifest_version: 3 }),
};

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

export const MARK_BEGIN = '<!-- wp-create:begin -->';
export const MARK_END = '<!-- wp-create:end -->';

// Rendered from the manifest, so the two files cannot disagree. Every line here is
// a decision some command branches on; guidance an operator writes lives OUTSIDE
// the markers and is never touched.
export function renderContext(manifest) {
  const lines = [
    MARK_BEGIN,
    '<!-- Generated from .wp-create.json by bin/wp-config.mjs. Edits inside these markers are reported, not kept. -->',
    '',
    `- **Project:** ${manifest.project?.name ?? ''} (\`${manifest.project?.slug ?? ''}\`)`,
    `- **Theme slug:** ${manifest.theme?.slug ?? ''}`,
    `- **i18n strategy:** ${manifest['i18n strategy'] ?? 'suffix'}`,
    `- **demo mode:** ${manifest['demo mode'] ?? 'plain'}`,
    `- **Primary language:** ${manifest.languages?.primary ?? ''}`,
    `- **Plugin profile:** ${manifest.plugins?.profile ?? 'none'}`,
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
