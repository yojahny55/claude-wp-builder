# GEO citability rubric

Part of the `wp-audit-geo-standards` skill (§5). The rubric is for **generation**:
`/wp-section` and `/wp-seed` authors apply it when writing copy. No GEO code scores it, so
the auditor reports nothing against it.

Citability is a property of the **copy**, not the markup. It scores how likely a
generative engine is to lift a passage verbatim. Weights:

| Component | Weight | What it means |
|---|---|---|
| Answer-block quality | 30% | A direct 1–2 sentence answer opens the section ("X is…") |
| Self-containment | 25% | The passage reads correctly with no surrounding context |
| Structural readability | 20% | Question-based H2s, short paragraphs, tables for 3+ comparisons |
| Statistical density | 15% | Named numbers, units, dates sourced to first-party data |
| Uniqueness | 10% | Original data or framing, not a restatement of the consensus |

Concrete rules:

- **Optimal extractable passage length: 134-167 words.** Below that the engine has too
  little to quote; above it gets truncated mid-argument.
- Open every section with a 1–2 sentence answer before any elaboration. Do not bury the
  answer under a definition parade.
- Phrase H2s as questions where the content answers one (`What does X cost?`).
- Use a table whenever three or more things are compared; prose comparisons are not
  extractable as a unit.
- Name sources and dates inline (`per the 2025 WordPress project survey…`).
- Prefer first-party data — measured numbers we own — over adjectives.
- One idea per passage; a section that answers two questions gets split.

## A rewrite, weak to strong

Weak — an answer an engine cannot lift:

> ## Our pricing
>
> We believe in fair, transparent pricing for all our customers. Every job is different,
> which is why we always take the time to understand your needs before giving a price. Our
> experienced team uses only quality parts. Contact us today to find out how we can help
> with your plumbing emergency!

No answer, no number, a heading that is not the question, and nothing that reads correctly
on its own.

Strong — 146 words, quotable whole:

> ## How much does an emergency plumber cost?
>
> An emergency call-out costs €95 for the first hour, then €45 for each additional half
> hour, including weekends and public holidays. Parts are billed at supplier price with no
> markup, and every quote is given in writing before work starts. Most emergency jobs — a
> burst pipe, a blocked drain, a failed water heater valve — are finished within ninety
> minutes, so the typical bill lands between €95 and €185 before parts. Night call-outs
> between 22:00 and 07:00 add a flat €40. We cover the whole metropolitan area within
> forty-five minutes of the call, measured across 1,240 call-outs in 2025. If the problem
> cannot be fixed on the first visit, the second visit carries no call-out charge. Payment
> is by card on completion, and the invoice itemises labour, parts and travel separately.
> Call the number at the top of this page and a dispatcher answers, not a voicemail.

What moved the score: the heading is the question (structural readability); the first
sentence is the answer (answer-block quality); every figure is named, with a unit and a
date (statistical density); the response time is first-party data (uniqueness); and the
passage needs no surrounding page to make sense (self-containment).
