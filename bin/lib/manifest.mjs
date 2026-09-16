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
