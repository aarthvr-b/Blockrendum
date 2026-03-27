# Building Blockrendum Through the GitHub Project Backlog

## 1. Why this guide exists

This file is not just an architecture note anymore. It is the build path for the repository backlog in `docs/github-project-issues.tsv`.

The goal is to help you do two things at the same time:

- ship the project in small, reviewable steps
- understand why each step exists before you write it

Treat every task below as a small learning exercise. For each one, the guide tells you:

- what you are doing
- what "done" should look like
- where to start
- a small implementation line to follow when code helps

This guide intentionally avoids full copy-pasteable files. The point is to help you build the system yourself.

## 2. Ground rules before you start

### Project framing

Blockrendum is an educational proof of concept for a digital referendum backend. It demonstrates:

- simulated `SPID` and `CIE` login
- one-person-one-vote enforcement
- anonymous ballot storage
- coarse demographic reporting
- blockchain-backed audit receipts

It does not claim to be a real voting system.

### Core privacy rule

The most important rule in the repo is this:

- identity data belongs in the identity and eligibility area
- ballot data belongs in the anonymous vote area
- the final stored vote record must not contain a direct voter identifier

If you break that rule, the project may still "work," but it stops teaching the right lesson.

### Recommended implementation choices

These choices match the backlog and keep the project small:

- license: `MIT`
- Python package/dependency tool: `uv`
- HTTP framework: `FastAPI`
- ASGI server: `uvicorn`
- settings library: `pydantic-settings`
- database: `PostgreSQL`
- ORM / SQL layer: `SQLAlchemy 2.x`
- Postgres driver: `psycopg`
- migrations: `Alembic`
- tests: `pytest`
- config source: environment variables
- API prefix: `/api/v1`
- auth style for the POC: simple mock login plus a lightweight session or bearer token

### Concrete stack baseline

To keep the repo coherent, treat these as the default implementation decisions unless you have a clear reason to deviate:

- package management and scripts: `uv`
- API framework: `FastAPI`
- request/response schemas: `Pydantic`
- config loading: `pydantic-settings`
- persistence layer: `SQLAlchemy 2.x` with the sync session API
- Postgres connectivity: `psycopg`
- migrations: `Alembic`
- tests: `pytest`

Why this exact stack:

- it keeps the language surface small because validation, settings, and OpenAPI work naturally together
- it gives you one mainstream migration path instead of ad hoc SQL plus drift
- it stays simple enough for a POC because sync SQLAlchemy is easier to reason about than an async DB stack

Recommended dependency set:

```toml
dependencies = [
  "fastapi",
  "uvicorn[standard]",
  "pydantic-settings",
  "sqlalchemy",
  "psycopg[binary]",
  "alembic",
  "web3",
]

[dependency-groups]
dev = [
  "pytest",
  "httpx",
  "ruff",
]
```

### Working style

Build in thin vertical slices. Do not try to finish "all auth" or "all blockchain" in one shot. A better sequence is:

1. make the API boot
2. make data exist
3. make login work
4. make a vote succeed once
5. make the same vote fail twice
6. add audit and reporting around that flow

## 3. Backlog waves

The TSV backlog naturally breaks into these waves:

1. foundation and local setup
2. API bootstrap
3. domain and database shape
4. seed data and demo bootstrap
5. mock identity and eligibility
6. referendum and vote flow
7. receipt hashing and audit state
8. documentation and diagrams

You can move through the guide in that order.

## 4. Wave 1: Foundation and Local Setup

This wave gives you a repo that a new contributor can run without guessing.

### Task: Decide project license

What you are doing:
Pick the repo license now so the project is not legally ambiguous.

What we should achieve:
- the decision is written down
- the README stops saying the license is undecided

Recommended line to follow:
Use `MIT` unless you have a clear reason to prefer stronger patent language such as `Apache-2.0`.

Why this matters:
Small open source projects lose momentum when basic repo metadata stays unresolved.

### Task: Create initial Python project metadata

What you are doing:
Establish the Python project boundary for the backend code.

What we should achieve:
- `pyproject.toml` exists
- the package or app entrypoint is documented in the repo

Where to start:
Decide whether you want a `src/` layout, then record the package name and runtime entrypoint in `pyproject.toml`.

Starter line:

```toml
[project]
name = "blockrendum"
```

Recommended additions:

- set `requires-python` explicitly
- define runtime dependencies in `project.dependencies`
- keep dev-only tools in a dev dependency group

