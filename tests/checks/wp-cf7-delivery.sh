#!/usr/bin/env bash
# Submit a real Contact Form 7 form to a real WordPress and assert the mail left the site.
#
# agents/wp-cf7.md contracts the form markup and the branded email template, and
# tests/checks/wp-cf7.sh greps that those contracts are still written down. What no grep
# could tell you is whether a submission is accepted, whether an invalid one is refused, or
# whether anything was actually sent -- and a contact form that renders perfectly and
# delivers nothing is the defect that costs a client real enquiries before anyone notices.
#
# I06's own completion check names this: "an intentionally broken carousel, incorrect
# colour, and failed form delivery each fail the appropriate check". This is the third.
#
# The sink is a must-use plugin on `pre_wp_mail` -- the same seam /wp-clone Step 5.5
# captures mail at, and for the same reason: it short-circuits core's own send, so nothing
# escapes even if a plugin is reactivated. Nothing here can reach a real inbox.
#
# SKIPs unless WP_FIXTURE=1, like the other fixture-backed checks: provisioning downloads
# WordPress, and making that the price of running the suite means people stop running it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

if [ "${WP_FIXTURE:-0}" != "1" ]; then
  echo "SKIP: set WP_FIXTURE=1 to provision a disposable WordPress and run this"
  exit 0
fi

prov=tests/fixtures/wp/provision.sh
setup=tests/fixtures/wp/cf7-setup.php
for f in "$prov" "$setup"; do
  [ -r "$f" ] || fail "$f is missing or unreadable"
done
command -v curl >/dev/null 2>&1 || fail "curl is not on PATH; this check posts a real submission"

DIR=""
SERVER_PID=""
cleanup() {
  status=$?
  # The server first: a fixture directory cannot be removed from under a running PHP
  # process cleanly, and a stranded `wp server` holds its port for the next run.
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  [ -n "$DIR" ] && bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || true
  exit $status
}
trap cleanup EXIT INT TERM

env_out=$(bash "$prov") || fail "could not provision a WordPress fixture"
DIR=$(printf '%s\n' "$env_out" | sed -n "s/^export WP_FIXTURE_DIR='\(.*\)'$/\1/p")
[ -n "$DIR" ] || fail "the provisioner printed no WP_FIXTURE_DIR"

setup_out=$(wp --path="$DIR" --allow-root eval-file "$setup" 2>&1) || {
  echo "$setup_out" | sed 's/^/  /'
  fail "could not create the fixture form"
}
FORM_ID=$(printf '%s' "$setup_out" | sed -n 's/^FORM_ID=//p')
PAGE_URL=$(printf '%s' "$setup_out" | sed -n 's/^PAGE_URL=//p')
PAGE_ID=${PAGE_URL##*page_id=}
[ -n "$FORM_ID" ] || { echo "$setup_out" | sed 's/^/  /'; fail "the setup printed no FORM_ID"; }
[ -n "$PAGE_ID" ] || fail "could not derive the container post id from $PAGE_URL"

# A port the kernel hands out, rather than a fixed one two concurrent runs would fight over.
PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
wp --path="$DIR" --allow-root server --host=127.0.0.1 --port="$PORT" >/tmp/wp-cf7-server.log 2>&1 &
SERVER_PID=$!

up=""
for _ in $(seq 1 40); do
  if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || true)" = "200" ]; then
    up=1
    break
  fi
  sleep 1
done
[ -n "$up" ] || { tail -5 /tmp/wp-cf7-server.log | sed 's/^/  /'; fail "the fixture site never answered on port $PORT"; }

endpoint="http://127.0.0.1:$PORT/?rest_route=/contact-form-7/v1/contact-forms/$FORM_ID/feedback"
sink="$DIR/wp-content/mail-sink.log"
lines() { [ -f "$sink" ] && wc -l < "$sink" | tr -d ' ' || echo 0; }

# CF7 refuses a submission with no unit tag, which is the hidden field its own rendered form
# carries. Posting without it returns wpcf7_unit_tag_not_found and never reaches validation
# -- so a check that omitted it would be asserting on CF7's request guard rather than on
# whether the form works.
post() {
  curl -s -X POST "$endpoint" \
    -F "_wpcf7=$FORM_ID" \
    -F "_wpcf7_unit_tag=wpcf7-f$FORM_ID-p$PAGE_ID-o1" \
    -F "_wpcf7_container_post=$PAGE_ID" \
    -F "your-name=$1" -F "your-email=$2" -F "your-message=$3"
}

ok=0
t() { # t <label> <condition-result>
  if [ "$2" = "1" ]; then echo "  ok   [$1]"; ok=$((ok + 1)); else echo "  FAIL [$1]"; return 1; fi
}

# --- a valid submission is accepted, and the mail actually leaves -----------------------
before=$(lines)
valid=$(post "Ana" "ana@example.invalid" "Hola")
case "$valid" in
  *'"status":"mail_sent"'*) t "a valid submission is accepted" 1 ;;
  *) echo "  $valid"; fail "a valid submission was not accepted" ;;
esac

after=$(lines)
[ "$after" -gt "$before" ] || { echo "  $valid"; fail "the submission was accepted but no mail reached the sink -- a form that renders and delivers nothing"; }
t "the mail reached the sink" 1

# The recipient and the interpolated body, not merely that something was sent: a mail with
# the right shape and the wrong address is the failure this is for.
last=$(tail -1 "$sink")
case "$last" in
  *'"to":"owner@example.invalid"'*) t "addressed to the form's recipient" 1 ;;
  *) echo "  $last"; fail "the captured mail is not addressed to the form's recipient" ;;
esac
# Anchored to the message FIELD, not to the line. Matching 'Ana' anywhere in the captured
# JSON passed while the body carried no submitted values at all, because the subject
# template is "Fixture: [your-name]" and supplied the match on its own -- found by
# mutation. The body is the half a client actually reads, and an assertion satisfied by
# the subject cannot see it go empty.
body=$(printf '%s' "$last" | sed -n 's/.*"message":"\(.*\)","at".*/\1/p')
[ -n "$body" ] || { echo "  $last"; fail "the captured mail has no message body"; }
case "$body" in
  *'Hola'*) t "the submitted message reached the body" 1 ;;
  *) echo "  body: $body"; fail "the captured mail body does not carry the submitted message" ;;
esac
case "$body" in
  *'ana@example.invalid'*) t "the submitter's address reached the body" 1 ;;
  *) echo "  body: $body"; fail "the captured mail body does not carry the submitter's address" ;;
esac
case "$last" in
  *'"subject":"Fixture: Ana"'*) t "the subject interpolated the submitted name" 1 ;;
  *) echo "  $last"; fail "the captured mail subject did not interpolate the name" ;;
esac

# --- an invalid submission is refused, and sends nothing --------------------------------
before=$(lines)
invalid=$(post "Ana" "" "Hola")
case "$invalid" in
  *'"status":"validation_failed"'*) t "a submission missing a required field is refused" 1 ;;
  *) echo "  $invalid"; fail "a submission with an empty required email was not refused" ;;
esac
case "$invalid" in
  *'"field":"your-email"'*) t "the refusal names the offending field" 1 ;;
  *) echo "  $invalid"; fail "the refusal does not name your-email" ;;
esac

after=$(lines)
[ "$after" -eq "$before" ] || fail "a refused submission still sent mail -- validation that reports an error and delivers anyway is worse than no validation"
t "a refused submission sends nothing" 1

echo "PASS: CF7 accepts, refuses and delivers correctly in a real WordPress ($ok assertions)"
