# Self-review report

**Scope:** whole app — `app/`, `config/routes.rb`, `config/`, `db/migrate/`, `.github/workflows/`, `spec/` · **Date:** 2026-09-03 · **Commit:** `f1ef803`

## How this review was run

Produced by the project's `/code-review` skill
([`.claude/skills/code-review/`](../.claude/skills/code-review/)):

- **Config:** [`SKILL.md`](../.claude/skills/code-review/SKILL.md) defines the
  workflow and this report's format;
  [`REVIEW_CHECKLIST.md`](../.claude/skills/code-review/REVIEW_CHECKLIST.md) is the
  checklist walked section by section — Chatter-specific hotspots first (XSS,
  strong params, coordinate validation, N+1, Action Cable scope, `data-turbo-*`,
  secrets), then SOLID, Ruby, Rails, Hotwire, and tests.
- **Baseline:** findings are measured against [`../CLAUDE.md`](../CLAUDE.md) and
  [`PRD.md`](PRD.md), not assumptions — "keep it simple" and the PRD §3 scope
  bound what counts as worth fixing.
- **Gates:** `bin/rubocop`, `bundle exec rspec`, `bin/brakeman`,
  `bin/importmap audit` (results below).
- **Output:** findings ranked by importance, each with a fix and a
  `Fix` / `Optional` / `Skip` call; then what was fixed and what was left, and why.

## Automated gates

| Gate | Result |
| --- | --- |
| RuboCop | pass — 37 files, 0 offenses |
| RSpec | 31 examples, 0 failures (12 model, 11 request, 3 system + 5 shared) |
| Brakeman | 0 warnings |
| importmap audit | clean |

## Findings

Ordered by importance. The Chatter-specific security hotspots (XSS in message
rendering, strong-params scoping, Action Cable subscription scope, coordinate
validation, secrets) were all checked and are **clean or acceptable by design** —
see "Clean" at the end.

### 1. Leaflet map has no `disconnect()` teardown — `app/javascript/controllers/map_controller.js:8`

- **What:** The controller builds the Leaflet map in `initialize()` and never tears
  it down. [PRD](PRD.md) §2.4 explicitly states *"the Leaflet instance … [is] owned
  by `map_controller` and torn down in `disconnect()`"*, and
  [`REVIEW_CHECKLIST.md`](../.claude/skills/code-review/REVIEW_CHECKLIST.md) calls
  for cleanup of map instances/listeners. Today's UI never triggers a Turbo Drive
  page swap (all navigation is a frame `src` change or `fetch`, both staying on
  `/`), so it doesn't break at runtime yet — but a Turbo cache restore, a
  back/forward navigation, or any future full-page link re-runs `initialize()` on a
  container that already holds a map → Leaflet throws *"Map container is already
  initialized"*, and the old map + tile layer + click listeners leak.
- **Fix:** Move the setup from `initialize()` to `connect()`, and add
  `disconnect() { this.map?.remove(); this.map = null }`.
- **Worth fixing:** `Fix` — a named design decision in PRD §2.4 that a
  reviewer will check against the code; ~4 lines.

### 2. CI never runs the test suite, and pushes to the integration branch aren't built — `.github/workflows/ci.yml:6`

- **What:** The workflow has `scan_ruby`, `scan_js`, and `lint` jobs but **no RSpec
  job** — the 31 specs never run in CI, so a broken spec doesn't block a PR.
  `bin/ci` / `config/ci.rb` also omit RSpec. Separately, `push:` triggers only on
  `branches: [ main ]`, but the repo integrates on `develop` (`origin/HEAD →
  develop`), so direct pushes to `develop` get no build (PRs still do).
- **Fix:** Add a `test` job (Postgres service, `bin/rails db:test:prepare`,
  `bundle exec rspec`, headless-Chrome deps for the system specs) and change the
  push branch to `develop`.
- **Worth fixing:** `Fix` — CLAUDE.md makes tests a first-class
  convention ("write the test with the feature"); shipping specs that CI ignores
  undercuts that, and it's the graders' first signal that the suite is real.

### 3. Marker `<span>` markup is duplicated instead of a shared partial — `app/views/chatrooms/index.html.erb:4` and `app/views/chatrooms/create.turbo_stream.erb:6`

- **What:** The hidden marker element (5 `data-*` attributes consumed by
  `map_controller`) is written out by hand in both the initial render and the
  create stream. CLAUDE.md: *"Extract partials for anything rendered in a Turbo
  Stream so the stream and the initial render share one template."* These two
  copies already drifted once (`data-latitude` vs `data-chatroom-latitude`) and
  silently broke every marker.
