- **`/wp-init` now parses the flags `/wp-cinematic-init` hands it.** The hand-off passed
  `--path`, `--mode`, `--starter` and `--acf-flavor`, none of which `/wp-init` read, so it asked
  for the template and the custom-fields plugin again, and choosing cinematic dispatched back to
  `/wp-cinematic-init` in a loop. A new Step 0.4 owns those values and skips Steps 0.5 and 0.6
  when they are preset, and a run entered with `--mode=cinematic` no longer dispatches back.
  The hybrid switch had two spellings (`--hybrid` and `--no-hybrid`); it is now `--no-hybrid`
  in both commands.
  Only `--mode=cinematic` and `--starter=__cinematic__` mark entry from the caller;
  `--template=cinematic` still dispatches. When entered from the caller, `/wp-init` does the
  shared bootstrap only (starter copy, placeholders, server, database) and returns: the agent,
  scenes, seeding and menus are owned by `/wp-cinematic-init` alone, and `--acf-flavor` is
  passed only when given.
  Choosing cinematic now dispatches `/wp-cinematic-init --path=<dir>` with `--acf-flavor` and
  `--no-hybrid` when set; a caller-entered `/wp-init` prints a return line instead of "Next step"
  and the live-view line; and `/wp-cinematic-init` builds the agent payload from `--scenes` and
  `--no-hybrid` instead of hard-coding 9 and hybrid on.
