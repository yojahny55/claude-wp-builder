- **`/wp-finalize` reports contact and social settings left empty.** When a demo had no
  Instagram link or phone number, the setting stayed empty and the header, footer or
  contact section rendered nothing in its place, so the client never learned the value was
  theirs to supply. Check 7 now lists every empty `social_*`, `contact_email`,
  `contact_phone`, `header_phone` and `business_address` setting under **Content pending**
  in the report. A `_<lang>` variant is skipped when its base exists. The item never turns
  the check into a FAIL, and it seeds no placeholder value a client could ship by mistake.
