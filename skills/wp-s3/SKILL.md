---
name: wp-s3
description: Moves a WordPress site's media library to S3, or to any S3-compatible server such as MinIO, with Human Made's S3 Uploads plugin, through bundled scripts — installs the plugin with its vendor tree, writes s3-config.php and the endpoint mu-plugin, migrates wp-content/uploads with a transfer that verifies itself, sets up the AWS side (bucket, CloudFront with OAC, IAM role), and takes the site back off S3. Run through /wp-s3 and /wp-s3-media. Use when a site's uploads should be served from an S3 bucket or a CloudFront media domain with S3 Uploads, when configuring S3 Uploads against AWS or MinIO, migrating or verifying the media transfer, or reverting a site off S3. Not for backups to S3, WP Offload Media, or hosting a static site or demo on S3.
user-invocable: false
---

# wp-s3: WordPress media on S3

S3 Uploads (Human Made) registers `s3://` as a PHP stream wrapper, so WordPress writes to the
bucket through the ordinary filesystem calls. Three consequences decide whether it fits:

- It **does not use the REST API**, so it works on sites that block `/wp-json/`.
- Media URLs are **not stored in the database**: they are built from
  `S3_UPLOADS_BUCKET_URL` at render time. Changing the bucket URL is changing one constant,
  not a search-and-replace over `wp_posts`.
- It supports a **custom endpoint**, so the same configuration runs against AWS and against
  any S3-compatible server.

The scripts never activate the plugin and never enable rewriting. Both are one WP-CLI command
away and belong to whoever owns the maintenance window.

## The order

1. **Downloadable products.** Measure, do not ask:
   `wp post list --post_type=product --meta_key=_downloadable --meta_value=yes --format=count`.
   Non-zero, read "Paid downloadable products" under Known failures before configuring
   anything; zero, or no WooCommerce, carry on.
2. **The AWS side.** On AWS, read `references/aws.md` first: the bucket, CloudFront and the
   role have to exist before setup is useful.
3. **Configure** with `s3-setup.sh` (below). It proves the credentials against the bucket.
4. **Dry run** the migration: `s3-media.sh upload <wp-root> --dry-run`.
5. **Upload** with `s3-media.sh upload <wp-root>`. Re-run until it exits `0`; a repeated run
   only sends what is missing. If the same objects are reported missing twice, stop and read
   the error instead of running it a third time.
6. **Activate and enable**, in the maintenance window:
   `cd <wp-root> && wp plugin activate S3-Uploads && wp s3-uploads enable`.
7. **Follow up per plugin** — "After the migration" below.
8. **Work through the staging checklist** before doing any of it on production.

```bash
S3_UPLOADS_SECRET_VALUE='<secret>' bash "${CLAUDE_PLUGIN_ROOT}/skills/wp-s3/scripts/s3-setup.sh" \
    --wp-root /path/to/wordpress \
    --bucket '<bucket>' --region '<region>' \
    --bucket-url 'https://media.example.com' \
    --auth key --key '<access-key-id>'

bash "${CLAUDE_PLUGIN_ROOT}/skills/wp-s3/scripts/s3-media.sh" upload /path/to/wordpress --dry-run
bash "${CLAUDE_PLUGIN_ROOT}/skills/wp-s3/scripts/s3-media.sh" upload /path/to/wordpress
```

On a server with an IAM role, drop `--key` and the secret and pass `--auth instance`. For an
S3-compatible server, add `--endpoint 'https://s3.example.com'`.

**The secret travels in the environment, never in a flag.** Anything in `argv` is readable
by every user on the machine through `ps`, and lands in the shell history of whoever pasted
it.

## Scripts and templates

