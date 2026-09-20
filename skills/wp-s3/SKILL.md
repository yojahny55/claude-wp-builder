---
name: wp-s3
description: Move a WordPress site's media to S3 with the S3 Uploads plugin — installs the plugin with its vendor tree, writes s3-config.php and the endpoint mu-plugin, migrates the existing library with a transfer that verifies itself, and reverses the whole thing. Use when the user wants uploads on S3, object storage, MinIO or any S3-compatible server, mentions S3 Uploads, offloading media, a media CDN on CloudFront, or asks to sync wp-content/uploads with a bucket. Run through /wp-s3 and /wp-s3-media.
user-invocable: false
---

# wp-s3: WordPress media on S3

## What this skill does

1. **Installs** S3 Uploads (Human Made) with its `vendor/` tree, and leaves it deactivated
2. **Writes** `s3-config.php` at the site root and hooks it into `wp-config.php`
3. **Installs** an mu-plugin that points the plugin at an S3-compatible endpoint, and does
   nothing on AWS
4. **Migrates** `wp-content/uploads` to the bucket, and **verifies** that every byte arrived
5. **Brings the media back** and unhooks the configuration when the site leaves S3

It does not activate the plugin and does not enable rewriting. Both are one WP-CLI command
away and belong to whoever owns the maintenance window.

## Why this plugin

S3 Uploads registers `s3://` as a PHP stream wrapper, so WordPress writes to the bucket
through the ordinary filesystem calls. That has three consequences worth knowing before
choosing it:

- It **does not use the REST API**, so it works on sites that block `/wp-json/`.
- Media URLs are **not stored in the database**: they are built from
  `S3_UPLOADS_BUCKET_URL` at render time. Changing the media domain is changing one
  constant, not a search-and-replace over `wp_posts`.
- It supports a **custom endpoint**, so the same configuration runs against AWS and against
  any S3-compatible server.

## Requirements

| Requirement | Why |
|---|---|
| PHP ≥ 8.1 with `simplexml`, `json`, `pcre`, `curl`, `mbstring` | The AWS SDK the plugin bundles |
| `allow_url_fopen = On` | The plugin registers `s3://` as a URL-type stream wrapper |
| `composer` | Releases since 3.0.10 ship without `vendor/`. On a PHP with no `iconv` the install adds `--ignore-platform-req=ext-iconv` by itself |
| `curl`, `tar`, `python3` | The setup script |
| A client binary named `mcli` or `mc` | Only for `/wp-s3-media` |
| WP-CLI | Optional. The credentials are proved by `scripts/check-credentials.php`, which does not need the plugin to be active |

## How to use

Configure a site:

```bash
S3_UPLOADS_SECRET_VALUE='<secret>' bash <path-to-skill>/scripts/s3-setup.sh \
    --wp-root /path/to/wordpress \
    --bucket '<bucket>' --region '<region>' \
    --bucket-url 'https://media.example.com' \
    --auth key --key '<access-key-id>'
```

On a server with an IAM role, drop `--key` and the secret and pass `--auth instance`. For an
S3-compatible server, add `--endpoint 'https://s3.example.com'`.

**The secret travels in the environment, never in a flag.** Anything in `argv` is readable
by every user on the machine through `ps`, and lands in the shell history of whoever pasted
it.

Migrate the library, and check first:

```bash
bash <path-to-skill>/scripts/s3-media.sh upload /path/to/wordpress --dry-run
bash <path-to-skill>/scripts/s3-media.sh upload /path/to/wordpress
```

Then, and only then:

```bash
cd /path/to/wordpress && wp plugin activate S3-Uploads && wp s3-uploads enable
```

Reverse everything:

```bash
bash <path-to-skill>/scripts/s3-revert.sh /path/to/wordpress
```

## What the configuration sets, and why

