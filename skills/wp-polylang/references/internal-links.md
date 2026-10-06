# Internal links inside translated content

What `pll-import.php`'s link-rewrite pass changes, the rules it follows, and what `pll-verify.php`
fails on. The summary is in `../SKILL.md`.

## The defect

A source post's content, or an ACF reference field, may link to another source-language post by
its own permalink. That href is copied verbatim into the counterpart with the rest of the content
— nothing parses it — so after import it still points at the SOURCE-language post: a button on
the English page sends the visitor back to the Spanish site. It is the same defect as an
untranslated menu item, in post content instead of a menu.

A `custom` menu item (a literal href, not an object id and type) has the same shape. A duplicated
menu produces exactly this, and a `custom` item whose URL is one of the site's own permalinks
needs re-pointing like any other link.

## The pass

The link-rewrite pass runs **after every post's counterpart exists**, for the same reason the
parent fixup does: a link's target may gain its counterpart later than the post containing the
link, on a run where the linking post itself was skipped by hash. It therefore runs over **every
target-language post with a source-language counterpart**, not only the posts written in the
current run. It is idempotent and cheap, so it runs unconditionally on every import, including a
real site's already-translated pages. It applies to:

- same-host `href="..."` attributes inside `post_content`;
- ACF/SCF `link` (its `url` key — the `title` is translatable text and travels through the
  manifest instead), `page_link`, `post_object` and `relationship` fields, wherever they sit in
  the field structure, read from the SOURCE post every run (`acf-fields.md`);
- `custom` menu items in every target-language menu, whenever their URL resolves to a post.

## Rules

- **Same host only.** Compared by *host*, not by a `home_url()` string prefix —
  `url_to_postid()` itself tolerates a scheme mismatch (an `https://` href against an `http://`
  site still resolves), and a literal prefix test would not. A leading `www.` is ignored on both
  sides, as `url_to_postid()` ignores it. A different host is never touched.
- **Resolved with `url_to_postid()`.** A zero result means it is not a post URL (an archive, a
  term, the home page) and is left exactly as it is. A WooCommerce shop page's own permalink does
  **not** resolve through `url_to_postid()` even with the correct host — a limitation of
  WordPress's own resolver, not of this pass — so such links are left alone like any other
  non-post URL.
- **Re-pointed via `pll_get_post( $id, $target_lang )`.** If it returns nothing, the target has
  no counterpart yet: the link is left pointed at the source and `pllx_warn()` names both posts.
  A link into the other language is bad; a broken link is worse.
- **Query string and fragment are preserved**, and a root-relative href is written back
  root-relative (`/servicios/?x=1#contacto` keeps both parts). The one exception is the `p`,
  `page_id` and `attachment_id` arguments that identified the source post: they are dropped,
  because `url_to_postid()` matches them first and re-appending them would resolve back to the
  source.
- **Idempotent.** Every candidate rewrite is compared against the current value first, so a
  second run over unchanged content writes nothing and `post_content` stays byte-identical.

## What the verifier fails on

`pll-verify.php` check 9 audits the same condition on `post_content` as a **hard failure** — the
same severity as its menu-item check, for the same reason — and check 1 (menus) inspects
`custom` items whose URL resolves to a post as well as `post_type` and `taxonomy` items.