Starter shape:

```toml
[project]
name = "blockrendum"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
  "fastapi",
  "uvicorn[standard]",
  "pydantic-settings",
  "sqlalchemy",
  "psycopg[binary]",
  "alembic",
  "web3",
]

[dependency-groups]
dev = ["pytest", "httpx", "ruff"]
```

Learning point:
The package metadata becomes part of your public project identity. Changing it later is possible, but avoid accidental churn.

### Task: Add initial backend folder structure

What you are doing:
Create a layout that separates runtime entrypoints from application packages.

What we should achieve:
- `src/blockrendum` exists
- `src/blockrendum/config.py`, `src/blockrendum/auth/`, `src/blockrendum/vote/`, `src/blockrendum/audit/`, and `src/blockrendum/api/` exist

Where to start:
Move away from a single empty script placeholder and give the API a real package with a clear app entrypoint.

Good rule:
Put wiring in `src/blockrendum/main.py`, keep request handlers in `src/blockrendum/api/`, business logic in focused packages, and avoid circular imports from the start.

Recommended shape:

- `src/blockrendum/main.py`: app creation and top-level wiring
- `src/blockrendum/config.py`: settings
- `src/blockrendum/db.py`: engine and session factory
- `src/blockrendum/models/`: SQLAlchemy models
- `src/blockrendum/schemas/`: request and response models
- `src/blockrendum/api/`: routers and error handling
- `src/blockrendum/services/`: business rules
- `src/blockrendum/repositories/`: database access boundaries if the codebase grows enough to need them

### Task: Add Python-focused `.gitignore` entries

What you are doing:
Stop build output and local secrets from polluting the repo.

What we should achieve:
- Python artifacts are ignored
- local env files are ignored

Where to start:
Add entries for virtual environments, bytecode caches, coverage output, and `.env` variants.

Starter lines:

```gitignore
.venv/
__pycache__/
.pytest_cache/
.coverage
.env
.env.local
```

Learning point:
This task is small, but it protects the repo from accidental leaks and noisy diffs.

### Task: Add task runner placeholders

What you are doing:
Give the project a single place to document common commands.

What we should achieve:
- there is a documented command for `run`, `test`, and `seed`
- placeholder targets exist before every implementation is finished

Where to start:
Use a `Makefile`, `Taskfile.yml`, or just a `scripts/` convention. For this repo, a small `Makefile` plus `uv` commands is enough.

Starter lines:

```make
run:
	uv run uvicorn blockrendum.main:app --reload

test:
	uv run pytest

lint:
	uv run ruff check .

migrate:
	uv run alembic upgrade head

seed:
	uv run python -m blockrendum.seed
```

Learning point:
The task runner is not about automation sophistication. It is about reducing setup guesswork.

### Task: Add `.env.example`

What you are doing:
Document the config contract before the app grows.

What we should achieve:
- `.env.example` exists
- every variable has a short purpose note

Where to start:
List only the variables the project truly needs. Avoid speculative config.

Good first set:
- `APP_ENV`
- `HTTP_ADDR`
- `DATABASE_URL`
- `DATABASE_ECHO`
- `CHAIN_ENABLED`
- `CHAIN_RPC_URL`
- `CHAIN_PRIVATE_KEY`
- `CHAIN_CHAIN_ID`

Recommended rules:

- keep secrets out of defaults
- prefer one `DATABASE_URL` over multiple partial DB env vars for a small repo
- only add chain variables that the current code path actually needs

Learning point:
A config file is also a design document. It shows which dependencies the app really has.

### Task: Add local Postgres compose file

What you are doing:
Create a reproducible local database bootstrap path.

What we should achieve:
- a compose file exists for PostgreSQL
- the docs explain how to start it

Where to start:
Keep it minimal: one Postgres service, one volume, one exposed port, one default database.

Starter shape:

```yaml
services:
  postgres:
    image: postgres:17
```

Good defaults to add immediately:

- container name or service name that matches docs
- `POSTGRES_DB=blockrendum`
- `POSTGRES_USER=blockrendum`
- `POSTGRES_PASSWORD=blockrendum`
- a named volume for persistence
- port mapping to local `5432`

Learning point:
For a backend POC, the goal is not "perfect local infra." The goal is "one command gets me a database."

### Task: Document local bootstrap steps

What you are doing:
Write the minimum setup path a new contributor needs.

What we should achieve:
- someone new can start dependencies and the API
- the guide points to the task runner

