#!/usr/bin/env node
/**
 * export-platform.mjs: make this plugin's commands usable from another coding agent.
 *
 * The plugin is written for Claude Code: slash commands in commands/*.md, subagents in
 * agents/*.md, knowledge in skills/, and every path spelled ${CLAUDE_PLUGIN_ROOT}/... . Other
 * agents read none of that by themselves. This writes, from the files as they are, what three
 * of them do read:
 *
 *   agents-md  <out>/AGENTS.md: an index of every command and agent, with its file
 *   cursor     <out>/.cursor/rules/<command>.mdc: one rule per command, attached on request
 *   gemini     <out>/GEMINI.md (the index) and <out>/.gemini/commands/<command>.toml
 *
 * Nothing in commands/, agents/ or skills/ changes: the export points at the plugin's own
 * files by absolute path, so a step that says "read ${CLAUDE_PLUGIN_ROOT}/skills/x/SKILL.md"
 * still resolves. Each exported command starts with the three things another agent does not
 * have: subagents (do the agent's work yourself, in order), AskUserQuestion (ask in the
 * chat), and the plugin root. This is phase 1; abstracting those three out of the commands
 * themselves changes every command and is left for a separate decision.
 *
 * Exit codes (COMMON scheme): 0 written, 2 the plugin root has no commands/ to read,
 * 3 crash, 64 usage.
 */
import './lib/stdio-blocking.mjs';
import { readFileSync, readdirSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, resolve, dirname, basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const TARGETS = ['agents-md', 'cursor', 'gemini'];

const HELP = `usage: export-platform.mjs --target agents-md|cursor|gemini <out-dir> [--plugin-root <dir>]

Writes this plugin's commands in the format another coding agent reads:
  agents-md  <out>/AGENTS.md
  cursor     <out>/.cursor/rules/<command>.mdc
  gemini     <out>/GEMINI.md and <out>/.gemini/commands/<command>.toml
Paths point at the plugin's own files (default root: the directory above bin/).
Exit 0 written, 2 no commands/ under the plugin root, 3 crash, 64 usage.
`;

class UsageError extends Error {}

/** Frontmatter (flat `key: value` lines) and body of a markdown file. */
export function splitFrontmatter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  if (!m) return { meta: {}, body: text };
  const meta = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z][\w-]*):\s*(.*)$/);
    if (!kv) continue;
    let v = kv[2].trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    meta[kv[1]] = v;
  }
  return { meta, body: text.slice(m[0].length) };
}

/** Every command or agent file of a directory: [{ name, file, meta, body }], sorted by name. */
function readDocs(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((f) => f.endsWith('.md'))
    .sort()
    .map((f) => {
      const file = join(dir, f);
      const { meta, body } = splitFrontmatter(readFileSync(file, 'utf8'));
      return { name: basename(f, '.md'), file, meta, body };
    });
}

/** The command body with plugin paths made absolute and, for Gemini, the arguments placeholder. */
export function portBody(body, root, argsToken) {
  let out = body.split('${CLAUDE_PLUGIN_ROOT}').join(root);
  if (argsToken) out = out.split('$ARGUMENTS').join(argsToken);
  return out;
}

/** What another agent needs before it reads a Claude Code command. */
export function preamble(root, cmd, argsNote = '`$ARGUMENTS` below means the words the user gave with the request.') {
  return [
    `This is the \`/${cmd.name}\` command of the claude-wp-builder plugin, exported for an agent`,
    'other than Claude Code. Three things in it are Claude Code tools you do not have:',
    '',
    `- **Subagents.** A step that dispatches an agent (\`wp-template\`, \`wp-css\`, …) means: read`,
    `  \`${root}/agents/<agent>.md\` and do that agent's work yourself, one agent at a time, in the`,
    '  order the step gives. Steps that dispatch several agents in parallel run in sequence.',
    '- **AskUserQuestion.** Ask the same question in the chat and wait for the answer.',
    `- **Plugin root.** Every path below is already absolute, under \`${root}\`. Read the files`,
    '  a step names when the step says so; they are part of the command.',
    '',
    cmd.meta['argument-hint'] ? `Arguments: \`${cmd.meta['argument-hint']}\`` : 'Arguments: none.',
    argsNote,
    '',
    '---',
    '',
  ].join('\n');
}

