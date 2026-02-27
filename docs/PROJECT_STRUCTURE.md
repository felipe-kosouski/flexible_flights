# Flexible Flights — Project Structure

A modular monolith Rails application for flexible flight search. Business logic lives in explicit domain modules; Rails handles delivery, persistence, and infrastructure.

---

## Root Overview

```
flexible_flights/
├── app/                    # Application code
├── bin/                    # Executables
├── config/                 # Configuration
├── db/                     # Database schema & migrations
├── docs/                   # Documentation
├── lib/                    # Shared libraries
├── log/                    # Log files
├── public/                 # Static assets
├── script/                 # Scripts
├── spec/                   # RSpec tests
├── .cursor/                # Cursor IDE rules
├── .github/                # GitHub config
├── .idea/                  # JetBrains IDE config
├── .kamal/                 # Kamal deployment
├── .ruby-lsp/              # Ruby LSP config
├── Dockerfile
├── Gemfile
├── Procfile.dev
├── Rakefile
├── README.md
├── config.ru
├── docker-compose.yml
└── .ruby-version
```

---

## Application (`app/`)

```
app/
├── assets/
│   ├── builds/
│   │   └── tailwind.css
│   ├── images/
│   ├── stylesheets/
│   │   └── application.css
│   └── tailwind/
│       └── application.css
│
├── controllers/
│   ├── concerns/
│   └── application_controller.rb
│
├── domain/                          # Domain layer (plain Ruby)
│   ├── confidence/                  # (empty — future bounded context)
│   ├── insights/                    # (empty — future bounded context)
│   │
│   └── search/                      # Search bounded context
│       ├── search_run.rb            # Aggregate root
│       │
│       ├── models/                  # Domain read models (NOT ActiveRecord)
│       │   ├── analysis_snapshot.rb
│       │   ├── flight_sample.rb
│       │   └── search_intent.rb
│       │
│       ├── sampling/
│       │   ├── candidate_selector.rb
│       │   ├── date_grid.rb
│       │   ├── runner.rb
│       │   └── sampler.rb
│       │
│       ├── scoring/
│       │   ├── final_score.rb
│       │   ├── price_score.rb
│       │   ├── scorer.rb
│       │   ├── time_comfort_score.rb
│       │   └── trip_fit.rb
│       │
│       ├── analysis/
│       │   └── snapshot_builder.rb
│       │
│       ├── factories/
│       │   └── search_run_factory.rb
│       │
│       ├── mappers/
│       │   └── search_run_mapper.rb
│       │
│       └── repositories/
│           └── search_run_repository.rb
│
├── helpers/
│   └── application_helper.rb
│
├── javascript/
│   ├── application.js
│   └── controllers/
│       ├── application.js
│       ├── hello_controller.js
│       └── index.js
│
├── jobs/
│   ├── application_job.rb
│   ├── analysis_job.rb
│   ├── sampling_job.rb
│   └── start_search_run_job.rb
│
├── models/                   # ActiveRecord models (dumb data holders)
│   ├── application_record.rb
│   ├── concerns/
│   ├── analysis_snapshot.rb
│   ├── flight_sample.rb
│   ├── search_intent.rb
│   ├── search_run.rb
│   └── user.rb
│
├── presenters/               # (empty)
├── services/                 # (empty)
│
└── views/
    ├── layouts/
    │   └── application.html.erb
    └── pwa/
        ├── manifest.json.erb
        └── service-worker.js
```

---

## Configuration (`config/`)

```
config/
├── environments/
│   ├── development.rb
│   ├── production.rb
│   └── test.rb
├── initializers/
│   ├── assets.rb
│   ├── content_security_policy.rb
│   ├── filter_parameter_logging.rb
│   └── inflections.rb
├── locales/
│   └── en.yml
├── application.rb
├── boot.rb
├── cable.yml
├── cache.yml
├── ci.rb
├── credentials.yml.enc
├── database.yml
├── deploy.yml
├── environment.rb
├── importmap.rb
├── puma.rb
├── queue.yml
├── recurring.yml
├── routes.rb
└── bundler-audit.yml
```

---

## Database (`db/`)