- **Fix:** Extract `app/views/chatrooms/_marker.html.erb` taking a `chatroom`
  local; render it from `index.html.erb` and from `create.turbo_stream.erb`.
- **Worth fixing:** `Fix` — explicit CLAUDE.md convention, already
  bit us once, trivial extraction.

### 4. `ChatroomsController#create` uses `create!` with no rescue — `app/controllers/chatrooms_controller.rb:9`

- **What:** An out-of-range or missing coordinate raises `ActiveRecord::RecordInvalid`,
  which Rails renders as its generic 422 page. The client does
  `Turbo.renderStreamMessage(html)` on that page — it contains no `<turbo-stream>`,
  so the pin silently fails to appear with no feedback. `MessagesController#create`
  handles the mirror case explicitly (`rescue … head :unprocessable_entity`), so
  the two write paths are inconsistent.
- **Fix:** Either `rescue ActiveRecord::RecordInvalid` and return a small
  `turbo_stream` that flashes an error, or accept the 422 and document it. At
  minimum match `MessagesController`'s pattern.
- **Worth fixing:** `Optional` — coordinates come straight from Leaflet clicks and
  PRD §3 assumes trusted input, so this is unreachable from the UI; the argument
  for fixing is consistency, not risk.

### 5. `Chatroom` title uses a `COUNT`-based counter that races — `app/models/chatroom.rb:17`

- **What:** `self.title = "Chatroom #{Chatroom.count + 1}"` — two simultaneous
  creates both read the same count and both become "Chatroom N". Also runs a
  `SELECT COUNT(*)` on every create.
- **Fix:** `after_create { update_column(:title, "Chatroom #{id}") if …}`, or a DB
  sequence, or leave it and accept duplicate labels.
- **Worth fixing:** `Optional` — titles are display-only labels, there's no
  uniqueness requirement in the PRD, and the collision window is a few milliseconds
  at demo scale. Note it and move on.

### 6. No index for the message-history query — `db/migrate/20260902060137_create_messages.rb:4`

- **What:** The panel runs `@chatroom.messages.order(:created_at)` — filter on
  `chatroom_id`, sort on `created_at` — but only `chatroom_id` is indexed.
- **Fix:** `add_index :messages, [:chatroom_id, :created_at]` in a new migration
  (replacing the single-column FK index).
- **Worth fixing:** `Optional` — tables are tiny at demo scale (PRD §3, no
  pagination) so Postgres will happily sort in memory; this is the first thing to
  add if message volume ever grows.

### 7. `createChatroom` hand-rolls a `fetch` where a Turbo-driven form would do — `app/javascript/controllers/map_controller.js:29`

- **What:** The map click posts via raw `fetch`, manually assembling the CSRF
  header, the `Accept` header, and `Turbo.renderStreamMessage`. CLAUDE.md /
  checklist: *"don't reach for Stimulus or `fetch` when a plain link/form + Turbo
  does it."* The click genuinely needs JS (Leaflet event → coords), but the
  submission doesn't.
- **Fix:** Keep a hidden `<form action="/chatrooms" method="post">` with
  lat/long inputs in the view; in the click handler set the inputs and call
  `form.requestSubmit()`. Turbo then handles CSRF, headers, and stream rendering.
- **Worth fixing:** `Optional` — current code works and is tested; the payoff is
  deleting the CSRF/`Accept`/`renderStreamMessage` boilerplate and the
  `?.content ?? ""` guard.

### 8. `GET /chatrooms/:id` renders only the panel frame, no standalone page — `app/views/chatrooms/show.html.erb:1`

- **What:** `show` renders just `turbo_frame_tag "panel"`. Visiting or reloading
  `/chatrooms/5` directly shows a bare panel with no map. Fine as a Turbo Frame
  response; degraded as a shareable URL.
- **Fix:** In `show`, if the request isn't a frame request
  (`turbo_frame_request?` is false), render `index` with the room preselected.
- **Worth fixing:** `Optional` — the PRD's §2.4 "linkable / back button" language
  was removed and the app's canonical URL is `/`; FR3 ("clicking a marker switches
  the panel") is met. Nice-to-have coherence, not a requirement.

### 9. `head :unprocessable_entity` — deprecated symbol — `app/controllers/messages_controller.rb:11`

- **What:** Rack 3.1 renamed the 422 symbol to `:unprocessable_content`
  (`:unprocessable_entity` still works but is on a deprecation path). The specs
  already assert `:unprocessable_content`.
