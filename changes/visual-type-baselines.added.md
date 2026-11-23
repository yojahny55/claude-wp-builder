- **Visual baselines now see colour and type.** `tests/checks/visual-baselines.sh` only
  photographed the motion fixtures, grey boxes that show layout moving but not a recoloured
  token or a swapped font. A colour-and-type page is now baselined at 1280 and 390 px, and
  four mutants of it — body text two grey steps lighter, the heading's font family, the
  button colour, the lead's size — must each differ from the baseline by more than the
  0.1% tolerance, so the baselines cannot quietly lose that sight. A one-step text tint
  measures 0% and is left to the computed-style checks. A failed run now also keeps the
  rendered shots for approval, its evidence folder is ignored by git, and CI uploads it:
  the upload step skipped it as a hidden path, so no failed visual run had ever shipped
  its diffs.
