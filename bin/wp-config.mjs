#!/usr/bin/env node
/**
 * wp-config.mjs: the one gate every command that reads .wp-create.json passes through.
 *
 * Exit codes are fixed and are part of the contract: 0 ok, 1 invalid or refused,
 * 2 a migration is available, 3 there is no manifest.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import {
  CURRENT_VERSION, MANIFEST_NAME, detectVersion, validateManifest,
} from './lib/manifest.mjs';

const say = (s) => console.log(s);
const warn = (s) => console.error(s);

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
  if (version < CURRENT_VERSION) {
    warn(`manifest_version ${version} can migrate to ${CURRENT_VERSION}: run wp-config.mjs migrate`);
    process.exit(2);
  }
  say(`ok: ${MANIFEST_NAME} valid at version ${version}`);
}

const [cmd, target] = process.argv.slice(2);
if (cmd === 'validate' && target) cmdValidate(target);
else {
  warn('usage: wp-config.mjs validate <project-path>');
  process.exit(1);
}
