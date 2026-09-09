# footer-columns

**Role:** footer, the full one. Wordmark and one sentence, two link columns, a
contact column with a real address, phone and email, and a legal line on its own
rule. Use it when the site has enough pages that a visitor might arrive at the
bottom still looking for one.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added. No devices at all, deliberately: a page whose ending
is a section that animates itself is a page that ended twice. The closing block
above it is the ending.

**Pick when:** more than six pages, or a business with a physical address, opening
hours or a phone number worth putting in front of people.

**Slots:** wordmark, blurb, `nav_N_label` and four `nav_N_link_M`/`nav_N_href_M`
pairs per column, contact_label, address_line, phone/phone_href, email, hours,
legal_line and two legal links.

**Notes:** contact details live in a real `<address>` with `tel:` and `mailto:`
links, so a phone can dial them. The ground is `--color-surface`, one step off
the page canvas, which separates the footer without a heavy rule.
