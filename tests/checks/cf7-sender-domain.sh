#!/usr/bin/env bash
# CF7 sender: agents/wp-cf7.md wrote `blogname <admin_email>` into mail.sender and
# mail_2.sender unchecked. An admin_email on a free-mail or foreign domain fails SPF/DKIM/
# DMARC and the message is rejected or junked, and CF7's own validator flags it
# (email_not_in_site_domain), as it flags an autoresponder to an unprotected [your-email]
# (unsafe_email_without_protection). A real build shipped all three warnings.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

a=agents/wp-cf7.md
# Whitespace-tolerant: no 'sender' line reads admin_email, and every one uses \$sender.
if grep -Eq "'sender'[[:space:]]*=>.*get_option[[:space:]]*\([[:space:]]*'admin_email'" "$a"; then
  fail "$a still puts admin_email in the sender unchecked"
fi
senders=$(grep -Ec "'sender'[[:space:]]*=>" "$a" || true)
computed=$(grep -Ec "'sender'[[:space:]]*=>[[:space:]]*\\\\?\\\$sender[[:space:]]*," "$a" || true)
[ "$computed" -ge 2 ] && [ "$computed" = "$senders" ] \
  || fail "$a: $computed of $senders 'sender' lines use the computed site-domain sender (mail and mail_2 need it)"
grep -Fq "'wordpress@' . \\\$domain" "$a" || fail "$a does not fall back to wordpress@<site domain>"
grep -Fq 'gmail.com' "$a" || fail "$a does not warn on free-mail sender domains"
grep -Fq 'new WPCF7_ConfigValidator(' "$a" || fail "$a does not run CF7's configuration validator"
grep -Fq 'collect_error_messages(' "$a" || fail "$a does not surface the validator's messages"
grep -Fq 'unsafe_email_without_protection' "$a" || fail "$a does not name the unprotected [your-email] recipient warning"
grep -Fq 'never in the repository' "$a" || fail "$a lets SMTP credentials into the repository"
grep -Fq "wp_mail( get_option(\"admin_email\")" "$a" || fail "$a has no wp_mail delivery test"
grep -Fq 'email log' "$a" || fail "$a does not read the SMTP plugin's log after the test"

echo PASS