Where to start:
Document the shortest happy path:

1. copy `.env.example`
2. start Postgres
3. run migrations
4. seed data
5. start the API
6. call `/health`

## 5. Wave 2: API Bootstrap

This wave gives you a small but disciplined HTTP service.

### Task: Choose HTTP framework

What you are doing:
Lock the framework choice so the guide and code do not drift.

What we should achieve:
- the chosen framework is recorded
- the implementation guide matches it

Recommended decision:
Use `FastAPI`.

Why:
- small amount of boilerplate for JSON APIs
- built-in request validation and OpenAPI generation
- easy versioned route grouping

Important follow-through:
Use FastAPI for HTTP shape and dependency injection, but keep business rules in services rather than pushing everything into route functions.

### Task: Bootstrap API server entrypoint

What you are doing:
Create the first executable server process.

What we should achieve:
- `src/blockrendum/main.py` exposes the ASGI app
- the listen address is configurable

Where to start:
Create `src/blockrendum/main.py` that builds the FastAPI app and keep server startup in the task runner or an ASGI command.

Starter line:

```python
app = FastAPI()
```

Recommended first shape:

```python
from fastapi import FastAPI

def create_app() -> FastAPI:
    app = FastAPI(title="Blockrendum")
    return app

app = create_app()
```

Why this shape:
An app factory makes testing and future environment-specific wiring easier without adding real complexity.

Learning point:
Your first entrypoint should be boring and explicit. Fancy server frameworks do not help here.

### Task: Add config loading

What you are doing:
Centralize environment parsing instead of reading env vars all over the codebase.

What we should achieve:
- startup reads env config
- missing required config fails clearly

Where to start:
Create `src/blockrendum/config.py` with `pydantic-settings` and load it once near startup boundaries.

Starter shape:

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    http_addr: str
    database_url: str
```

Recommended fields:

- `app_env`
- `http_host`
- `http_port`
- `database_url`
- `database_echo`
- `chain_enabled`
- `chain_rpc_url`
- `chain_private_key`
- `chain_chain_id`

Recommended rule:
Do not call `os.getenv()` throughout handlers and services. Resolve configuration once and inject what you need.

Learning point:
Strong config loading makes startup failures fast and honest.

### Task: Add `/health` endpoint

What you are doing:
Expose a tiny route that proves the server is alive.

What we should achieve:
- `GET /health` returns success
- it does not depend on the database

Where to start:
Return a fixed JSON body with a small status field.

Starter line:

```json
{"status":"ok"}
```

Recommended implementation detail:
Expose `/health` outside auth and outside `/api/v1` only if you have a strong operational reason. Otherwise keep everything, including health, under `/api/v1` for consistency.

Learning point:
Health is not "deep readiness." At this stage it is just "the process accepted and routed a request."

### Task: Add API base path versioning

What you are doing:
Create a stable top-level namespace for future routes.

What we should achieve:
- routes sit under a versioned prefix
- the version choice is documented

Recommended decision:
Use `/api/v1`.

Why:
Even for a POC, versioning early is simpler than retrofitting every route later.

### Task: Add request logging middleware

What you are doing:
Record basic request traffic for local debugging.

What we should achieve:
- incoming requests are logged
- logs include method, path, and status

Where to start:
Use FastAPI middleware or a tiny custom wrapper if you want to understand the mechanics.

Good minimum log shape:
- request id if available
- method
- path
- status code
- duration in milliseconds

Learning point:
Do not overbuild logging yet. You want request visibility, not observability maturity.

### Task: Add error response shape

What you are doing:
Standardize how handlers return failures.

What we should achieve:
- all errors share one JSON shape
- at least one route uses it

Starter shape:

```json
{
  "error": {
    "code": "unknown_voter",
    "message": "No voter matched the supplied identity"
  }
}
```

Learning point:
This is worth doing early because it shapes every negative-path test that comes later.

### Task: Add graceful shutdown handling

What you are doing:
Teach the server to stop cleanly on termination signals.

What we should achieve:
- the API handles `SIGINT` and `SIGTERM`
- shutdown uses a timeout

Where to start:
Use the ASGI server's shutdown hooks cleanly and make sure long-lived connections close within a bounded timeout.

Starter line:

```python
uvicorn.run("blockrendum.main:app", host="0.0.0.0", port=8000)
```

Recommended split:

- use `uvicorn.run(...)` only for local or script-based bootstrap
- for normal development, prefer `uv run uvicorn blockrendum.main:app --reload`
- avoid embedding too much runtime behavior in `main.py`

Learning point:
This is a small production habit that pays off immediately in local development too.

### Task: Add health route test

What you are doing:
Write the first automated route test.

What we should achieve:
- `GET /health` is tested
- the test asserts the success response

Where to start:
Use FastAPI's `TestClient` or an equivalent HTTP test client and keep the test focused on the handler contract.

Starter shape:

```python
from fastapi.testclient import TestClient

