#!/usr/bin/env bash
set -euo pipefail
. tests/checks/lib/expand-command.sh; expand_command commands/wp-yolo.md; f=$EXPANDED
for token in 'transcribe' 'block' 'assets/fonts' '@font-face' 'role'; do
  grep -qi "$token" "$f" || { echo "FAIL: wp-yolo missing '$token'"; exit 1; }
done
grep -qi 'google fonts' "$f" || { echo "FAIL: wp-yolo does not state self-hosted-vs-Google-fonts rule"; exit 1; }
echo PASS