/** AGENTS.md / GEMINI.md: the index of commands and agents. */
export function indexDoc(root, commands, agents, heading) {
  const lines = [
    `# ${heading}`,
    '',
    'WordPress site builder commands from the claude-wp-builder plugin. Each command is a',
    'markdown file of steps: when the user asks for one by name (`/wp-init`, "run wp-audit"),',
    'read its file whole and follow it in order. A step that dispatches a subagent means: read',
    `\`${root}/agents/<agent>.md\` and do that work yourself, in sequence. A question the command`,
    'asks with AskUserQuestion is asked in the chat. `${CLAUDE_PLUGIN_ROOT}` in any file is',
    `\`${root}\`.`,
    '',
    '## Commands',
    '',
  ];
  for (const c of commands) {
    lines.push(`- \`/${c.name}\` — ${c.meta.description || '(no description)'} — \`${c.file}\``);
  }
  lines.push('', '## Agents', '');
  for (const a of agents) {
    lines.push(`- \`${a.name}\` — ${a.meta.description || '(no description)'} — \`${a.file}\``);
  }
  return lines.join('\n') + '\n';
}

/**
 * A double-quoted string valid in both TOML (basic string) and YAML (flow scalar). JSON.stringify
 * escapes quotes, backslashes and C0 controls with escapes both accept, but leaves DEL and the
 * C1 controls raw and writes a lone surrogate as \uD800, which neither accepts. So: lone
 * surrogates become U+FFFD first, and DEL and C1 are escaped after.
 */
export function quoted(s) {
  const wellFormed = String(s).replace(/[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/g, '\uFFFD');
  return JSON.stringify(wellFormed).replace(/[\x7f-\x9f]/g, (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, '0')}`);
}

/** A Cursor rule (.mdc): attached on request by its description, never always on. */
export function cursorRule(root, cmd) {
  const desc = `/${cmd.name}: ${cmd.meta.description || ''}`.replace(/\s+/g, ' ').trim();
  return [
    '---',
    `description: ${quoted(desc)}`,
    'globs:',
    'alwaysApply: false',
    '---',
    '',
    preamble(root, cmd) + portBody(cmd.body, root, null),
  ].join('\n');
}

/**
 * A Gemini CLI custom command. Strings go out as TOML basic strings through quoted(), so a
 * command body full of quotes, backslashes and backticks needs no hand-written escaping.
 */
export function geminiCommand(root, cmd) {
  const desc = `/${cmd.name}: ${cmd.meta.description || ''}`.replace(/\s+/g, ' ').trim();
  const prompt = preamble(root, cmd, "The user's arguments: `{{args}}`.") + portBody(cmd.body, root, '{{args}}');
  return `description = ${quoted(desc)}\nprompt = ${quoted(prompt)}\n`;
}

function write(file, text) {
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, text);
  return file;
}

function parseArgs(argv) {
  const o = { target: null, out: null, root: null, help: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => {
      if (i + 1 >= argv.length) throw new UsageError(`${a} needs a value`);
      return argv[++i];
    };
    if (a === '--help' || a === '-h') o.help = true;
    else if (a === '--target') o.target = next();
    else if (a === '--plugin-root') o.root = next();
    else if (a.startsWith('--')) throw new UsageError(`unknown option ${a}`);
    else if (o.out === null) o.out = a;
    else throw new UsageError(`unexpected argument ${a}`);
  }
  if (o.help) return o;
  if (!TARGETS.includes(o.target)) throw new UsageError(`--target must be one of ${TARGETS.join(', ')}`);
  if (o.out === null) throw new UsageError('missing <out-dir>');
  return o;
}

function main(argv) {
  let o;
  try {
    o = parseArgs(argv);
  } catch (e) {
    if (!(e instanceof UsageError)) throw e;
    process.stderr.write(`export-platform: ${e.message}\n${HELP}`);
    process.exitCode = 64;
    return;
  }
  if (o.help) {
    process.stdout.write(HELP);
    process.exitCode = 0;
    return;
  }
  const root = resolve(o.root || join(dirname(fileURLToPath(import.meta.url)), '..'));
  const commands = readDocs(join(root, 'commands'));
  if (commands.length === 0) {
    process.stderr.write(`export-platform: no commands/*.md under ${root}\n`);
    process.exitCode = 2;
    return;
  }
  const agents = readDocs(join(root, 'agents'));
  const out = resolve(o.out);
  const written = [];
  if (o.target === 'agents-md') {
    written.push(write(join(out, 'AGENTS.md'), indexDoc(root, commands, agents, 'WordPress builder commands')));
  } else if (o.target === 'cursor') {
    for (const c of commands) written.push(write(join(out, '.cursor', 'rules', `${c.name}.mdc`), cursorRule(root, c)));
  } else {
    written.push(write(join(out, 'GEMINI.md'), indexDoc(root, commands, agents, 'WordPress builder commands')));
    for (const c of commands) written.push(write(join(out, '.gemini', 'commands', `${c.name}.toml`), geminiCommand(root, c)));
  }
  process.stdout.write(`export-platform: ${o.target}: ${written.length} file(s) under ${out}\n`);
  process.exitCode = 0;
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  try {
    main(process.argv.slice(2));
  } catch (e) {
    process.stderr.write(`export-platform: ${e.stack || e}\n`);
    process.exitCode = 3;
  }
}
