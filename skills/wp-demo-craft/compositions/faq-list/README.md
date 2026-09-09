# faq-list

**Role:** faq. Native `<details>` disclosures on hairlines, heading held to the
left on wide screens so the questions read as a column rather than a page-wide
accordion. No JavaScript at all: the browser already ships this widget with
keyboard support, and in-page search can open a closed answer.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added. Devices: reveal on the block, stagger 60. The
open/close marker rotates 45 degrees, which is `transform` only.

**Pick when:** there are four to six questions the client is genuinely asked. Skip
when the list would be marketing copy phrased as questions.

**Slots:** kicker, title, lede, then `q1`..`q5` and `a1`..`a5`. The first item
ships `open`, so the section is never a stack of closed bars with nothing to read.

**Notes:** the brief specified `dl.faq-list__list`. It is a `div` instead, because
`<dl>` may only contain `dt`, `dd`, `div`, `script` and `template`, so
`dl > details` is invalid HTML and the accessibility tree drops the list
semantics anyway. The shared `name="faq-list"` makes the group exclusive natively
(one answer open at a time) in browsers that support it, and degrades to
independent disclosures in those that do not.
