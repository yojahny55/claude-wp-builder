# Responsive Images

Markup for each case in `SKILL.md` § Responsive Images.

## srcset and sizes Attributes

Provide multiple image resolutions so the browser picks the best one for the viewport and pixel density.

```html
<img
    src="image-800.jpg"
    srcset="image-400.jpg 400w,
            image-800.jpg 800w,
            image-1200.jpg 1200w"
    sizes="(min-width: 1024px) 50vw,
           (min-width: 768px) 75vw,
           100vw"
    alt="Descriptive alt text"
    loading="lazy"
>
```

## The `<picture>` Element

Use `<picture>` for art direction -- serving different crops or images per viewport.

```html
<picture>
    <source
        media="(min-width: 1024px)"
        srcset="hero-desktop.jpg"
    >
    <source
        media="(min-width: 768px)"
        srcset="hero-tablet.jpg"
    >
    <img
        src="hero-mobile.jpg"
        alt="Hero image description"
        loading="lazy"
    >
</picture>
```

## WordPress wp_get_attachment_image()

In WordPress templates, use the built-in function to output responsive images automatically.

```php
<?php
$image_id = prefix_get_field('hero_image');
if ($image_id) :
    // WordPress generates srcset automatically from registered image sizes
    echo wp_get_attachment_image($image_id, 'large', false, array(
        'class'   => 'hero__image',
        'loading' => 'lazy',
        'sizes'   => '(min-width: 1024px) 50vw, 100vw',
    ));
endif;
?>
```

If you have an image array (from ACF/SCF) instead of just the ID:

```php
<?php
$image = prefix_get_field('hero_image');
if ($image) :
?>
    <img
        src="<?php echo esc_url($image['url']); ?>"
        srcset="<?php echo esc_attr($image['sizes']['medium'] . ' 300w, ' . $image['sizes']['large'] . ' 1024w, ' . $image['url'] . ' ' . $image['width'] . 'w'); ?>"
        sizes="(min-width: 1024px) 50vw, 100vw"
        alt="<?php echo esc_attr($image['alt']); ?>"
        width="<?php echo esc_attr($image['width']); ?>"
        height="<?php echo esc_attr($image['height']); ?>"
        loading="lazy"
    >
<?php endif; ?>
```

## Lazy Loading

Add `loading="lazy"` to all images below the fold. Do NOT add it to the hero/LCP image (which should be preloaded instead).

```html
<!-- Hero image: NO lazy loading (it's the LCP element) -->
<img src="hero.jpg" alt="Hero" fetchpriority="high">

<!-- Below-the-fold images: lazy loaded -->
<img src="service.jpg" alt="Service" loading="lazy">
```
