# Responsive Images

Markup for each case in `SKILL.md` § Responsive Images.

## The hero (LCP) image: never lazy

The first image a visitor sees is the Largest Contentful Paint element. It gets
`fetchpriority="high"` and no `loading` attribute; `loading="lazy"` on it delays the
paint the page is graded on.

```html
<img
    src="hero-1200.jpg"
    srcset="hero-800.jpg 800w, hero-1200.jpg 1200w, hero-1800.jpg 1800w"
    sizes="(min-width: 1024px) 50vw, 100vw"
    width="1200" height="800"
    alt="Descriptive alt text"
    fetchpriority="high"
>
```

## Below the fold: lazy

Every other image carries `loading="lazy"`, plus `srcset`/`sizes` and `width`/`height`
so the browser reserves its box.

```html
<img
    src="service-800.jpg"
    srcset="service-400.jpg 400w, service-800.jpg 800w, service-1200.jpg 1200w"
    sizes="(min-width: 1024px) 33vw, (min-width: 768px) 50vw, 100vw"
    width="800" height="600"
    alt="Descriptive alt text"
    loading="lazy"
>
```

## The `<picture>` element: art direction only

Use `<picture>` only when the crop changes per viewport. The `loading` rule follows the
`<img>` inside it: a hero `<picture>` is not lazy.

```html
<picture>
    <source media="(min-width: 1024px)" srcset="hero-desktop.jpg">
    <source media="(min-width: 768px)" srcset="hero-tablet.jpg">
    <img src="hero-mobile.jpg" width="750" height="1000" alt="Hero image description" fetchpriority="high">
</picture>
```

## In a WordPress template

ACF/SCF image fields are generated with `return_format => 'array'` (`agents/wp-acf.md`),
so the field returns an array, not an ID. Pass its `ID` to `wp_get_attachment_image()`,
which writes `srcset`, `sizes`, `width` and `height` from the registered image sizes.
Passing the array itself prints nothing.

```php
<?php
$image = prefix_get_field('hero_image');
if (!empty($image['ID'])) :
    echo wp_get_attachment_image($image['ID'], 'large', false, array(
        'class'         => 'hero__image',
        'sizes'         => '(min-width: 1024px) 50vw, 100vw',
        'fetchpriority' => 'high',
        'loading'       => false, // the hero is the LCP image: no lazy-loading
    ));
endif;
?>
```

Below the fold, leave `loading` out: WordPress core adds `loading="lazy"` itself.

```php
<?php
$image = prefix_get_field('services_image');
if (!empty($image['ID'])) :
    echo wp_get_attachment_image($image['ID'], 'large', false, array(
        'class' => 'services__image',
        'sizes' => '(min-width: 1024px) 33vw, 100vw',
    ));
endif;
?>
```
