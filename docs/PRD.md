# Chatter - Technical PRD

A chat app built on a map. Users click the map to drop a pin and open a chatroom, click an existing pin to switch chatrooms, and post messages inside a chatroom.

## 1. Functional requirements

- **FR1 - Create a pin.** Clicking an empty spot on the map creates a chatroom pin there.
- **FR2 - Panel follows pin creation.** Creating a pin also switches the right-hand panel to the chatroom (title, empty message list, composer).
- **FR3 - Select an existing pin.** Clicking an existing marker switches the panel to the chatroom. At minimum, the title updates.
- **FR4 - Post a message.** A user types a display name and a message and submits it. The message appears in the chatroom's list (sender, body, timestamp).
- **FR5 - Persistence.** Chatrooms and messages survive a page reload, a new session, and a server restart. State lives on the server, not just in the browser.
- **FR6 - Real-time delivery.** A message posted by anyone shows up for everyone else already viewing that chatroom, without a refresh.

## 2. Technical decisions

### 2.1 Stack

Stock Rails 8 — nothing added that the feature set doesn't require.

| Concern | Choice | Why |
| --- | --- | --- |
| Framework | Rails 8.1 (Ruby 4.0) | One toolchain for views, jobs, and websockets. |
| Database | PostgreSQL | Domain data, plus — via Solid Queue/Cache/Cable — jobs, cache, and pub/sub. **No Redis.** |
| Frontend | Hotwire (Turbo + Stimulus), server-rendered ERB | Real-time is HTML broadcasts; no client framework, no JSON API. |
| Assets | Propshaft + import maps | No Node build step. Leaflet pinned from a CDN. |
| Styling | Tailwind | Utility classes in the templates. |
| Map | Leaflet | Required by the brief; layout from the provided CodePen. |
| Tests | RSpec + Capybara | Model specs; system specs for the core flows. |
| Deploy | Kamal + Docker | One container image. |

Net result: **one web process and one Postgres database** — which keeps both the infra estimate and the real-time feature cheap.

### 2.2 Data model

Two tables. No `User`, no auth — a username is free text typed per message, as in the mockup.

**`chatrooms`**

| Column | Type | Notes |
| --- | --- | --- |
| `title` | string, not null | Set server-side: `"Chatroom #{count + 1}"`. |
| `latitude` | decimal(9,6), not null | Validated `-90..90`. |
| `longitude` | decimal(9,6), not null | Validated `-180..180`. |
| timestamps | | |

**`messages`**

| Column | Type | Notes |
| --- | --- | --- |
| `chatroom_id` | references, not null | Indexed; FK with `on_delete: :cascade`. |
| `username` | string, not null | Display name, not an account. |
| `body` | text, not null | |
| timestamps | | `created_at` is shown in the panel. |

`Chatroom has_many :messages, dependent: :destroy`. Every `not null` column has a matching model validation. The map loads every chatroom in one query — few enough pins that no spatial index or viewport filtering is needed.

### 2.3 Real-time message delivery

Turbo Streams over Action Cable, backed by Solid Cable (Postgres pub/sub) — no Redis.

- The chatroom panel renders `turbo_stream_from @chatroom`, subscribing the viewer to that room.
- `Message` broadcasts with the turbo-rails macro `broadcasts_to :chatroom`, which appends the new row (from a background job) to `#messages` in every subscriber's panel.
- The sender's form submit returns a Turbo Stream that **only clears the composer**. The message itself arrives through the same broadcast as everyone else's, rendered by the one `messages/_message` partial — no duplicate, no optimistic echo.
- No backfill on reconnect: a client that drops and reloads re-fetches the full list.

New pins are **not** broadcast — another user's pin appears on your next load. Only messages are real-time (FR6).

### 2.4 State management

- **The server is the source of truth.** Everything persists in Postgres (FR5); no `localStorage`, no client store.
- Each page load renders the map, all existing pins, and either the selected room or the "Click on the map to start a chat" placeholder.
- **Select a room:** `GET /chatrooms/:id` into a `#chatroom-panel` Turbo Frame; the URL updates so rooms are linkable and the back button works.
- **Create a pin:** `POST /chatrooms` with the clicked coordinates; the response adds the marker and swaps in the new room's panel.
- **Client state** is just the Leaflet instance, owned by `map_controller` and torn down in `disconnect()`. No business logic in JS.

## 3. Assumptions & out of scope

- **No login.** Anyone with the URL can read every room and post as any name. A username is a label on a message, not an identity — two people can use the same one.
- **One shared map.** A single global set of pins; there are no private or per-user maps, and no map bounds or regions.
- **No editing, deleting, read receipts, typing indicators, or moderation.** Messages are append-only and permanent. Nothing tracks who has seen what or who is currently typing, and there is no way to report, hide, or remove a message or pin.
- **No pagination.** A room renders its full message history on load, and the map renders every pin. Fine at demo scale; a production build would page both.
- **Trusted input.** Basic length validation only. No rate limiting, spam protection, or profanity filtering.
- **Modern browser.** Latest Chrome/Firefox/Safari with JavaScript and WebSocket support; no IE or no-JS fallback.