def test_health_returns_ok() -> None:
    client = TestClient(app)
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

Learning point:
This test is not interesting on its own. It teaches the testing style you will reuse for every handler.

## 6. Wave 3: Domain and Database Shape

This wave locks the language of the system before the handlers get complicated.

Recommended modeling rule:
Use Pydantic models for external request and response contracts, and SQLAlchemy models for persistence. Do not try to make one class serve every purpose.

### Task: Define referendum domain type

What you are doing:
Create the type that represents the thing people are voting on.

What we should achieve:
- a referendum type exists
- it includes status and timing fields

Suggested fields:
- `id`
- `title`
- `description`
- `question`
- `status`
- `opens_at`
- `closes_at`

Learning point:
Status plus time window is the minimum model for "can voting happen now?"

### Task: Define voter identity domain type

What you are doing:
Model the known person in the identity and eligibility domain.

What we should achieve:
- a voter type exists
- it includes provider, eligibility, and vote-consumed state

Suggested fields:
- `provider_type`
- `provider_subject`
- `date_of_birth`
- `residence_region`
- `is_eligible`
- `has_voted`

Learning point:
This record is allowed to know who the person is. The vote record is not.

### Task: Define vote record domain type

What you are doing:
Model the anonymous ballot record.

What we should achieve:
- a vote type exists
- it contains no direct voter identifier

Suggested fields:
- `referendum_id`
- `choice`
- `age_band`
- `residence_area`
- `receipt_hash`
- `anchor_status`

Red flag:
If you feel tempted to add `voter_id`, stop and revisit the privacy rule.

### Task: Define audit receipt domain type

What you are doing:
Model the blockchain-facing audit trail.

What we should achieve:
- a receipt type exists
- it includes the hash and anchoring state

Suggested fields:
- `vote_id`
- `receipt_hash`
- `tx_hash`
- `chain_id`
- `block_number`
- `status`

Learning point:
The receipt is not the vote. It is proof about the vote.

### Task: Draft voters table schema

What you are doing:
Translate the voter domain into SQL.

What we should achieve:
- schema captures eligibility and vote-consumed state
- provider subject is unique

Where to start:
Create the first migration with a `voters` table and a uniqueness constraint on provider identity.

Starter line:

```sql
unique (provider_type, provider_subject)
```

Recommended columns:
- `id uuid primary key`
- `provider_type text not null`
- `provider_subject text not null`
- `date_of_birth date not null`
- `residence_region text not null`
- `is_eligible boolean not null default false`
- `has_voted boolean not null default false`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

### Task: Draft referendums table schema

What you are doing:
Create storage for one active yes/no ballot.

What we should achieve:
- schema supports one active referendum
- status and timing fields exist

Where to start:
Use a `status` column and check constraints or enum-like text validation later if needed.

Recommended columns:
- `id uuid primary key`
- `title text not null`
- `description text not null`
- `question text not null`
- `status text not null`
- `opens_at timestamptz not null`
- `closes_at timestamptz not null`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Learning point:
Do not over-design for multi-election complexity yet.

### Task: Draft votes table schema

What you are doing:
Create storage for anonymous ballots.

What we should achieve:
- schema stores anonymous ballot data
- there is no direct voter identifier field

Required columns:
- `referendum_id`
- `choice`
- `age_band`
- `residence_area`
- `receipt_hash`
- `anchor_status`

Recommended columns to add as well:
- `id uuid primary key`
- `created_at timestamptz not null default now()`

Hard rule:
No `voter_id`, no full birth date, no exact residence.

### Task: Draft audit receipts table schema

What you are doing:
Create storage for asynchronous receipt tracking.

What we should achieve:
- schema stores receipt hash and blockchain metadata
- pending status is supported

Where to start:
Allow `tx_hash` and `block_number` to be nullable at first because new receipts begin unresolved.

