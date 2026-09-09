# Domain table

Vendored from `nextlevelbuilder/ui-ux-pro-max-skill` (MIT). Regenerate with
`bin/domains-import.sh`, which overwrites `domains.csv` in place, clones
`main` unpinned, and records the exact commit it imported in `SOURCE.txt` —
that file, not a version number here, is the source of truth for what was
actually vendored.

## What is here

One row per product category: the category name, the keyword list that matches
it against a client's documents, the landing-page pattern it wants, the things
it must consider, and upstream's own confidence in the record.

## What was refused, and why

That catalogue also ships a colour table and a typography table. Neither is
vendored, and neither should be.

Its colour table maps 192 product types onto 50 distinct primary colours, so
roughly four categories share each hex. Every general SaaS project it advises
gets the same blue. Its typography table pairs Playfair Display with Inter.
This plugin's fingerprint gate exists to refuse two clients the same palette and
type pair, and its type floor names Inter as the most-used face in machine
generated pages. Importing those tables would hand every client in a category
the same palette, which is the sameness the craft path exists to prevent.

Colour and type come from the client's own material, through
`references/design-md.md`. This table decides shape only.
