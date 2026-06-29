# CLAUDE.md

Reference notes on P4 programmability, NOS + P4 ASIC integration, and a
proof-of-concept lab. Documentation, not a software project — no build or
test step.

## Contents
- `README.md` — index into the topic docs
- `p4learn.md` — P4 learning resources
- `install.md` — native Mininet + BMv2 install path (bare-metal Linux)
- `examples.md` — validated NOS + P4 ASIC combinations
- `poc.md` — proof-of-concept lab options (Mininet+BMv2, RARE/freeRtr, SONiC-VS, Kind)
- `sample.p4` — minimal IPv6 LPM forwarder (v1model / BMv2)
- `sampleP4overview.md` — block-by-block walkthrough of sample.p4

## Behavior
- The user drives all decisions. Don't suggest directions unless asked.
- Don't make assumptions. If you're not confident in a claim, say so or
  validate it first. Don't hallucinate examples, integrations, or product
  capabilities — verify before stating.
- Don't repeat back what the user already said as if it's new.
- Distinguish clearly between what's verified and what's uncertain.

## Conventions
- Markdown files are reference material — don't restructure or re-comment
  without being asked.
- `sampleP4overview.md` cites line numbers/blocks in `sample.p4` — keep the
  two in sync if either changes.
- Concise and direct. No emojis in files.
- The user has networking domain expertise — don't over-explain fundamentals.

## Stack
P4, BMv2, Mininet, p4c, P4Runtime, Containerlab, Kind, SONiC, RARE/freeRtr, INT.
