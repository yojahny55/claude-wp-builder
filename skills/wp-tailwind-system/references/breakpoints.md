# Breakpoints

From the `wp-tailwind-system` skill: how a demo's media queries become Tailwind
variants. Mobile-first with Tailwind's own prefixes, never a hand-written `@media`.

## Name the breakpoints; never ship `max-[<n>px]:`

A demo converted from a design tool carries media queries at the FRAME widths it was
drawn at — 1599, 1023, 759 — and none of those is a default Tailwind stop. Translating
each one literally gives `max-[1599px]:`, `max-[1023px]:`, `max-[759px]:`, hundreds of
them, and that is a defect, not a detail:

- **It breaks anything the scanner cannot see.** Tailwind compiles a variant only while
  some scanned file uses it. Markup that lives in the DATABASE — a CF7 form, a widget, a
  block pattern — silently loses every rule the day the theme normalizes its variants.
  (This has shipped: a footer form lost its whole responsive layout that way.)
- **Each pair leaves a 1px dead band.** `max-[759px]` and a `min-width: 760px` rule agree
  only by luck; the arbitrary form invites off-by-one boundaries nobody re-checks.
- It is unreadable, and it makes every future width change a find-and-replace.

So: take the widths the demo actually switches at, declare them ONCE in `@theme`, and use
the named prefixes everywhere.

```css
@theme {
  --breakpoint-sm:  430px;
  --breakpoint-md:  760px;
  --breakpoint-lg: 1024px;
  --breakpoint-xl: 1281px;
  --breakpoint-3xl: 1600px;
}
```

```html
<!-- wrong -->
<div class="max-[1023px]:col-span-full max-[759px]:pt-5">
<!-- right: max-lg = below 1024, max-md = below 760 -->
<div class="max-lg:col-span-full max-md:pt-5">
```

Mind the boundary when converting: the demo's `max-width: 759px` is `≤ 759`, and `max-md`
with `--breakpoint-md: 760px` is `< 760`. Same rule — which is why each stop above is the
demo's width plus one (next section). Re-measure at the stop itself after the change — an
off-by-one here moves a whole layout one pixel early.

An arbitrary variant is acceptable only for a one-off width that is genuinely not a
breakpoint of the design (a single `max-[891px]:` where one field wraps). If it appears
more than twice, it is a breakpoint: name it.

## `max-width: N` in the demo is INCLUSIVE; `max-*` in Tailwind is EXCLUSIVE

A plain-CSS demo's `@media (max-width: Npx)` matches width N itself. Tailwind 4
compiles every `max-*` variant — named or arbitrary — as `width < N`, which
EXCLUDES it. Converting one into the other with the same number is a 1px bug at
exactly N, and N is very often a real device width (768, 1024): the two most
common desktop-first stops a demo declares.

**The rule: a demo's `max-width: Npx` becomes a `--breakpoint-*` stop set to `N+1`
in `@theme`, used through its named `max-*` variant.** The `+1` lives in the one
declaration, and the markup never repeats it. The arbitrary `max-[N+1px]:` form is
only for the one-off width of the previous section — a width the design does not
switch at. `min-width` needs no adjustment — CSS `min-width: N` is already inclusive
of N, and Tailwind's `min-*:` variants compile the same way, so they map straight
across.

```css
/* demo: @media (max-width: 768px) { … } and @media (max-width: 1024px) { … } */
@theme {
  --breakpoint-md: 769px;  /* not 768 — Tailwind's max-* is exclusive */
  --breakpoint-lg: 1025px; /* not 1024, same reason */
}
```

```html
<!-- demo: @media (max-width: 768px) { .nav { display: none } } -->
<!-- wrong: max-md: against the stock --breakpoint-md (768px) excludes width 768 -->
<!-- wrong: max-[768px]:hidden — the same off-by-one, as an arbitrary variant -->
<!-- right: --breakpoint-md: 769px declared in @theme above, then the named variant -->
<nav class="max-md:hidden">
```

Never adopt Tailwind's stock breakpoint scale (`sm: 640`, `md: 768`, `lg: 1024`,
`xl: 1280`) as-is against a demo that declares those same numbers as
`max-width` — the two disagree by exactly one pixel at the value that matters.
Re-measure the layout AT 768 and AT 1024 after converting, not only at 1440
and 390: those two widths are where the off-by-one hides, and a sweep that
only samples far from every breakpoint never lands on it.
