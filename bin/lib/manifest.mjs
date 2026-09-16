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