| File | Run or read | Arguments and environment | Exit codes |
|---|---|---|---|
| `scripts/s3-setup.sh` | Run, through `/wp-s3` | `--wp-root`, `--bucket`, `--region`, `--bucket-url`, `[--endpoint]`, `[--auth key\|instance]`, `[--key]`, `[--version 3.0.13]`, `[--unverified-download]`, `[--skip-plugin-install]`; the secret in `S3_UPLOADS_SECRET_VALUE` | `0` configured, and the credentials proved whenever a `vendor/` tree is there to prove them with; non-zero refused or failed, the reason on stderr |
| `scripts/s3-media.sh` | Run, through `/wp-s3-media` | `upload\|download <wp-root> [--dry-run]`; `S3_MEDIA_KEY` and `S3_MEDIA_SECRET` for a site that authenticates with an IAM role | `0` verified; `1` failed, or files missing on the other side; `2` usage, or the listing failed or came back empty on a download |
| `scripts/s3-revert.sh` | Run, through `/wp-s3 --revert` | `<wp-root> [--keep-remote-media]` | `0` done; `1` stopped, nothing renamed and the site still working; `2` usage |
| `scripts/check-credentials.php` | Run by `s3-setup.sh`; safe to run by hand to re-check | `<wp-root>` | `0` the bucket listed; `1` it could not; `2` the configuration could not be read |
| `scripts/lib-mirror.sh` | Sourced by `s3-media.sh`; never run by hand | | |
| `scripts/verify-transfer.py` | Called by `lib-mirror.sh`; never run by hand | `WP_S3_LIST_TIMEOUT`, seconds, default 300 | `0` everything arrived; `1` files missing or of the wrong size; `2` the listing failed |
| `scripts/read-s3-config.php` | Called by every script to parse `s3-config.php` without including it; never run by hand — its `--export` mode prints the secret | | |
| `templates/s3-config.php.tpl` | Read when changing what a constant does; `s3-setup.sh` fills it in as `<wp-root>/s3-config.php`, backing up the old copy, so a hand edit in a site lasts until the next setup run | | |
| `templates/s3-uploads-endpoint.php` | Read when changing the endpoint filter; `s3-setup.sh` copies it to `wp-content/mu-plugins/` | | |

## Requirements

| Requirement | Why |
|---|---|
| PHP ≥ 8.1 with `simplexml`, `json`, `pcre`, `curl`, `mbstring` | The AWS SDK the plugin bundles |
| `allow_url_fopen = On` | The plugin registers `s3://` as a URL-type stream wrapper |
| `composer` | S3 Uploads ships without `vendor/`. On a PHP with no `iconv` the install adds `--ignore-platform-req=ext-iconv` by itself |
| `git` | The plugin is cloned at a pinned commit and refused if the tag no longer points there. Without git the install stops: `--unverified-download` takes the tarball instead, which carries nothing that can be checked |
| `php` CLI, `python3` | All three scripts: `php` reads `s3-config.php` and lints every PHP file setup or revert writes; `python3` edits `wp-config.php`, writes the client's private configuration and compares both sides of a transfer |
| `curl`, `tar` | Setup, only on the `--unverified-download` path |
| A client binary named `mcli` or `mc`, on `PATH` | `/wp-s3-media`, and `/wp-s3 --revert` unless `--keep-remote-media` is passed: the revert brings the media back through `s3-media.sh download`, with a key pair. Install the standalone binary as `~/.local/bin/mcli`, not inside the plugin directory, which a plugin update replaces |
| WP-CLI | Optional. The credentials are proved by `scripts/check-credentials.php`, which does not need the plugin to be active |

## What the configuration sets, and why

| Constant | Value | Reason |
|---|---|---|
| `S3_UPLOADS_AUTOENABLE` | `false` | Activating the plugin must not move a file. Rewriting starts at `wp s3-uploads enable`, when someone is watching |
| `S3_UPLOADS_OBJECT_ACL` | `bucket-owner-full-control` | The plugin sends an ACL on every upload. New AWS buckets have ACLs disabled, and a public ACL fails the upload outright |
| `S3_UPLOADS_HTTP_CACHE_CONTROL` | `2592000` | 30 days. An edited image is written under a new name, so no URL ever changes meaning |
| `WC_LOG_DIR` | local path | WooCommerce logs are not media. In the bucket they cost storage and are one bad policy line away from being public |
| `WPCF7_UPLOADS_TMP_DIR` | local path | A form attachment that round-trips to S3 is slower and needlessly exposed |

`s3-config.php` is written `0640` and added to the site's `.gitignore`. Give it the web
server's group. `wp-config.php` is backed up as `wp-config.php.bak-<timestamp>` before the
`require` is inserted, and the insertion is idempotent.

## The transfer verifies itself

The transfer runs through `mcli mirror` — `mcli` is the client in every line below — and
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
copy from burying a newer one in the bucket. `mcli` exits non-zero for those refusals, so the
exit code cannot separate "declined to clobber" from "could not connect": a refusal is
counted and reported, any other `<ERROR>` line fails the run, and the comparison decides
whether the result is right either way.