| Constant | Value | Reason |
|---|---|---|
| `S3_UPLOADS_AUTOENABLE` | `false` | Activating the plugin must not move a file. Rewriting starts at `wp s3-uploads enable`, when someone is watching |
| `S3_UPLOADS_OBJECT_ACL` | `bucket-owner-full-control` | The plugin sends an ACL on every upload. AWS has had ACLs disabled by default since 2023, and a public ACL fails the upload outright |
| `S3_UPLOADS_HTTP_CACHE_CONTROL` | `2592000` | 30 days. An edited image is written under a new name, so no URL ever changes meaning |
| `WC_LOG_DIR` | local path | WooCommerce logs are not media. In the bucket they cost storage and are one bad policy line away from being public |
| `WPCF7_UPLOADS_TMP_DIR` | local path | A form attachment that round-trips to S3 is slower and needlessly exposed |

`s3-config.php` is written `0640` and added to the site's `.gitignore`. Give it the web
server's group. `wp-config.php` is backed up as `wp-config.php.bak-<timestamp>` before the
`require` is inserted, and the insertion is idempotent.

## The transfer verifies itself

`mcli mirror` can exit `0` without having transferred everything. It was measured **writing
7 of 38 objects with no warning**, and printing its summary table while the storage backend
was down. The summary is printed on failure too, so neither it nor the exit code is evidence
that the media moved.

`scripts/lib-mirror.sh` therefore checks the result instead of the report:
`scripts/verify-transfer.py` lists both sides and compares names and sizes. An upload must
account for every local file; a download for every object. Extra files on the other side are
not a failure — that is what an environment nobody migrated in this run looks like.

Neither direction ever passes `--overwrite` or `--remove`. A file already on the other side
is refused and reported, which is what makes a second run safe and what stops a stale local
copy from burying a newer one in the bucket. The client exits non-zero for those refusals,
so the exit code cannot separate "declined to clobber" from "could not connect": a refusal
is counted and reported, any other `<ERROR>` line fails the run, and the comparison decides
whether the result is right either way.

**The comparison runs even when the transfer failed**, and especially then: a failure is
the moment the operator most needs to know how much of it landed. It cannot rescue the run
— a failed transfer stays failed whatever the comparison says — but "47 of 812 objects
arrived" is what makes the next run safe, and the client's own error says nothing about
that. The listing has a timeout of 300 seconds (`WP_S3_LIST_TIMEOUT`), because an
unreachable endpoint otherwise hangs with nothing to read.

Excluded from both directions: `wc-logs/*`, `cache/*`, `wio_backup/*`, `wrio/*`,
`wpcf7_uploads/*` — logs, caches, the image optimizer's untouched originals, and the form
attachments. None is ever served from a media URL. The last two are also the directories a
mistake in the bucket policy would expose, and a site migrating in arrives with years of
them: keeping them out of the bucket is the guard that does not depend on the policy being
right.

The client is pointed at a **private configuration directory** (`MC_CONFIG_DIR`, `0700`,
removed when the script exits) rather than at `MC_HOST_<alias>`. The credentials in that
URL are not percent-decoded by the client — measured — so a secret holding `/`, `@`, `+`,
`%`, `#` or `?` works only verbatim, and one holding `:` cannot be expressed in it at all.
AWS secret keys are base64, so `/` and `+` are ordinary. `mcli alias set` is not used
either: it takes the secret in `argv`, where `ps` shows it to every user on the machine.

**On a server with an IAM role there is no key pair to hand the client.** `/wp-s3-media`
stops and offers two ways out: temporary credentials in the environment for that one
transfer, or `wp s3-uploads upload-directory`, which uses the role but reports no summary,
so the result has to be counted by hand.

## After the migration

| Plugin | What it needs |
|---|---|
| WooCommerce, **downloadable products** | Settings → Products → Approved download directories: add `<bucket-url>/uploads/`. Set the download method to **Redirect**. Without the first, saving a product fails with "not in an approved directory"; without the second, the customer's download 404s |
| Elementor | `wp elementor replace-urls '<site>/wp-content/uploads' '<bucket-url>/uploads'` then `wp elementor flush-css`. Elementor stores absolute URLs inside its own data and regenerates its CSS straight into the bucket afterwards |
| Robin Image Optimizer | Nothing. It optimizes and writes `.webp` into the bucket; its backups stay private |
| Polylang | Nothing |
| Contact Form 7 | Covered by `WPCF7_UPLOADS_TMP_DIR`. Still send one test submission with an attachment |
| Anything else that writes into `uploads` | Check it one at a time on staging. If its files must be public, its path has to be added to the bucket policy |

