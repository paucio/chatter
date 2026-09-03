---
name: code-review
description: >-
  Code-review checklist for this Rails 8 + Hotwire codebase. Triggers on
  /code-review and whenever reviewing a diff, a branch, a PR, or the whole app for design, correctness, security, and idiom. Covers SOLID, Ruby/Rails best
  practices, Hotwire (Turbo + Stimulus), and tests. Overwrites
  docs/self-review.md with findings ranked by importance, each with a fix and a
  "worth fixing" call against the PRD/CLAUDE scope.
---

# Rails code review

A review pass for **Chatter** (Rails 8.1, Hotwire, import maps, PostgreSQL,
Solid Cable). Goal: catch design and correctness problems, keep the code idiomatic and simple, and produce a report a human can act on.

## How to run it

Invoked by `/code-review [target]`. `target` is optional:
- omitted → the diff against `develop` (the integration branch)
- a path (`app/models/`) → just that path
- `all` → the whole app (`app/`, `config/routes.rb`, `db/migrate/`, `spec/`)
- a branch name or PR number → that branch's diff / that PR

1. Establish scope from `target` as above. For the default, run
   `git diff develop...HEAD --stat` then read the full diff.
2. Read the [PRD](../../../docs/PRD.md) and [CLAUDE.md](../../../CLAUDE.md) first so findings are measured against the intended design, not a guess.
3. Walk **every section** of [`REVIEW_CHECKLIST.md`](REVIEW_CHECKLIST.md) against the
   code in scope — starting with "Chatter-specific hotspots", which lists the
   concrete things most likely to be wrong in this codebase.
4. Run the automated gates and fold their output into the report:
   ```bash
   bin/rubocop
   bundle exec rspec
   bin/brakeman --quiet --no-pager
   bin/importmap audit
   ```
5. Write the report to `docs/self-review.md`, **always overwriting** whatever is
   there (this file is regenerated each run, not appended to). Use the format below.

Be specific: every finding names a file and line, says why it matters, and shows the fix. Skip nitpicks RuboCop already enforces. Distinguish "this is a bug" from "this is a smell" from "preference".

## Report format

Always write to `docs/self-review.md`, overwriting the existing file. Structure:

```markdown
# Self-review report

**Scope:** <what was reviewed> · **Date:** <YYYY-MM-DD> · **Commit:** <sha>

## Automated gates
| Gate | Result |
| --- | --- |
| RuboCop | pass / N offenses |
| RSpec | N examples, N failures |
| Brakeman | N warnings |
| importmap audit | clean / N |

## Findings

One numbered list, **ordered by importance** (most important first — security and
correctness above design above idiom). For each finding:

### N. <short title> — `file:line`
- **What:** one or two sentences on the problem.
- **Fix:** the concrete change to make.
- **Worth fixing:** one of `Fix` / `Optional` / `Skip`, followed by a one-line
  justification measured against [CLAUDE.md](../../../CLAUDE.md) and
  [docs/PRD.md](../../../docs/PRD.md):
  - `Fix` — breaks a functional requirement, a security hole, or a data-integrity
    bug; **or** violates a stated convention/guardrail or the "keep it simple"
    grading criterion. Either way it should be fixed before this is called done.
  - `Optional` — real improvement but the PRD's scope/assumptions (§3) make it
    low-value; fix only with time to spare.
  - `Skip` — out of scope per the PRD, or fixing it would over-build against
    "keep it simple". Record it so the omission is visibly deliberate.

## Decisions
What was fixed in this pass, what was deliberately left (with the `Skip` /
`Optional` reasoning), and follow-ups worth doing with more time.
```

If a checklist section's code is clean, say so in one line under Findings — don't
invent findings to fill the template.