Recommended columns:
- `id uuid primary key`
- `vote_id uuid not null references votes(id)`
- `receipt_hash text not null unique`
- `tx_hash text null`
- `chain_id bigint null`
- `block_number bigint null`
- `status text not null`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Implementation recommendation:
Use Alembic from the start, even if the early migrations are simple. One migration history is easier to keep honest than mixed migration approaches.

### Task: Document identity-ballot separation rule

What you are doing:
Write the privacy boundary down in repo docs so it becomes a design constraint, not tribal knowledge.

What we should achieve:
- docs say the final vote record must not include a direct voter identifier
- the reason is explained briefly

Learning point:
A boundary written down early is easier to defend in code review later.

## 7. Wave 4: Seed Data and Demo Bootstrap

This wave makes the project demoable before the full API exists.

### Task: Seed one active referendum

What you are doing:
Create a referendum record that the API can expose immediately.

What we should achieve:
- one active referendum is inserted
- it can be fetched locally

Where to start:
Give it clear open and close times around the current demo period.

Recommended seed fields:
- stable UUID
- human-readable title
- question text suitable for screenshots and curl examples
- timestamps that are obviously active during local demos

Learning point:
Hard-code only enough data to prove the path. A single referendum is enough.

### Task: Seed mock voter dataset

What you are doing:
Create recognizable test identities for the login flow.

What we should achieve:
- there is at least one eligible voter
- there is at least one ineligible voter
- provider data is included

Suggested seed mix:
- one eligible `spid` voter
- one eligible `cie` voter
- one ineligible voter
- one already-voted voter
- one unknown-provider test case left absent on purpose

Good practical rule:
Use deterministic seed subjects like `SPID-ALICE-001` so manual API testing and automated tests can refer to the same identities.

### Task: Seed eligibility flags

What you are doing:
Make eligibility explicit instead of inferred.

What we should achieve:
- seeded data has `is_eligible`
- the login flow can exercise allow and reject paths

Learning point:
Explicit flags are easier to test than burying business logic in hidden rules.

### Task: Define age-band derivation rule

What you are doing:
Lock a deterministic mapping from birth date to a reporting bucket.

What we should achieve:
- the rule is documented
- identical voter data always maps to the same age band

Recommended buckets:
- `18-25`
- `26-35`
- `36-50`
- `51-65`
- `65+`

Starter logic:

```python
if age <= 25:
```

Learning point:
You are storing the result of a privacy-preserving transform, not the raw input.

### Task: Define residence-area derivation rule

What you are doing:
Map detailed residence into a coarse reporting region.

What we should achieve:
- the rule is documented
- it avoids high-granularity location data

Recommended buckets:
- `Nord`
- `Centro`
- `Sud-Isole`

Learning point:
This is intentionally lossy. That is the privacy feature.

### Task: Add seed command hook

What you are doing:
Expose a single command that loads demo data without hand-running SQL.

What we should achieve:
- there is a documented seed command
- it works without manual SQL editing

Where to start:
This can be a Python module entrypoint or a shell script. Pick the simpler option for now.

Starter examples:
- `make seed`
- `uv run python -m blockrendum.seed`
- `./scripts/seed.sh`

Recommended implementation line:
Make the seed command idempotent enough for repeated local runs, or document clearly that it expects a fresh database.

### Task: Verify seeded data loads locally

What you are doing:
Prove the bootstrap path actually works on a real local database.

What we should achieve:
- seed data loads into local Postgres
- the result can be checked by SQL or by the app

Where to start:
Run the full sequence on an empty database and verify counts.

Good local checks:
- count `voters`
- count `referendums`
- ensure exactly one referendum is `active`
- verify at least one voter is eligible and one is ineligible

Recommended flow:

1. `uv run alembic upgrade head`
2. `uv run python -m blockrendum.seed`
3. inspect rows with SQL or admin tooling
4. hit the login and referendum endpoints

## 8. Wave 5: Mock Identity and Eligibility

This wave creates the first real user-facing business flow.

### Task: Define mock SPID/CIE payload shape

What you are doing:
Design the input contract for simulated identity login.

What we should achieve:
- the payload shape is documented in code or docs
- it supports both `spid` and `cie`

Suggested request body:

```json
{
  "provider": "spid",
  "subject": "SPID-ALICE-001"
}
```

Learning point:
This payload should resemble identity-provider output enough that a real adapter could replace it later.

### Task: Add simulated login endpoint

What you are doing:
Accept a mock identity payload and turn it into an authenticated session response.

