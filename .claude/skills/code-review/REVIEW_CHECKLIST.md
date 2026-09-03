# Chatter — code review checklist

Walk every section against the code in scope. Measure findings against
[`docs/PRD.md`](../../../docs/PRD.md) and [`CLAUDE.md`](../../../CLAUDE.md), not
assumptions. Skip nitpicks RuboCop already enforces; distinguish "bug" from
"smell" from "preference". Every finding names a file and line, says why it
matters, and shows the fix. If a section's code is clean, say so.

## Chatter-specific hotspots

The places this codebase is most likely to be wrong — check each one explicitly
and report on it, even when the answer is "fine, and here's why":

1. **XSS in message rendering.** `messages/_message.html.erb` renders `username`
   and `body` — free user text, no auth, no sanitization step. Confirm every
   interpolation is plain `<%= %>` (auto-escaped) and there is no
   `raw` / `html_safe` / `sanitize` / `<%==` on user text, here or on
   `chatroom.title`. Turbo Stream broadcast payloads run through the same partial
   — the escaping must live in the partial, because the channel does not escape
   for you.
2. **Strong params / mass assignment.** `chatroom_params` permits **only**
   `:latitude`, `:longitude` — never `:title` (server-assigned "Chatroom N").
   `message_params` permits **only** `:username`, `:body` — never `:chatroom_id`
   (that comes from the nested route + association). No `permit!` anywhere.
3. **Coordinate validation.** `Chatroom` validates `latitude` in `-90..90` and
   `longitude` in `-180..180`, plus presence, mirroring the `NOT NULL` columns.
   The create path depends on it (`create!` → rescued as 422, not an unhandled
   500). Confirm out-of-range or missing coordinates can't persist and the
   failure response is deliberate.
4. **N+1 on messages.** The panel renders `@chatroom.messages` as a collection.
   Ordering (`created_at`) must be done in SQL, not Ruby. The `_message` partial
   must not touch `message.chatroom` (or any association) per row; if it does,
   add `includes`. Rendering the full unbounded history is accepted at demo
   scale (PRD §3) — note it as a conscious trade-off, not a miss.
5. **Action Cable auth / scoping.** `turbo_stream_from @chatroom` subscribes via a
   signed stream name. There is no `ApplicationCable::Connection` identification
   and no per-room authorization: anyone who can guess or replay the signed name
   can listen. PRD says every room is world-readable, so this is acceptable — the
   review must state that explicitly. Flag immediately if any user-specific or
   sensitive data ever enters a stream.
6. **`data-turbo-*` correctness.** Frame ids match between trigger and response
   (`panel`), and the id used by `turbo_stream_from` / `broadcasts_to` targets
   agrees with the DOM (`messages`). Frame and stream responses render only their
   fragment, no layout. `map_controller`'s `fetch` sends
   `Accept: text/vnd.turbo-stream.html` and the controller replies in that
   format. Any `data-turbo="false"`, `data-turbo-method`, `data-turbo-frame`,
   `data-turbo-action`, or `data-turbo-permanent` is deliberate and correct.
7. **No secrets committed.** `config/master.key` is git-ignored; `.kamal/secrets`
   holds only ENV / password-manager references, no raw values; no credentials in
   `config/`, `docker-compose.yml`, the CI YAML, or specs/fixtures.
   `config/credentials.yml.enc` (encrypted) is fine — its key is not.

## SOLID (as it applies to Ruby/Rails)

- **Single responsibility.** A class/module has one reason to change. Watch for
  controllers doing persistence + broadcasting + formatting; models over ~100 lines or mixing persistence with business workflows; a Stimulus controller that both drives the map and manages form state. Extract POROs / service objects / form objects, not more callbacks.
- **Open/closed.** New behavior should not require editing a `case`/`if` 
  ladder that switches on type. Prefer polymorphism, a registry, or a strategy object. In Rails this often means a subclass or a duck-typed collaborator instead of `if
  chatroom.kind == ...`.
- **Liskov substitution.** STI subclasses and any `< SomeBase` must honor the 
  base contract — no overridden method that raises, returns a wildly different type, or needs `is_a?` checks at the call site.
- **Interface segregation.** Don't force callers to depend on fat modules. 
  Split large concerns; pass the narrow collaborator a method needs, not the whole model. A concern mixed into a class that uses 2 of its 9 methods is a smell.
- **Dependency inversion.** High-level code shouldn't hard-depend on incidental
  details. Inject collaborators (mailer, clock, broadcaster) so they can be
  substituted in tests. `Time.current` over `Time.now`; avoid `SomeClass.new`
  buried deep in a method when it could be a constructor arg with a default.

Keep it proportional. This is a small app — flag genuine violations that hurt
readability or testability, not every place a pattern *could* be applied.

## Ruby

- Idiom: `map`/`select`/`filter_map`/`sum`/`tally` over manual accumulation;
  safe navigation `&.`; `presence`, `dig`, `then`/`yield_self` where they clarify.
- Guard clauses over nested conditionals. Early return beats `else`.
- Prefer immutable data flow; avoid mutating method arguments. Freeze constant
  literals.
- Naming: predicates end in `?`, bang methods `!` only when there's a non-bang
  pair or real mutation/exception. No abbreviations that aren't domain terms.
- Keyword arguments for anything with >1 param or a boolean. No positional
  booleans.
- No rescuing `Exception` or bare `rescue`; rescue the narrowest class. Don't
  swallow errors silently.
- Memoization (`@x ||=`) is fine for pure reads; never memoize something with
  side effects or that can legitimately be `nil`/`false`.