**The comparison runs even when the transfer failed**, and especially then: a failure is
the moment the operator most needs to know how much of it landed. It cannot rescue the run
— a failed transfer stays failed whatever the comparison says — but "47 of 812 objects
arrived" is what makes the next run safe, and `mcli`'s own error says nothing about that.
The listing has a timeout of 300 seconds (`WP_S3_LIST_TIMEOUT`), because an unreachable
endpoint otherwise hangs with nothing to read.

Excluded from both directions: `wc-logs/*`, `cache/*`, `wio_backup/*`, `wrio/*`,
`wpcf7_uploads/*` — logs, caches, the image optimizer's untouched originals, and the form
attachments. None is ever served from a media URL. The last two are also the directories a
mistake in the bucket policy would expose, and a site migrating in arrives with years of
them: keeping them out of the bucket is the guard that does not depend on the policy being
right.

`mcli` is pointed at a **private configuration directory** (`MC_CONFIG_DIR`, `0700`, removed
when the script exits) rather than at `MC_HOST_<alias>`. The credentials in that URL are not
percent-decoded by `mcli` — measured — so a secret holding `/`, `@`, `+`, `%`, `#` or `?`
works only verbatim, and one holding `:` cannot be expressed in it at all. AWS secret keys are
base64, so `/` and `+` are ordinary. `mcli alias set` is not used either: it takes the secret
in `argv`, where `ps` shows it to every user on the machine.

**On a server with an IAM role there is no key pair to hand `mcli`.** `s3-media.sh` stops.
Use temporary credentials for that one transfer, in `S3_MEDIA_KEY` and `S3_MEDIA_SECRET`,
never written to disk — the script prints the exact commands. `wp s3-uploads
upload-directory` uses the role instead, but it only uploads, reports no summary (the result
has to be counted by hand), and so cannot serve a download or a revert.

## After the migration

| Plugin | What it needs |
|---|---|
| WooCommerce, **downloadable products** served from the bucket (free ones; paid ones stay off S3, see Known failures) | Settings → Products → Approved download directories: add `<bucket-url>/uploads/`. Set the download method to **Redirect**. Without the first, saving a product fails with "not in an approved directory"; without the second, the customer's download 404s |
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
| 14 | Cut the site off from the storage — stop the S3-compatible server, or on AWS deactivate the access key (or detach the role's policy) — then load a page and upload an image. Restore it afterwards. `wp s3-uploads disable` is not this test: it only stops rewriting URLs | The site still answers; images do not load; the upload fails with a visible admin error |

## Known failures

**`AccessControlListNotSupported` on the first upload.** The bucket has ACLs disabled and
the plugin sent one. `bucket-owner-full-control` is what the configuration ships and AWS
accepts it. If it still fails, set the bucket's Object Ownership to *bucket owner preferred*
and `S3_UPLOADS_OBJECT_ACL` to `private`, keeping Block Public Access on and serving through
CloudFront.

**Paid downloadable products.** With the *Redirect* method the customer receives the file's
public URL, and anyone holding that URL can fetch it. Kept private under
`woocommerce_uploads/`, the redirect returns `403`. Default: keep paid files off S3, in a
local directory outside `uploads` (S3 Uploads rewrites only `uploads`), listed under Approved
download directories, denied to direct requests the way `woocommerce_uploads` is, and served
with the **Force downloads** method. Signing CloudFront URLs is the other way, and it is
custom work this skill does not cover.

**`composer install` refuses the lock file: `ext-iconv` is missing.** Several
distributions ship a PHP without it. The dependency that declares it — Symfony's mbstring
polyfill, reached only through their console — never runs inside WordPress, so
`scripts/s3-setup.sh` adds `--ignore-platform-req=ext-iconv` by itself when PHP lacks iconv.
A plugin directory left without `vendor/` by a failed composer run is completed by running
setup again, not treated as an installed plugin.

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
Read it before the first run against AWS, and when media returns `403`.

## Reverting

`scripts/s3-revert.sh` disables rewriting, **downloads the media before removing the
configuration** — without `s3-config.php` there is no bucket, region or credential left to
fetch them with — deactivates the plugin, removes the `require`, and renames `s3-config.php`
and the mu-plugin to `.disabled` rather than deleting them. It deletes nothing in the
bucket. Two things it cannot undo, because they are site data: Elementor's stored URLs and
WooCommerce's download settings. It prints both commands, filled in.