What we should achieve:
- an endpoint accepts the simulated payload
- eligible seeded voters get a success response

Suggested endpoint:
- `POST /api/v1/auth/mock-login`

Why not separate `spid` and `cie` routes yet:
One route with a `provider` field keeps the surface smaller and the flow easier to test.

Recommended response shape:

```json
{
  "access_token": "demo-token",
  "token_type": "bearer",
  "voter": {
    "provider": "spid",
    "eligible": true
  }
}
```

### Task: Add voter lookup by provider subject

What you are doing:
Resolve a voter record from identity provider data.

What we should achieve:
- provider type and subject map to a voter
- unknown voters fail clearly

Starter query shape:

```sql
select * from voters where provider_type = $1 and provider_subject = $2
```

Learning point:
This lookup sits at the boundary between external identity and internal eligibility.

### Task: Add eligibility check service

What you are doing:
Centralize the rule that decides whether a voter may enter the vote flow.

What we should achieve:
- eligibility is checked before vote access is granted
- ineligible voters are rejected consistently

What to check:
- voter exists
- `is_eligible = true`
- optional later: referendum window and `has_voted` for flow gating

Learning point:
Small service methods are useful when multiple handlers need the same policy.

### Task: Add unknown voter response

What you are doing:
Return a failure that is clear to the caller and consistent with the API error shape.

What we should achieve:
- unknown voter uses the standard error response
- the reason is understandable

Suggested code:
- `unknown_voter`

### Task: Add ineligible voter response

What you are doing:
Make rejection for known-but-ineligible voters explicit.

What we should achieve:
- ineligible responses use the standard error response
- the reason is understandable

Suggested code:
- `voter_ineligible`

Learning point:
Unknown and ineligible are different states. Model them separately.

### Task: Add successful mock login test

What you are doing:
Prove the happy path for a seeded eligible voter.

What we should achieve:
- automated test covers successful login
- the test uses seeded-style data

Where to start:
Use a fake repository or a test database, but keep the test focused on the handler contract.

### Task: Add ineligible login test

What you are doing:
Prove the negative path for rejected voters.

What we should achieve:
- automated test covers ineligible rejection
- response shape is asserted

Learning point:
Negative-path tests are where your error contract becomes real.

## 9. Wave 6: Referendum and Vote Flow

This wave is the core of the project.

### Task: Add active referendum endpoint

What you are doing:
Expose the currently active referendum.

What we should achieve:
- an endpoint returns the active referendum
- missing or closed referendums are handled clearly

Suggested endpoint:
- `GET /api/v1/referendum/current`

Recommended behavior:
- return `200` with the current referendum when one is active
- return a clear `404` or domain-specific error when none is active

Learning point:
This route decouples reading the ballot from casting the ballot.

### Task: Add vote submission endpoint

What you are doing:
Accept a yes or no vote from an authenticated voter.

What we should achieve:
- a vote submission endpoint exists
- only allowed ballot values are accepted

Suggested endpoint:
- `POST /api/v1/votes`

Suggested request body:

```json
{
  "referendum_id": "ref-2026-01",
  "choice": "yes"
}
```

### Task: Validate referendum is active before vote

What you are doing:
Prevent voting outside the valid time window.

What we should achieve:
- votes are rejected when the referendum is not active
- the response explains the state problem

What to check:
- `status == active`
- `now >= opens_at`
- `now < closes_at`

Learning point:
Never trust the client to know whether voting is open.

### Task: Validate voter has not already voted

What you are doing:
Block repeat submission from the same voter identity.

What we should achieve:
- prior vote blocks another submission
- the rejection is consistent

Where to start:
Use the voter record as the ballot-consumption source of truth.

Important note:
This is why `has_voted` lives in the identity domain while the anonymous vote table stays identity-free.

### Task: Derive age band during vote submission

What you are doing:
Attach anonymous age data to the stored ballot.

What we should achieve:
- age band is derived from voter data
- the vote request does not carry raw birth date

Learning point:
The client should not tell the server its anonymous bucket. The server should derive it.

### Task: Derive residence bucket during vote submission

What you are doing:
Attach anonymous area data to the stored ballot.

What we should achieve:
- residence area is derived from voter data
- the vote request does not carry exact residence

Learning point:
Again, derive sensitive transforms server-side.

### Task: Persist anonymous vote record

What you are doing:
Store the ballot in a form that is useful but not directly linkable to the voter record.

