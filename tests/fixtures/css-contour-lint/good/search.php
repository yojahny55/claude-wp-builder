<?php defined( 'ABSPATH' ) || exit; ?>
<form role="search"><input type="search" name="q" aria-label="Search"><button type="button" data-search-clear aria-label="Clear">×</button></form>
<a class="rounded-lg border-0 shadow-[inset_0_0_0_1px_var(--color-accent)] px-4 py-2" href="#">Outline</a>
<a class="rounded-lg border bg-primary text-white px-4 py-2" href="#">Solid</a>
<div class="rounded-lg border p-6">A card is not a control.</div>
<style>
/* The fix itself: the attribute text here is a selector, not a field. */
input[type="search"]::-webkit-search-cancel-button { appearance: none; }
</style>
<script>document.querySelectorAll('input[type="search"]').forEach((el) => el.dataset.ready = '1');</script>