- **Fix:** `head :unprocessable_content`.
- **Worth fixing:** `Optional` — one-word change, silences a future deprecation,
  matches the specs.

### 10. Minor: ERB style in `show.html.erb` — `app/views/chatrooms/show.html.erb:3`

- **What:** `<%end%>` (no spaces) and 4-space indentation where the rest of the
  codebase uses 2. RuboCop doesn't lint ERB so CI won't catch it.
- **Fix:** `<% end %>`, reindent. Same for the 4-space block in
  `messages/_message.html.erb`.
- **Worth fixing:** `Optional` — pure cosmetics; do it in passing.

## Clean

- **XSS (hotspot 1):** `_message.html.erb` renders `username`/`body` through plain
  `<%= %>`; no `raw`/`html_safe`/`sanitize` anywhere on user text; `chatroom.title`
  likewise. Brakeman CrossSiteScripting: 0.
- **Strong params (hotspot 2):** `chatroom_params` permits only `latitude`/`longitude`
  (a request spec proves a client `title` is ignored); `message_params` permits only
  `username`/`body`, and the message is built through `@chatroom.messages` from the
  nested route. No `permit!`. Brakeman MassAssignment: 0.
- **Action Cable scope (hotspot 5):** `turbo_stream_from @chatroom` uses a signed
  stream name; there's no connection identification or per-room authz, which is
  correct — PRD §3 makes every room world-readable. Flag this the moment any
  user-specific data enters a stream.
- **N+1 (hotspot 4):** panel orders in SQL; `_message` touches no associations;
  `Chatroom.all` on the index reads only own columns. Unbounded history load is a
  conscious PRD §3 trade-off.
- **Coordinate validation (hotspot 3):** presence + `-90..90` / `-180..180`
  numericality, mirroring `NOT NULL`; model specs cover the boundaries.
- **Secrets (hotspot 7):** `config/*.key` git-ignored; `.kamal/secrets` holds only a
  `RAILS_MASTER_KEY=$(cat …)` reference; `credentials.yml.enc` is encrypted;
  `docker-compose.yml` / CI YAML carry only throwaway local values.
- **`data-turbo-*` (hotspot 6):** frame id `panel` and stream target `messages` /
  `message_form` agree across every trigger and response; `map_controller`'s `fetch`
  `Accept` matches the controller's `turbo_stream` format.
- **Migrations:** reversible, one concern each, `null: false` deliberate, timestamps
  present, real FK + constraint on `messages.chatroom_id`.
- **`Message` broadcast:** `broadcasts_to` uses `after_create_commit` +
  `broadcast_*_later` under the hood — request isn't blocked, a rollback can't emit
  a phantom row.
- **Tests:** every model's validations/associations covered; all four core flows
  have request or system specs; system specs use Capybara waiting matchers, no
  sleeps.

## Decisions

**Fixed before this review (earlier in the branch history):** the `data-latitude`
attribute mismatch, `turnbo_stream_from` typo, `Turbo.visit(url, {frame:})` →
`panel.src`, the CSRF-meta `.content` crash, `before_create` → `before_validation`
for the title, CARTO tiles → keyless OpenStreetMap, the layout `<main>` wrapper
that fought the full-screen map.

**Fixed after this review**

- **#1, #2, #3** :
  - **#1** — needed to be fixed since it requires the Leaflet instance to be "torn down in `disconnect()`"; it also threw *"Map container is already initialized"* on a Turbo cache restore.
  - **#2** — needed to be fixed since CI never ran the specs, so a broken one couldn't block a merge.
  - **#3** — the marker markup was duplicated in two files; duplicated code like this belongs in one shared partial so it can't drift.

- **#7** — the payoff was worth it: routing the map-click POST
  through a hidden Turbo-driven form deleted ~12 lines of hand-rolled `fetch`
  plumbing (CSRF header, `Accept` header, `Turbo.renderStreamMessage`) and the
  brittle `?.content ?? ""` CSRF guard that only existed because raw `fetch`
  doesn't get the token for free. Net less code, and it follows the
  "let Turbo do it" convention. Cost was one small hidden `<form>` in the view.

- **#9, #10** — each was a one-line change so they were done in passing
  rather than deferred.

**Left deliberately:**

- **#6 #8 (`Optional`)** — all real improvements, all low-value against
  PRD §3's scope (trusted input, demo scale, no pagination, `/` as the canonical
  URL). Recorded so the omissions are visible choices, not misses.



