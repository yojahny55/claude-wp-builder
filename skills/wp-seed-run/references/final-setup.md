# /wp-seed — Phase 7

`commands/wp-seed.md` sends the run here at Phase 7 (Final Setup). Follow it in order; nothing in it is optional background.

## Contents

- Flush rewrite rules and cache
- Delete default WordPress content
- Set timezone
- Close comments by default
- Sweep for posts with no author

### Flush rewrite rules and cache

```bash
bash -c "$WP rewrite flush"
bash -c "$WP cache flush"
```

### Delete default WordPress content

Remove the default "Hello World" post, sample page, and sample comment — **but only
while they are still untouched defaults.**

These three are the one place this command deletes a record it does not own. Every other
record follows the Phase 1.5 rule: no `_<prefix>_seeded_content` marker means the client
owns it, leave it alone. WordPress ships these three, so they never carry the marker and
never will — which is why the rule has to be spelled differently for them rather than
skipped.

Repurposing the sample page is ordinary: it arrives at ID 2 with the slug `sample-page`,
and an editor turns it into About instead of deleting it and making a new one. An
unconditional `wp post delete 2 --force` on that site's second seed run destroys it
permanently — `--force` bypasses the trash, and the `|| true` that used to be here hid
that anything had happened. So each delete is gated on two signals that a shipped default
is still one: the original slug, and a `post_modified` still equal to `post_date`. An
edited slug or an edited body keeps the record.

```bash
bash -c "
for PAIR in '1:hello-world' '2:sample-page'; do
  ID=\${PAIR%%:*}; WANT=\${PAIR#*:}
  SLUG=\$($WP post get \$ID --field=post_name 2>/dev/null) || continue
  CREATED=\$($WP post get \$ID --field=post_date)
  TOUCHED=\$($WP post get \$ID --field=post_modified)
  if [ \"\$SLUG\" = \"\$WANT\" ] && [ \"\$CREATED\" = \"\$TOUCHED\" ]; then
    $WP post delete \$ID --force && echo \"deleted default post \$ID (\$WANT)\"
  else
    echo \"KEPT post \$ID: not an untouched default (slug=\$SLUG) -- the client owns it\"
  fi
done
"
```

The sample comment is gated the same way, on the author WordPress ships it with:

```bash
bash -c "
AUTHOR=\$($WP comment get 1 --field=comment_author 2>/dev/null) || exit 0
if [ \"\$AUTHOR\" = 'A WordPress Commenter' ]; then
  $WP comment delete 1 --force && echo 'deleted default comment 1'
else
  echo \"KEPT comment 1: author is '\$AUTHOR', not the WordPress default -- the client owns it\"
fi
"
```

Every `KEPT` line belongs in the Phase 8 report beside the field conflicts: a default that
survived is a record this command decided not to touch, which is the same kind of fact.

### Set timezone

```bash
bash -c "$WP option update timezone_string 'America/New_York'"
```

### Close comments by default

```bash
bash -c "$WP option update default_comment_status 'closed'"
```

### Sweep for posts with no author

The same query `/wp-finalize` Check 7 runs, with the same two exclusions (auto-drafts and
menu items, which WordPress itself leaves at 0). It must print `0`; anything else is a create
above that lost its `--post_author`, and the seed is not done until it is fixed:

```bash
bash -c "$WP db query \"SELECT COUNT(*) FROM \$($WP db prefix)posts WHERE post_author = 0 AND post_status != 'auto-draft' AND post_type != 'nav_menu_item';\""
```
