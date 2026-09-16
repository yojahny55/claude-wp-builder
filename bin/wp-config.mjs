#!/usr/bin/env node
/**
 * wp-config.mjs: the one gate every command that reads .wp-create.json passes through.
 *
 * Exit codes are fixed and are part of the contract: 0 ok, 1 invalid or refused,
 * 2 a migration is available, 3 there is no manifest.
 */
import {
  readFileSync, existsSync, writeFileSync, copyFileSync, mkdirSync,
} from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import {
  CURRENT_VERSION, MANIFEST_NAME, detectVersion, validateManifest, migrateManifest,
  renderContext, spliceContext, contextDrift,
} from './lib/manifest.mjs';

const say = (s) => console.log(s);
const warn = (s) => console.error(s);

function claudeMdPath(projectPath) {
  return join(resolve(projectPath), '.claude', 'CLAUDE.md');
}

function loadManifest(projectPath) {
  const file = join(resolve(projectPath), MANIFEST_NAME);
  if (!existsSync(file)) {
    warn(`no ${MANIFEST_NAME} at ${resolve(projectPath)} -- run /wp-create first`);
    process.exit(3);
  }
  try {
    return { file, manifest: JSON.parse(readFileSync(file, 'utf8')) };
  } catch (err) {
    warn(`${MANIFEST_NAME} is not valid JSON: ${err.message}`);
    process.exit(1);
  }
}

function cmdValidate(projectPath) {
  const { manifest } = loadManifest(projectPath);
  const version = detectVersion(manifest);
  if (version > CURRENT_VERSION) {
    warn(`manifest_version ${version} is newer than this plugin understands (${CURRENT_VERSION}); leaving it untouched`);
    process.exit(1);
  }
  const problems = validateManifest(manifest);
  if (problems.length) {
    for (const p of problems) warn(`invalid: ${p}`);
    process.exit(1);
  }
  const claudeFile = claudeMdPath(projectPath);
  if (existsSync(claudeFile)) {
    const drift = contextDrift(readFileSync(claudeFile, 'utf8'), manifest);
    if (drift) {
      warn(`invalid: ${drift}`);
      warn('run wp-config.mjs render-context to regenerate it, or fix the manifest it came from');
      process.exit(1);
    }
  }
  if (version < CURRENT_VERSION) {
    warn(`manifest_version ${version} can migrate to ${CURRENT_VERSION}: run wp-config.mjs migrate`);
    process.exit(2);
  }
  say(`ok: ${MANIFEST_NAME} valid at version ${version}`);
}

function cmdMigrate(projectPath) {
  const { file, manifest } = loadManifest(projectPath);
  const version = detectVersion(manifest);
  if (version > CURRENT_VERSION) {
    warn(`manifest_version ${version} is newer than this plugin understands (${CURRENT_VERSION}); leaving it untouched`);
    process.exit(1);
  }
  if (version === CURRENT_VERSION) {
    say(`ok: already at version ${CURRENT_VERSION}, nothing to migrate`);
    return;
  }
  const claudeFile = claudeMdPath(projectPath);
  const claudeMd = existsSync(claudeFile) ? readFileSync(claudeFile, 'utf8') : '';
  const { manifest: next, notes } = migrateManifest(manifest, { claudeMd });

  // Versioned on purpose: /wp-create writes .wp-create.json.bak when the user chooses
  // Overwrite, and reusing that name would destroy their pre-overwrite copy.
  copyFileSync(file, `${file}.v${version}.bak`);
  writeFileSync(file, `${JSON.stringify(next, null, 2)}\n`);
  for (const n of notes) say(n);
  say(`ok: migrated to version ${CURRENT_VERSION}`);
  cmdRenderContext(projectPath);
}

function cmdRenderContext(projectPath) {
  const { manifest } = loadManifest(projectPath);
  const file = claudeMdPath(projectPath);
  const current = existsSync(file) ? readFileSync(file, 'utf8') : '';
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, spliceContext(current, renderContext(manifest)));
  say(`ok: wrote the generated block in ${file}`);
}

const [cmd, target] = process.argv.slice(2);
if (cmd === 'validate' && target) cmdValidate(target);
else if (cmd === 'migrate' && target) cmdMigrate(target);
else if (cmd === 'render-context' && target) cmdRenderContext(target);
else {
  warn('usage: wp-config.mjs <validate|migrate|render-context> <project-path>');
  process.exit(1);
}