What we should achieve:
- vote data is persisted
- no direct voter identifier is stored

Starter SQL shape:

```sql
insert into votes (referendum_id, choice, age_band, residence_area, receipt_hash, anchor_status)
```

### Task: Mark voter as having voted

What you are doing:
Consume the voter's ballot after a successful vote.

What we should achieve:
- the voter record updates after success
- failed submissions do not consume the ballot

Critical design point:
Do this in the same transaction as vote creation.

### Task: Return receipt placeholder in vote response

What you are doing:
Expose immediate audit information without waiting for blockchain confirmation.

What we should achieve:
- the vote response includes a receipt placeholder or hash
- the response does not block on chain confirmation

Suggested response shape:

```json
{
  "vote_id": "uuid-here",
  "receipt_hash": "0x...",
  "anchor_status": "pending"
}
```

### Task: Add duplicate-vote rejection test

What you are doing:
Prove the one-person-one-vote rule.

What we should achieve:
- a test submits two votes
- the second one is rejected

Learning point:
This is one of the most important business tests in the repo.

### Task: Add successful vote submission test

What you are doing:
Prove the full happy path from an eligible voter to a stored anonymous vote.

What we should achieve:
- automated test covers successful vote submission
- the response includes receipt data

Suggested assertions:
- `201` or `200`
- `receipt_hash` present
- voter marked as voted

Recommended test levels:

- route tests with `TestClient` for response contracts
- service tests for duplicate-vote and eligibility rules
- a small number of DB-backed integration tests for transaction boundaries

### Task: Add test that vote storage excludes identity fields

What you are doing:
Protect the privacy boundary with a regression test.

What we should achieve:
- the test confirms stored vote data has no direct identity field
- it fails if the model or schema regresses

How to think about it:
You are not only testing behavior. You are testing a design invariant.

## 10. Wave 7: Receipt Hashing and Audit State

This wave adds the blockchain-facing side without putting blockchain on the critical path.

### Task: Define receipt hash input contract

What you are doing:
Specify exactly which fields are hashed and in what order.

What we should achieve:
- hash input fields are documented
- ordering is deterministic

Recommended tuple:

```text
referendum_id | vote_id | choice | created_at | server_nonce
```

Good implementation rule:
Document the serialization format once, then reuse that exact function everywhere instead of rebuilding hash input ad hoc in different modules.

Learning point:
Deterministic hashing depends as much on field ordering as on field selection.

### Task: Add receipt hash generation service

What you are doing:
Compute the receipt hash after a vote is accepted.

What we should achieve:
- a service computes the hash
- the hash joins the vote and audit flow

Where to start:
Put this in `src/blockrendum/audit.py` or `src/blockrendum/blockchain.py` and return a hex string.

Starter line:

```python
digest = hashlib.sha256(payload_bytes).hexdigest()
```

### Task: Store pending audit status

What you are doing:
Track the fact that a vote has an audit receipt before the blockchain work completes.

What we should achieve:
- new receipts start as `pending`
- the status is persisted

Why this matters:
The vote path stays fast, and the docs remain honest about asynchronous anchoring.

### Task: Document blockchain anchoring as async follow-up

What you are doing:
Explain that vote acceptance does not wait for chain confirmation.

What we should achieve:
- docs say the vote path does not block on confirmation
- the async model is described briefly

Learning point:
This is one of the main architectural lessons of the project: blockchain is attached to the vote flow, not fused into the request latency path.

### Task: Add deterministic receipt hash test

What you are doing:
Prove hash stability.

What we should achieve:
- identical input produces identical hash
- changing one field changes the hash

Suggested assertions:
- same tuple twice -> same hash
- `choice=yes` vs `choice=no` -> different hash

## 11. Wave 8: Documentation, Diagrams, and Demo Notes

These tasks make the repo teachable, not just runnable.

### Task: Add architecture diagram draft

What you are doing:
Draw the boundaries between auth, vote, audit, and reporting.

What we should achieve:
- the diagram shows the major areas
- it is stored in the repo

Where to start:
Use Mermaid in Markdown if you want the lightest maintenance burden.

Good nodes:
- Client
- Mock Auth
- Eligibility
- Vote Service
- Postgres
- Audit Service
- EVM Testnet
- Reporting

### Task: Add API happy-path docs

What you are doing:
Document the main user journey.

What we should achieve:
- docs show `login -> referendum -> vote`
- example requests are included

Learning point:
Happy-path docs force endpoint naming and payload design to become coherent.

