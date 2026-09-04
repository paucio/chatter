# Chatter

A real-time chat app built on a map. Click the map to drop a pin — each pin is a
chatroom. The right-hand panel shows the selected room and lets you post messages.
Rooms and messages persist across sessions, and messages appear live for everyone
already viewing that room.

Server-rendered Rails 8 + Hotwire (Turbo + Stimulus), Leaflet for the map,
PostgreSQL for everything (data plus Solid Queue / Cache / Cable — no Redis).

See [`docs/PRD.md`](docs/PRD.md) for the functional spec and design decisions, and
[`docs/infrastructure.md`](docs/infrastructure.md) for the deploy plan and cost
estimate. [`CLAUDE.md`](CLAUDE.md) is the guidance file for AI assistants working
in the repo.

## Requirements

- Ruby 4.0.6 (see [`.ruby-version`](.ruby-version))
- PostgreSQL 16
- A modern browser (the app targets current Chrome/Firefox/Safari; no no-JS
  fallback)

No Node toolchain — JavaScript is served via import maps, CSS via
`tailwindcss-rails`.

## Getting started

```bash
bin/setup        # installs gems, prepares the database, starts the dev server
```

or step by step:

```bash
bundle install
bin/rails db:prepare      # create + migrate development and test databases
bin/dev                   # Rails server + Tailwind watcher (Procfile.dev)
```

Then open http://localhost:3000.

### Configuration

Development and test read the database connection from `DATABASE_HOST` /
`RAILS_MAX_THREADS` with sensible localhost defaults (see
[`config/database.yml`](config/database.yml)); no `.env` needed for local work.
Production expects `RAILS_MASTER_KEY` and `CHATTER_DATABASE_PASSWORD`.

## Tests

RSpec, with Capybara + Selenium (headless Chrome) for the system specs.

```bash
bin/rails db:test:prepare        # once, or after a schema change
bundle exec rspec                # full suite
bundle exec rspec spec/models    # a subset
```

System specs build `app/assets/builds/tailwind.css` automatically before they run.

## Checks

```bash
bin/rubocop -a       # rails-omakase style, autocorrect
bin/ci               # style + security gates (rubocop, bundler-audit, importmap audit, brakeman)
bin/brakeman         # security scan on its own
```

CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs RuboCop, RSpec,
Brakeman, and the importmap audit on every pull request.

## Running with Docker

[`docker-compose.yml`](docker-compose.yml) runs the production image against a
Postgres container:

```bash
export RAILS_MASTER_KEY=$(cat config/master.key)
docker compose up --build
```

## Deployment

Deployment is a written exercise — nothing is actually deployed. The plan
(Kamal 2 → VMs, two environments, cost tables) is in
[`docs/infrastructure.md`](docs/infrastructure.md). [`config/deploy.yml`](config/deploy.yml)
is scaffolded but carries placeholder values.
