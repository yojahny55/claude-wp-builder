# /wp-audit — Step 6.10

`commands/wp-audit.md` sends the run here at Step 6.10. Follow it in order; nothing in it is optional background.

§6.9 makes a *finding* a measurement. The same has to hold for the *fix*, and it is the half
that gets skipped: a page that still returns 200 after an edit proves the site did not break,
not that the defect is gone. The defect was on one record, one field, one template — reload
that one.

Every finding therefore carries the case that produced it, and the fix is re-measured on it:

| Finding shape | What to reload after the fix |
|---|---|
| a field on one post prints wrong | that post's permalink, not the archive |
| a template part misbehaves on some rows | the URL of a row that was wrong before |
| an option value reaches the rendered head | `curl` the page and read the head again |
| a query returns the wrong set | the same query, same arguments, and diff the ID list |

On one audited site a relationship field pointed at a deleted post, and the template painted an
empty card for it. Two pages using that template rendered correctly, because their fields held
no orphan. The fix could only be verified by finding the one record whose field held the
missing ID and reloading that page.

So: name the reproducing case when the finding is written, while the measurement is in hand.
Recovering it afterwards costs more than recording it, and a fix nobody could reproduce is a
fix nobody ran.

A fix whose reproducing case cannot be found is reported as `UNVERIFIED`, exactly like a
finding that could not be measured. It is not counted as resolved.
