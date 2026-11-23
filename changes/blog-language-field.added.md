- **Blog posts carry a language under the suffix strategy.** `/wp-page blog` now installs
  `templates/blog-language/blog-language.php` as `inc/blog-language.php` on suffix projects:
  a `post_language` select on posts and a filter that lists the visitor's language plus
  every post with no language on the blog index, post archives and search. Before, a
  one-page-per-every-language site listed every post in every language. Posts with no
  language stay listed everywhere, and Polylang projects are untouched.
