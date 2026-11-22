# wp-template — CSS backgrounds

The `wp-template` agent reads this when a section paints an image through CSS (`background-image`).

### CSS backgrounds (MANDATORY when a section paints an image through CSS)

An image printed as a `background-image` is not an `<img>`, so nothing that rewrites `<img>` tags reaches it — including Robin Image Optimizer in its default `picture` delivery mode, which is what most optimized sites run. A background left alone can serve a megabyte where its WebP sibling is a third of that.

Print the background with the starter helper `prefix_background_image( $url )` (from `inc/performance.php`), never a bare `url()`:

```php
$image = prefix_get_field('hero_image');
?>
<section class="hero" style="<?php echo prefix_background_image( $image['url'] ?? '' ); ?>">
```

- The helper emits `background-image:url(…)` first and an `image-set()` second, so a browser without `image-set()`/`type()` (Safari 16 and older) keeps the plain URL and the background never disappears.
- It adds the WebP branch **only when the sibling file exists on disk**, and it resolves local uploads URLs only.
- Its return value is already escaped — print it raw, do **not** wrap it in `esc_attr()`.
- Each browser requests the URL it understands, so this is safe behind a full-page cache. Never solve this with `Vary: Accept` from a template.
- Prefer an `<img>` with `object-fit: cover` where the layout allows one: it gets a `srcset`, which a background never has.

#### A decorative background below the fold is deferred (MANDATORY)

`background-image` has no `loading` attribute, so the browser downloads every background it parses with the first paint — a footer band, a map panel or a decorative section sitting thousands of pixels down is on the critical path exactly like the hero. On a real build four such backgrounds were 120–320KB each, and holding them back took the first paint from 3.7MB to 1.4MB with no visible change.

Print those with `prefix_lazy_background_attr( $url )` instead, which returns attributes rather than a style value:

```php
<section class="cta" <?php echo prefix_lazy_background_attr( $image['url'] ?? '' ); ?>>
```

- **Never the hero.** It is the LCP element, and deferring it moves the largest paint later by whatever the observer waits. The hero keeps `prefix_background_image()` and its preload.
- Pass `true` as the second argument for an element that is *inside* the first viewport but not yet visible — a carousel slide behind the first one. An observer fires on those immediately, so they are painted after the load event instead.
- The helper registers each declaration and `prefix_print_lazy_background_noscript()` repeats all of them inside a `<noscript><style>` block on `wp_footer`, so a visitor with JavaScript disabled sees the same page. Do not remove that hook while the helper is in use.
- The key travels in a data attribute and **not** in `id`, because these sections usually carry one already and an HTML parser drops a second `id` on the same element — which leaves the noscript rule pointing at nothing while the page still looks correct with JavaScript on.
