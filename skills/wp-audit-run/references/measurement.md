# /wp-audit — Step 6.9

`commands/wp-audit.md` sends the run here at Step 6.9. Follow it in order; nothing in it is optional background.

A finding is the output of a command that ran in THIS run, and it carries what produced it:
the `$WP` call, the file:line, the URL fetched. Nothing else is a finding.

Two shapes have shipped in real reports, and both read exactly like a real defect:

- **Asserted from reading, not from counting.** An agent that sees two code paths capable of
  printing a meta description reports a duplicate description — on a page that emits one. The
  fix is to count the rendered output, not the code paths: `curl -s <url> | grep -c '<meta
  name="description"'`.
- **Carried over from a stale input.** An agent that reads a manifest, an earlier report or a
  cached snapshot and reports what it said — "the site has no posts" against a site with
  twenty — is quoting history, not measuring the site. §2.5b already says this about the
  environment; it holds for every finding.

So:

1. Each finding line carries its evidence — the command, the path, or the URL. A finding with
   no evidence line does not reach the report.
2. What the tier cannot reach is reported as `UNVERIFIED`, with the command the user can run,
   and is never counted in the totals or offered as a fix in Step 9.
3. When a check needs a number, take the number. Counting is one command; guessing costs the
   client a change that fixes nothing.

The aggregator enforces this: a finding arriving with no evidence is dropped and reported as
dropped, naming the agent — an agent that guesses should be visible, not silently trusted.
