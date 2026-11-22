- **`bin/*.mjs` tools no longer drop output on a pipe when they exit.** On a pipe Node
  writes asynchronously, so a tool that printed more than 64 KiB and then called
  `process.exit()` ended with the rest of its output unsent: `css-contour-lint.mjs` with a
  thousand findings delivered 272 of its 1001 lines through a slow reader, the summary line
  among the lost ones, and still exited 1. Every tool now imports `bin/lib/stdio-blocking.mjs`
  first, which makes stdout and stderr blocking, so each write completes before the next
  statement and none of the tools' 160 or so exit sites had to change.
  `tests/checks/mjs-stdio-blocking.sh` pins the import in every tool and pipes more than
  64 KiB through the module and through `css-contour-lint.mjs`.
