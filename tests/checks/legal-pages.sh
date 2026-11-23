#!/usr/bin/env bash
# /wp-page legal creates the Privacy, Terms and Cookie Policy pages as drafts through
# skills/wp-page-run/scripts/legal-pages.php. This pins the contract the run follows: drafts
# only, recorded facts only, an existing page is never overwritten. The script's behaviour
# against a real WordPress is tests/checks/legal-pages-integration.sh.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

ref=skills/wp-page-run/references/legal.md
script=skills/wp-page-run/scripts/legal-pages.php
[ -f "$script" ] || fail "$script is missing"

need_token "$ref" '## Create and seed the legal pages'
need_token "$ref" 'skills/wp-page-run/scripts/legal-pages.php'
need_token "$ref" '**Never invent a fact.**'
need_token "$ref" '[[pending: <what is missing>]]'
need_token "$ref" 'overwrite it, and do not ask to.'
need_token "$ref" 'Nothing is published'
need_token "$ref" 'dry-run'
need_token "$ref" 'wp_cli.wrapper'
need_token "$script" "defined( 'ABSPATH' ) || exit;"
need_token "$script" "'post_status' => 'draft',"
need_token BACKLOG.md 'tests/checks/legal-pages-integration.sh'
if grep -n "'publish'" "$script" >/dev/null; then fail "$script publishes a page; legal drafts are reviewed before they go live"; fi
if grep -nE "wp_update_post|'post_content'" "$script" >/dev/null; then fail "$script writes post fields of an existing page; it must only fill the legal fields of its own drafts"; fi

require_tool php
php -l "$script" >/dev/null || fail "$script does not parse"
echo "PASS: legal pages are created as drafts, from recorded facts, never over an existing page"