### Task: Add data-boundary note for identity vs ballot

What you are doing:
Write a short, explicit reminder of which fields belong where.

What we should achieve:
- docs explain what belongs in identity storage
- docs explain what belongs in ballot storage

Good contrast to document:
- identity side: provider subject, eligibility, birth date, residence region
- ballot side: choice, age band, residence area, receipt hash

### Task: Add POC limitations section near implementation status

What you are doing:
Keep the repo honest while implementation grows.

What we should achieve:
- docs restate the main limitations
- the note stays visible near project progress

Must include:
- no real `SPID` or `CIE`
- no production voting security guarantees
- no coercion resistance
- blockchain receipt anchoring is not the same as fair election verification

### Task: Add curl examples for happy path

What you are doing:
Make the demo easy to exercise manually without a frontend.

What we should achieve:
- docs include curl examples for health, login, referendum, and vote
- examples match the implemented endpoints

Suggested sequence:

1. `GET /api/v1/health`
2. `POST /api/v1/auth/mock-login`
3. `GET /api/v1/referendum/current`
4. `POST /api/v1/votes`

Learning point:
If curl examples feel awkward, the API design may still be awkward.

## 12. Suggested file and package direction

As you implement the backlog, this is a reasonable structure to grow toward:

```text
blockrendum/
  pyproject.toml
  alembic.ini
  alembic/
    versions/
  src/blockrendum/
    main.py
    config.py
    db.py
    api/
    auth/
    models/
    schemas/
    services/
    repositories/
    referendum/
    vote/
    audit/
    seed.py
  tests/
  seeds/
  docs/
```

Keep packages responsibility-focused. Avoid dumping unrelated code into generic modules like `utils.py`.

Recommended test layout:

- `tests/api/` for endpoint behavior
- `tests/services/` for business rules
- `tests/integration/` for DB-backed flows

## 13. Suggested endpoint map

If you want one coherent API surface while working through the tasks, use this:

- `GET /api/v1/health`
- `POST /api/v1/auth/mock-login`
- `GET /api/v1/referendum/current`
- `POST /api/v1/votes`
- `GET /api/v1/votes/receipts/{id}`

Potential read-only admin routes later:

- `GET /api/v1/admin/results`
- `GET /api/v1/admin/results/demographics`
- `GET /api/v1/admin/audit/receipts`

## 14. Suggested database tables

These table names line up well with the backlog:

- `voters`
- `referendums`
- `votes`
- `vote_receipts`
- optional later: `auth_sessions`

Recommended ownership:

- SQLAlchemy models define persistence fields and relationships
- Alembic owns schema change history
- services own transaction-level business rules

Important rule:
Even if you add auth sessions, they should point to the identity domain, not to the anonymous vote record.

## 15. Suggested implementation order inside a sprint

If you want a practical way to chip through the TSV without thrashing, follow this sequence:

1. repo hygiene: license, `.gitignore`, `.env.example`, task runner
2. runtime bootstrap: `src/blockrendum/main.py`, config loader, `/health`, graceful shutdown
3. data model: Pydantic schemas, SQLAlchemy models, and Alembic migrations
4. local demoability: compose, seeds, seed command, local verification
5. auth slice: mock login, lookup, eligibility, negative responses, tests
6. referendum slice: current referendum endpoint
7. vote slice: validation, anonymous persistence, consume ballot, receipt placeholder, tests
8. audit slice: deterministic hash, pending receipt state, async documentation
9. docs polish: diagram, curl flow, limitations note, data-boundary note

That order keeps the repo usable at every stage.

## 16. What success looks like when the whole guide is done

By the end of this backlog, you should be able to:

1. start local Postgres
2. run Alembic migrations
3. seed one referendum and mock voters
4. start the Python API
5. call `/api/v1/health`
6. log in as a seeded mock voter
7. fetch the active referendum
8. submit one `yes` or `no` vote
9. see the voter blocked from voting twice
10. inspect a receipt hash with `pending` audit state

If those steps work, the project has achieved its first real learning milestone.

## 17. Final advice while building

- Prefer small commits that each satisfy one backlog item or one tight cluster of related items.
- Keep writing tests for negative paths, not just happy paths.
- Do not put raw personal fields into the vote table "just for convenience."
- Do not block vote acceptance on blockchain confirmation.
- Keep the docs updated as soon as you choose names, routes, and payloads.

The repo becomes educational when the code and docs teach the same story.
