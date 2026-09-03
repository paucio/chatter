# CLAUDE.md

Guidance for AI assistants (and humans) working in this repo.

## What this is

**Chatter** — a real-time chat app built on a map. Users click the map to drop a pin; each pin is a chatroom; the right-hand panel shows the selected chatroom and lets you post messages. Chatrooms and messages persist across sessions.

See [`docs/PRD.md`](docs/PRD.md) for the full functional spec and [`docs/`](docs/) for the other deliverables (infrastructure estimate, self-review). **Keep it simple** is an explicit grading criterion — favor the smallest solution that fully meets the spec.

## Stack

- **Ruby** 3.4.x, **Rails** 8.1 (see [`.ruby-version`](.ruby-version))
- **PostgreSQL** via Active Record
- **Hotwire**: Turbo + Stimulus, **Import maps** (no Node build step for JS)
- **Tailwind CSS** via `tailwindcss-rails`
- **Solid Queue / Cache / Cable** (database-backed, no Redis)
- **Leaflet** for the map — the challenge requires using the provided map. Layout reference: https://codepen.io/riko11/pen/GExZzQ
- **RSpec** + Capybara + Selenium for tests
- **Kamal** + Docker for deploy

## Architecture decisions

- **Server-rendered, Hotwire-first.** No SPA, no client-side framework. Stimulus controllers are thin glue around Leaflet and form behavior only.
- **Real-time via Turbo Streams over Action Cable** (`solid_cable`). Posting a message broadcasts a `turbo_stream` append to everyone subscribed to that chatroom.
- **Data model** (keep it minimal):
  - `Chatroom` — `title`, `latitude`, `longitude`, `timestamps`. Title auto-assigned as
    `"Chatroom N"` on create.
  - `Message` — `belongs_to :chatroom`, `username`, `body`, `timestamps`.
  - No `User` model, no authentication. Username is just a string typed into the form, matching the mockup.
- **State**: persistence is the database. No `localStorage`, no session storage for domain data — "stored between sessions" means server-side.
- **Map <-> panel**: clicking the map POSTs a new `Chatroom`; clicking a marker
  navigates/streams the panel to that chatroom. The panel is a Turbo Frame.

Anything not locked down here is open — raise the question rather than guessing on a decision that affects the data model or the real-time design.

## Commands

```bash
bin/setup              # install deps, prepare DB
bin/dev                # run web + tailwind watcher (Procfile.dev)
bin/rails db:prepare   # create + migrate
bin/rails console

bundle exec rspec              # full test suite
bundle exec rspec spec/models  # a subset
bin/rubocop -a                 # autocorrect style (rails-omakase)
bin/ci                         # style + security gates (see config/ci.rb)
bin/brakeman                   # security scan
```

## Conventions

- **Style**: `rubocop-rails-omakase`. Run `bin/rubocop -a` before committing. Don't hand-fight the formatter.
- **Tests**: every model gets model specs; the core flows (drop pin, switch chatroom, post message, real-time delivery) get request or system specs. Write the test with the feature, not after.
- **Migrations**: reversible, one concern each. Never edit a migration that's been committed — add a new one.
- **JavaScript**: import maps only. Pin new libs with `bin/importmap pin <name>`. Keep Stimulus controllers small and behavior-focused; no business logic in JS.
- **Views**: ERB + Tailwind utility classes. Extract partials for anything rendered in a Turbo Stream so the stream and the initial render share one template.
- **Naming**: match the surrounding Rails conventions. RESTful controllers, standard resource routes.
- **Commits**: small, focused, present-tense subject lines. The graders read the history to see how the work was done.
- **Reviews**: run `/code-review` against a branch/diff before merging. The
project skill in `.claude/skills/code-review/` covers SOLID, Ruby/Rails idiom,
Hotwire, security, and tests, and writes the self-review report.

## Deliverables checklist

This repo is graded on four artifacts — keep them in sync with the code:

1. Source code + AI config (this file, the `/code-review` skill in `.claude/skills/`) — committed
2. [`docs/PRD.md`](docs/PRD.md) — 1–2 page technical PRD
3. [`docs/infrastructure.md`](docs/infrastructure.md) — deploy plan + cost table, ≥2 envs
4. [`docs/self-review.md`](docs/self-review.md) — review config + report + notes

## Guardrails

- Don't add authentication, user accounts, avatars, or presence unless asked.
- Don't introduce Redis, a JS bundler, or a frontend framework.
- Don't over-model the domain — two tables is the target.
- Don't deploy anything; the infrastructure piece is a written exercise.
- If a change touches the data model or real-time flow, flag it before implementing.
