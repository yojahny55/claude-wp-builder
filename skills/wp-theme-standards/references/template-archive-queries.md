# wp-template — Archive ordering and pagination

The `wp-template` agent reads this when a template lists posts in an archive, directory or paginated custom query.

### Archive and directory ordering needs a tiebreaker

`'orderby' => 'date'` alone is not stable when several records share a `post_date` to the
second — which seeded content routinely does, since a seed script creates a batch of posts
in the same request. MySQL is free to return same-timestamp rows in a different order on
every query, so the same archive/directory page silently reshuffles between requests and
between page loads. Add `ID` as the tiebreaker whenever ordering by date:

```php
'orderby' => array( 'date' => 'DESC', 'ID' => 'DESC' ),
```

Only do this for date-based ordering. A query whose `orderby` is already something else —
`menu_order`, a specific field, the demo's own explicit sequence (see "A list's ORDER and
COUNT come from the demo" above) — is already deterministic and does not need it.

## Pagination

Use WordPress built-in pagination functions:

```php
<?php
// Simple numbered pagination
the_posts_pagination(array(
    'mid_size'  => 2,
    'prev_text' => '&laquo; Previous',
    'next_text' => 'Next &raquo;',
));
?>
```

For custom query pagination, use `paginate_links()`.