## Staging checklist

Run all of it on staging before production. The first row is the one that fails.

| # | Check | Expected |
|---|---|---|
| 1 | Upload an image from Media → Add new | No error. `AccessControlListNotSupported` or `AccessDenied` means the ACL question below |
| 2 | Its URL | Starts with the bucket URL |
| 3 | `ls wp-content/uploads/<year>/<month>/` | The file is not on disk |
| 4 | List the bucket prefix | Original plus every thumbnail |
| 5 | Open the URL in a private window | It loads |
| 6 | `curl -I <bucket-url>/uploads/wc-logs/` | `403` |
| 7 | Change a product image; view the product and its gallery | Served from the bucket |
| 8 | Rotate an image and save | New files with an `-e<timestamp>` suffix |
| 9 | Delete an image permanently | Original and thumbnails gone from the bucket |
| 10 | Edit and save an Elementor page, console open | Saves, no CORS error |
| 11 | Submit a Contact Form 7 form with an attachment | The mail arrives with the attachment |
| 12 | Force a WooCommerce log entry | It lands in `wc-logs-local/`, not in the bucket |
| 13 | Buy a downloadable product | The download works |
| 14 | Take S3 away from the site | The site still answers; images do not load; uploads fail with a visible admin error |

## Known failures

**`AccessControlListNotSupported` on the first upload.** The bucket has ACLs disabled and
the plugin sent one. `bucket-owner-full-control` is what the configuration ships and AWS
accepts it. If it still fails, set the bucket's Object Ownership to *bucket owner preferred*
and `S3_UPLOADS_OBJECT_ACL` to `private`, keeping Block Public Access on and serving through
CloudFront.

**Paid downloadable products have no clean answer with this plugin.** With the *Redirect*
method the customer receives the file's public URL, and anyone holding that URL can fetch
it. Kept private under `woocommerce_uploads/`, the redirect returns `403`. Either keep those
files off S3, or sign CloudFront URLs — custom work. Confirm whether the site sells
downloadables **before** configuring anything.

**`composer install` refuses the lock file: `ext-iconv` is missing.** Several
distributions ship a PHP without it. The dependency that declares it — Symfony's mbstring
polyfill, reached only through their console — never runs inside WordPress, so
`scripts/s3-setup.sh` adds `--ignore-platform-req=ext-iconv` by itself when `php -m` does
not list iconv. If a composer run failed before that existed, the plugin directory is
there without `vendor/`: run the setup again and it completes the install rather than
treating the directory as an installed plugin.

**`'s3-uploads' is not a registered wp command.`** That subcommand only exists while the
plugin is active, and setup leaves it deactivated on purpose. It is not what proves the
credentials — `scripts/check-credentials.php` does, through the SDK the plugin bundles,
with the plugin off. After activating, `wp s3-uploads verify` works as usual.

**A missing image after the migration, `403` in the network panel.** A path that is not in
the bucket policy. Add it there; do not make the bucket public.

**The site is slow and image-less.** The object storage is unreachable. The site does not go
down — pages answered in 1.8–7.0s against a stopped backend, `wp-admin` still redirected,
no fatals — but media-heavy pages took roughly five times longer. On AWS, CloudFront's cache
absorbs this, which is why its TTLs are long.

## AWS

`references/aws.md` holds the infrastructure side: bucket settings, lifecycle rule,
CloudFront with OAC, the bucket policy that keeps private paths private, the IAM policy,
networking, and what to hand over to whoever configures WordPress.

## Reverting

`scripts/s3-revert.sh` disables rewriting, **downloads the media before removing the
configuration** — without `s3-config.php` there is no bucket, region or credential left to
fetch them with — deactivates the plugin, removes the `require`, and renames `s3-config.php`
and the mu-plugin to `.disabled` rather than deleting them. It deletes nothing in the
bucket. Two things it cannot undo, because they are site data: Elementor's stored URLs and
WooCommerce's download settings. It prints both commands, filled in.