```
db/
├── migrate/
│   ├── 20260212123843_create_users.rb
│   ├── 20260212202731_create_search_intents.rb
│   ├── 20260212203947_create_search_runs.rb
│   ├── 20260212204429_create_flight_samples.rb
│   ├── 20260212204936_create_analysis_snapshots.rb
│   ├── 20260217111434_rename_status_to_statein_search_runs.rb
│   ├── 20260217111838_rename_completed_at_to_finished_atin_search_runs.rb
│   └── 20260217111918_add_error_message_to_search_runs.rb
├── cable_schema.rb
├── cache_schema.rb
├── queue_schema.rb
├── schema.rb
└── seeds.rb
```

---

## Documentation (`docs/`)

```
docs/
├── domain/
│   ├── analysis.md
│   ├── sampling.md
│   ├── sampling_candidate_selector.md
│   ├── sampling_runner.md
│   ├── sampling_sampler.md
│   ├── scoring.md
│   ├── search_run.md
│   ├── search_run_repository.md
│   └── search_run_spec.md
├── ARCHITECTURE.md
├── PRD.md
└── PRODUCT_GUIDE.md
```

---

## Specs (`spec/`)

```
spec/
├── domain/
│   └── search/
│       ├── analysis/
│       │   └── snapshot_builder_spec.rb
│       ├── models/
│       │   └── analysis_snapshot_spec.rb
│       ├── sampling/
│       │   ├── candidate_selector_spec.rb
│       │   ├── date_grid_spec.rb
│       │   ├── runner_spec.rb
│       │   └── sampler_spec.rb
│       ├── scoring/
│       │   ├── final_score_spec.rb
│       │   ├── price_score_spec.rb
│       │   ├── scorer_spec.rb
│       │   ├── time_comfort_score_spec.rb
│       │   └── trip_fit_spec.rb
│       ├── search_run_factory_spec.rb
│       ├── search_run_mapper_spec.rb
│       ├── search_run_repository_mapper_spec.rb
│       └── search_run_spec.rb
├── jobs/
│   ├── analysis_job_spec.rb
│   ├── sampling_job_spec.rb
│   └── start_search_run_job_spec.rb
├── models/
│   ├── analysis_snapshot_spec.rb
│   ├── flight_sample_spec.rb
│   ├── search_intent_spec.rb
│   ├── search_run_spec.rb
│   └── user_spec.rb
├── support/
│   ├── factory_bot.rb
│   └── shoulda_matchers.rb
├── rails_helper.rb
└── spec_helper.rb
```

---

## Binaries (`bin/`)

```
bin/
├── brakeman
├── bundler-audit
├── ci
├── dev
├── docker-entrypoint
├── importmap
├── jobs
├── kamal
├── rails
├── rake
├── rubocop
├── setup
└── thrust
```

---

## Public Assets (`public/`)

```
public/
├── 400.html
├── 404.html
├── 406-unsupported-browser.html
├── 422.html
├── 500.html
├── icon.png
├── icon.svg
└── robots.txt
```

---

## Cursor Rules (`.cursor/`)

```
.cursor/
└── rules/
    ├── architecture.mdc
    ├── coding-guidelines.mdc
    ├── domain.mdc
    ├── persistence.mdc
    └── testing.mdc
```

---

## GitHub (`.github/`)

```
.github/
├── workflows/
│   └── ci.yml
└── dependabot.yml
```

---

## Kamal Deployment (`.kamal/`)

```
.kamal/
├── hooks/
│   ├── docker-setup.sample
│   ├── post-app-boot.sample
│   ├── post-deploy.sample
│   ├── post-proxy-reboot.sample
│   ├── pre-app-boot.sample
│   ├── pre-build.sample
│   ├── pre-connect.sample
│   ├── pre-deploy.sample
│   └── pre-proxy-reboot.sample
└── secrets
```

---

## Dependency Flow (Architecture)

```
Controllers / Jobs
        ↓
  Repositories
        ↓
  Domain (incl. domain read models)
```

- **Domain** — Pure Ruby, no Rails/AR/I/O
- **Repositories** — Persistence coordination, may use AR
- **ActiveRecord** — Schema, associations, validations only

---

## Domain Layer Summary

| Path | Purpose |
|------|---------|
| `search_run.rb` | Aggregate root, orchestrates sampling & scoring |
| `models/` | Domain read models (read-only projections) |
| `sampling/` | Candidate generation, date grids, sampling strategies |
| `scoring/` | Price, time, comfort, trip fit, final score |
| `analysis/` | Snapshot building for insights |
| `factories/` | Domain object construction |
| `mappers/` | AR ↔ domain translation |
| `repositories/` | Persistence coordination |
