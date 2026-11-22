- **The impeccable detector follows the newest release.** Every call is now `npx -y impeccable@latest`
  instead of a major-version pin, on purpose. `bin/composition-gate.sh` refuses detector output it
  does not understand (a finding that is not an object, one missing `antipattern` or `file`, a
  `category` outside slop/quality or a `severity` outside warning/advisory) and exits 1 instead of
  passing it. The checks now fail on any numeric `impeccable@` pin.