## Rails

**Controllers**
- Skinny. RESTful actions only; if you're adding a 6th custom action, you probably
  need another resource. Business logic belongs in models or service objects.
- Strong parameters on every write. Never `permit!`.
- One object load per action, scoped through an association
  (`chatroom.messages.build`) not `Message.where(...)` — protects against IDOR.
- Set HTTP status explicitly on non-GET responses. Use `head :no_content` etc.
- No view logic (`helper_method` or a presenter instead).

**Models**
- Validations mirror DB constraints — every `validates ... presence: true` has 
  a matching `NOT NULL`; every uniqueness validation has a unique index (validation alone races).
- `belongs_to` is required by default in Rails 5+; add `optional: true` only 
  when truly optional. Add the FK index and a real foreign key constraint in the migration.
- Callbacks: only for things intrinsic to persistence (normalizing a column).
  Anything that touches another aggregate, sends mail, or broadcasts should be an explicit call from the caller or a service — not an `after_save`. `after_commit` for anything with external side effects, never `after_save`.
- Scopes return relations (chainable), never arrays or `nil`.
- No default_scope.
- Enums: back with a string column, not integer, unless space matters.

**Queries & performance**
- N+1: any view or serializer iterating an association needs `includes`/`preload`. Check partials rendered in a collection too.
- `exists?` not `.present?`/`.any?` when you only need a boolean.
- `find_each` for batch work; never load an unbounded collection.
- Push filtering/counting/ordering into SQL, not Ruby.
- `pluck`/`select` when you don't need full objects.

**Migrations**
- Reversible (`change` or explicit `up`/`down`). One concern per migration.
- Indexes for every FK and every column you query or sort by.
- `null: false` + defaults decided deliberately. Timestamps on every table.
- No data backfill in the same migration as a schema change on a large table
  (fine here given scale, but note it).

**Security**
- Brakeman clean, or every warning triaged in the report.
- No string interpolation into `where`/`order`/`find_by_sql` — parameterize.
- Mass-assignment guarded by strong params.
- Output is escaped by default; every `raw`/`html_safe`/`sanitize` is justified.
- Secrets via credentials/ENV, never committed. Check `config/` and fixtures.
- CSRF protection on; Action Cable connection identified/authorized if it carries anything user-specific.

**Config & structure**
- Framework defaults loaded (`config.load_defaults 8.1`).
- Autoload-safe: file/constant names match Zeitwerk expectations.
- No environment checks (`if Rails.env.production?`) sprinkled in app code — use config objects.

## Hotwire

**Turbo Drive / Frames**
- Default to Turbo Drive navigation; don't reach for Stimulus or `fetch` when a
  plain link/form + Turbo does it.
- A `turbo_frame_tag` id is stable and matches between the trigger and the
  response. Frame responses render *only* the frame's content — no wasted layout.
- Use `target="_top"` on links that must break out of a frame.
- Lazy-load frames (`src:` + `loading: :lazy`) for panels not needed on first
  paint.
- Every frame/stream response has a non-Turbo fallback (full page render) so the URL is shareable and the back button works.

**Turbo Streams**
- Streams are for *broadcast to many* or *multi-target updates*. A single
  same-page update after a form submit is often just a frame — simpler.
- Broadcast from a clear seam (service object or an explicit model method), not
  scattered `broadcast_append_to` calls. Prefer `after_create_commit` /
  `broadcast_*_later` so the request isn't blocked and a rollback doesn't emit a phantom message.
- The stream template and the initial page render share one partial — no
  divergence between "first load" and "live update" markup.
- Name streams from a stable identifier (`"chatroom_#{id}_messages"`); document
  the channel naming.
- Consider `turbo_stream.replace` with morphing vs. `append` — appending
  duplicates if the client already rendered optimistically.
- Authorize the subscription in `Turbo::StreamsChannel` terms — anyone who can
  guess the signed stream name can listen. For this app that's acceptable; say so.

**Stimulus**
- Controllers are small and single-purpose. `map_controller` drives Leaflet and
  nothing else; form behavior is its own controller.
- Use `static targets`, `static values`, and `data-action` — never
  `querySelector`, manual `addEventListener` in `connect` without teardown, or
  reading `data-*` by hand.
- Always clean up in `disconnect()` (Leaflet map instances, timers, listeners) — Turbo Drive keeps the page alive between visits, so leaks accumulate.
- Pass server data via `values` (typed) or a `<script type="application/json">`
  data island, not string-concatenated HTML.
- No business logic or persistence in JS. The controller sends a request and lets the server + Turbo update the DOM.
- Idempotent `connect()` — it can fire more than once.

**Import maps**
- New dependencies pinned via `bin/importmap pin`, vendored or from a pinned CDN version. `bin/importmap audit` clean.
- No `import` from a bare URL scattered in controllers.

## Tests (RSpec)

- Every model: validations, associations, scopes, and any public method.
- Core flows have request or system specs: drop a pin creates a chatroom, 
  clicking a marker switches the panel, submitting posts a message and it persists, real-time append reaches a second session.
- One assertion-concept per example; descriptive `it` strings.
- Use `build`/`build_stubbed` unless the test needs the DB. No fixtures-as-God-
  object.
- No sleeps in system specs — rely on Capybara's waiting matchers.
- Don't test framework behavior (that `validates` works); test *your* rules.
- Test doubles verify (`instance_double`), not loose `double`.
- Deterministic: freeze time, seed randomness, no order dependency.
