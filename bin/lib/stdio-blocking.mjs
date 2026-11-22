/**
 * stdio-blocking.mjs: make stdout and stderr blocking, so process.exit() never drops output.
 *
 * Imported for its side effect, first, by every bin/*.mjs tool:
 *
 *   import './lib/stdio-blocking.mjs';
 *
 * Why: when stdout or stderr is a pipe, Node writes to it asynchronously. A write the pipe
 * cannot take at once (more than its 64 KiB buffer, or a reader that is slow to drain it) is
 * queued in the process, and process.exit() ends the process with that queue still unsent.
 * `tool --json | jq` then reads a report cut at 65536 bytes, and the tool still exits 0.
 * A file or a terminal is not affected: Node already writes those synchronously.
 *
 * The tools call process.exit() at about 160 sites, many in the middle of a function to stop
 * it there. Rewriting each one to set process.exitCode and return changes control flow at
 * every site; making the two streams blocking once keeps every site as it is and makes each
 * write complete before the next statement runs. The cost is that a tool waits for a slow
 * reader instead of racing ahead of it, which is what a command-line tool should do.
 *
 * `_handle.setBlocking()` is not a documented API, but it is the call Node makes on its own
 * stdio, and libuv implements it for pipes. Where a stream has no such handle (a worker
 * thread, a runtime without it) the import does nothing and the tool behaves as before.
 * tests/checks/mjs-stdio-blocking.sh pipes more than 64 KiB through this module and fails if
 * the output arrives short, so a Node release that drops the call is caught by the suite.
 */

for (const stream of [process.stdout, process.stderr]) {
  const handle = stream && stream._handle;
  if (handle && typeof handle.setBlocking === 'function') {
    try { handle.setBlocking(true); } catch { /* leave the stream as Node opened it */ }
  }
}
