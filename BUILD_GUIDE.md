# Building a Blockchain-Backed Referendum Voting POC in Go

## 1. Introduction

This document explains how to build a proof-of-concept referendum voting backend in Go.

The goal is educational: show how a modern digital referendum system could work if it combined:

- identity verification inspired by `SPID` or `CIE`
- one-person-one-vote rules
- anonymous vote storage
- simple demographic reporting
- blockchain-backed audit receipts

This is not a production voting system and must not be presented as one. It is a learning project that demonstrates architecture, flow separation, and core technical tradeoffs.

## 2. What This POC Does and Does Not Solve

### What it does

- Simulates login with `SPID` or `CIE`
- Exposes one active yes/no referendum
- Lets an eligible voter cast one vote
- Prevents duplicate voting in the backend
- Separates voter identity from ballot choice
- Stores coarse anonymous demographic data for reporting
- Anchors a receipt hash on an EVM testnet
- Exposes admin read endpoints for totals, demographics, and audit receipts
- Ships with seeded data so the system is demonstrable immediately

### What it does not solve

- Real legal identity verification
- End-to-end cryptographic ballot secrecy
- Coercion resistance
- Independent verifiability at national-election level
- Formal auditing requirements
- Production security hardening
- Real referendum governance and legal compliance

### Why this scope

If the POC tries to solve real-world e-voting end to end, it becomes a research and regulatory project rather than a practical software concept. This guide keeps the system simple enough to build and explain.

## 3. High-Level Architecture

The system has five logical parts:

1. `Auth`
   - simulates a trusted digital identity provider
   - issues a session or token for a seeded voter

2. `Eligibility`
   - checks whether the user is allowed to vote
   - ensures the ballot can only be consumed once

3. `Voting`
   - exposes the current referendum
   - accepts a yes/no vote
   - stores the vote without direct identity data

4. `Audit`
   - creates a receipt hash for the vote
   - anchors that receipt on an EVM testnet
   - stores transaction status

5. `Reporting`
   - returns totals
   - returns anonymous demographic breakdowns
   - returns receipt and anchoring status

### Data separation model

The most important design choice is this:

- voter identity is stored in one area of the system
- ballot choice is stored in another area
- reporting uses only anonymous demographic buckets

This is the minimum separation that makes the POC instructive.

### Why this choice

If identity and ballot stay in the same record, the system is easy to build but weak from a privacy standpoint. Separating them makes the architecture more realistic without requiring advanced cryptography.

## 4. Suggested Stack

Use these defaults:

- Language: Go
- Router: `chi`
- Database: PostgreSQL
- DB access: `pgx` or `database/sql`
- Migrations: `golang-migrate`
- Config: environment variables
- Blockchain client: `go-ethereum`
- Smart contract deployment target: EVM public testnet
- Auth model: simulated `SPID/CIE`

### Why Go is a good fit here

- it is simple for building HTTP APIs
- it handles concurrency well for background receipt anchoring
- it has mature PostgreSQL support
- it has native EVM tooling through `go-ethereum`
- it keeps the learning surface smaller than splitting backend logic across multiple languages

### Suggested project layout

```text
blockrendum/
  cmd/api/
  internal/auth/
  internal/config/
  internal/db/
  internal/referendum/
  internal/vote/
  internal/audit/
  internal/reporting/
  internal/httpapi/
  migrations/
  seeds/
  contracts/
  README.md
```

The exact layout can vary, but keep modules separated by responsibility.

## 5. Core Domain Model

Define the core entities before writing handlers.

### Entities

#### Voter

Represents the known person in the eligibility domain.

Example fields:

- `id`
- `provider_type` (`spid`, `cie`)
- `provider_subject`
- `first_name`
- `last_name`
- `date_of_birth`
- `residence_region`
- `is_eligible`
- `has_voted`
- `voted_at`
- `created_at`

#### Referendum

Represents one active yes/no ballot.

Example fields:

- `id`
- `title`
- `description`
- `question`
- `status` (`draft`, `active`, `closed`)
- `opens_at`
- `closes_at`

#### Vote

Represents the anonymous ballot record.

Example fields:

- `id`
- `referendum_id`
- `choice` (`yes`, `no`)
- `age_band`
- `residence_area`
- `receipt_hash`
- `anchor_status`
- `created_at`

#### VoteReceipt

Represents blockchain audit data.

Example fields:

- `id`
- `vote_id`
- `receipt_hash`
- `tx_hash`
- `chain_id`
- `block_number`
- `status` (`pending`, `confirmed`, `failed`, `synthetic`)
- `created_at`

### Design rule

Do not put `voter_id` in the final vote record if your goal is to keep identity separated from ballot choice.

### Why this choice

For the POC, the backend still knows whether someone has already voted, but it should not be able to answer, "Which exact voter chose yes?" from a single joined record.

## 6. Database Design

Start with a relational model. It is easier to explain and reason about than event sourcing for a first version.

### Recommended tables

#### `voters`

Stores seeded mock identities and eligibility data.

#### `referendums`

Stores the ballot definition.

#### `vote_submissions`

Stores anonymous vote data.

#### `vote_receipts`

Stores audit and blockchain anchoring data.

#### `auth_sessions`

Stores temporary login/session state.

### Example schema sketch

```sql
create table voters (
  id uuid primary key,
  provider_type text not null,
  provider_subject text not null unique,
  first_name text not null,
  last_name text not null,
  date_of_birth date not null,
  residence_region text not null,
  is_eligible boolean not null default true,
  has_voted boolean not null default false,
  voted_at timestamptz,
  created_at timestamptz not null default now()
);

create table referendums (
  id uuid primary key,
  title text not null,
  description text not null,
  question text not null,
  status text not null,
  opens_at timestamptz not null,
  closes_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table vote_submissions (
  id uuid primary key,
  referendum_id uuid not null references referendums(id),
  choice text not null,
  age_band text not null,
  residence_area text not null,
  receipt_hash text not null unique,
  anchor_status text not null,
  created_at timestamptz not null default now()
);

create table vote_receipts (
  id uuid primary key,
  vote_id uuid not null references vote_submissions(id),
  receipt_hash text not null unique,
  tx_hash text,
  chain_id bigint,
  block_number bigint,
  status text not null,
  created_at timestamptz not null default now()
);
```

### Missing link on purpose

Notice there is no `voter_id` inside `vote_submissions`.

Instead:

- `voters.has_voted` prevents duplicate votes
- `vote_submissions` stores only anonymous reporting fields

### Common mistake to avoid

Do not include highly specific location data such as full address, postal code, or municipality in the vote record. That makes re-identification much easier, especially in small populations.

## 7. Project Setup

Build the project in small phases.

### Step 1: Initialize the Go service

Objective:
Create a runnable API server with configuration loading and health checks.

Components to create:

- `cmd/api/main.go`
- `internal/config`
- `internal/httpapi`

Implementation steps:

1. Initialize a Go module.
2. Add routing, config, and DB dependencies.
3. Create a basic HTTP server.
4. Add a `/health` endpoint.
5. Wire the PostgreSQL connection.

Expected result:
A server starts locally and responds to a health check.

Verification:

- run the server
- call `GET /health`
- confirm DB connection errors fail clearly during startup

### Step 2: Add migrations and seed loading

Objective:
Create the schema and preload demo data.

Components to create:

- `migrations/`
- `seeds/`
- a seed runner command or startup flag

Implementation steps:

1. Add SQL migrations for all core tables.
2. Create a seed dataset for voters and one referendum.
3. Add a script or command to load the seed data.

Expected result:
The database can be recreated from zero and filled with demo records.

Verification:

- run migrations
- run seed command
- query the tables and confirm records exist

## 8. Simulated Identity Flow

Do not integrate real `SPID` or `CIE` for this POC. Simulate the experience and shape the interfaces as if a real integration could be added later.

### Why this choice

Real identity-provider integration adds external dependencies, legal setup, certificates, and protocol complexity. That would obscure the educational goal of this project.

### Recommended flow

1. Client chooses `SPID` or `CIE`
2. Client submits a mock subject identifier
3. Backend checks seeded voter records
4. If the voter exists and is eligible, backend creates a session
5. Backend returns a token

### Example login payload

```json
{
  "provider": "spid",
  "subject": "SPID-ALICE-001"
}
```

### Example login response

```json
{
  "access_token": "demo-token",
  "token_type": "Bearer",
  "expires_in": 3600,
  "voter": {
    "provider": "spid",
    "eligible": true
  }
}
```

### Files and components

- auth handler
- voter repository
- session store
- token middleware

### Common mistakes to avoid

- storing too much identity data in tokens
- treating mock login as anonymous login
- mixing session state with vote records

## 9. Referendum Retrieval and Eligibility

Before a vote is accepted, the backend must confirm:

- the referendum is active
- the voter is authenticated
- the voter is eligible
- the voter has not already voted

### Example endpoint

`GET /referendum/current`

### Example response

```json
{
  "id": "ref-2026-01",
  "title": "Digital Referendum POC",
  "question": "Do you approve the proposed public digital voting pilot?",
  "status": "active",
  "opens_at": "2026-03-25T08:00:00Z",
  "closes_at": "2026-03-26T20:00:00Z"
}
```

### Implementation notes

- keep only one active referendum in the POC
- if there is no active referendum, return a clear empty-state response
- validate the time window on every vote submission

### Why this choice

A single referendum keeps the guide focused. Multi-ballot election logic adds complexity without improving the main lesson.

## 10. Voting Flow

This is the core of the POC.

### Step-by-step vote path

1. Authenticate the voter
2. Fetch the active referendum
3. Verify eligibility and unused ballot
4. Derive anonymous reporting buckets from the voter profile
5. Generate a receipt hash
6. Store the anonymous vote
7. Mark the voter as having voted
8. Create or queue the blockchain receipt anchor
9. Return the vote receipt

### Example vote payload

```json
{
  "referendum_id": "ref-2026-01",
  "choice": "yes"
}
```

### Example vote response

```json
{
  "vote_id": "7e4b5d85-58e0-4c98-9c99-d2d6af3f4ea1",
  "receipt_hash": "0x8c0f...",
  "anchor_status": "pending"
}
```

### Transactional rule

The write path should be transactional.

At minimum, this sequence should succeed or fail together:

- confirm voter has not voted
- insert anonymous vote
- mark voter as voted
- create receipt record

### Why this choice

Without a transaction, duplicate voting and inconsistent audit records become much easier to create.

### Common mistake to avoid

Do not mark the voter as voted before the vote record is safely written.

## 11. Anonymous Demographic Reporting

The user wanted reporting by age and area while preserving anonymity. For a POC, the safest simple approach is bucketization.

### Recommended buckets

#### Age bands

- `18-25`
- `26-35`
- `36-50`
- `51-65`
- `65+`

#### Residence areas

- `Nord`
- `Centro`
- `Sud-Isole`

These are derived from the voter profile at vote time.

### Important privacy rule

Store only the derived bucket values in the anonymous vote record. Do not store raw birth date or full residence data there.

### Example demographic response

```json
{
  "by_age_band": [
    { "band": "18-25", "yes": 21, "no": 9 },
    { "band": "26-35", "yes": 34, "no": 17 }
  ],
  "by_residence_area": [
    { "area": "Nord", "yes": 40, "no": 12 },
    { "area": "Centro", "yes": 18, "no": 10 }
  ]
}
```

### Why this choice

It allows useful reporting without storing direct identifying attributes next to the ballot.

### Production reality

Even coarse analytics can create re-identification risks in small groups. A real system would need stronger statistical disclosure controls.

## 12. Blockchain Receipt Anchoring

The blockchain part should stay minimal.

### Recommended design

Do not put the whole vote on-chain.

Instead:

- create a deterministic receipt hash
- send that hash to a simple smart contract
- emit an event or store the hash
- keep the full vote off-chain

### Example receipt input shape

The hash can be generated from a stable tuple such as:

```text
referendum_id | choice | created_at | server_nonce
```

The exact format can vary, but it should be deterministic once the vote is accepted.

### Contract responsibility

The contract should do one thing well:

- accept a receipt hash
- emit `VoteAnchored(receiptHash, timestamp, sender)`

That is enough for a POC.

### Why this choice

This keeps gas costs and chain complexity low while still demonstrating auditability.

### Example receipt record

```json
{
  "receipt_hash": "0x8c0f...",
  "tx_hash": "0x2d14...",
  "chain_id": 11155111,
  "status": "confirmed",
  "block_number": 5821941
}
```

### Local and demo mode

The guide should support two operating modes:

- real testnet anchoring when credentials are configured
- synthetic anchoring when no blockchain credentials exist

Synthetic mode should label receipts clearly as synthetic so the demo does not misrepresent them.

### Common mistake to avoid

Do not pretend synthetic receipts are actual blockchain confirmations.

## 13. API Design

Keep the HTTP surface small.

### Public endpoints

- `POST /auth/spid/mock-login`
- `POST /auth/cie/mock-login`
- `GET /referendum/current`
- `POST /vote`
- `GET /vote/receipt/{id}`

### Read-only admin endpoints

- `GET /admin/referendum/status`
- `GET /admin/results`
- `GET /admin/results/demographics`
- `GET /admin/audit/receipts`
- `GET /admin/audit/receipts/{id}`

### Example results response

```json
{
  "referendum_id": "ref-2026-01",
  "status": "active",
  "turnout": 150,
  "totals": {
    "yes": 96,
    "no": 54
  },
  "anchoring": {
    "confirmed": 120,
    "pending": 30
  }
}
```

### Endpoint rules

- all vote endpoints require authentication
- admin endpoints are read-only in this POC
- no endpoint returns full voter identity together with vote choice

## 14. Demo Data and Seeding

Because this is a concept system, it should not start empty.

### What to seed

- one active referendum
- a registry of mock voters
- a mix of already-voted and not-yet-voted users
- vote submissions with anonymous demographic buckets
- receipt records with either synthetic or real-looking testnet metadata

### Example seeded voter

```json
{
  "provider_type": "spid",
  "provider_subject": "SPID-ALICE-001",
  "first_name": "Alice",
  "last_name": "Rossi",
  "date_of_birth": "1992-04-12",
  "residence_region": "Lazio",
  "is_eligible": true,
  "has_voted": false
}
```

### Example seeded vote

```json
{
  "referendum_id": "ref-2026-01",
  "choice": "yes",
  "age_band": "26-35",
  "residence_area": "Centro",
  "receipt_hash": "0x8c0f...",
  "anchor_status": "confirmed"
}
```

### Why this choice

If the system starts empty, the admin reporting and blockchain story are difficult to demonstrate.

## 15. Testing Strategy

This POC should be validated mainly through integration-style scenarios.

### Core scenarios

#### Login

- seeded SPID voter can log in
- seeded CIE voter can log in
- unknown identity is rejected

#### Voting

- eligible voter can cast one vote
- second vote from the same voter is rejected
- vote outside the referendum window is rejected

#### Privacy

- vote table contains no direct voter identity
- reporting endpoints expose only coarse aggregates

#### Audit

- receipt hash is generated for every accepted vote
- receipt record is created
- anchor status changes from `pending` to `confirmed` in real-chain mode
- synthetic mode still returns a visible receipt record

#### Reporting

- totals endpoint returns yes/no counts
- demographics endpoint returns bucketed data
- seeded data produces non-empty reports immediately

### Example test checklist

```text
[ ] Create database from scratch
[ ] Apply migrations
[ ] Load seed data
[ ] Log in as a seeded voter
[ ] Fetch current referendum
[ ] Submit a yes vote
[ ] Verify the same voter cannot vote again
[ ] Fetch receipt by ID
[ ] Fetch admin totals
[ ] Fetch demographic breakdown
```

## 16. Security and Privacy Caveats

This section must remain explicit in the project because it prevents the POC from being misunderstood.

### Caveats to state clearly

- simulated `SPID/CIE` is not real identity assurance
- backend-enforced ballot uniqueness is weaker than cryptographic one-time voting
- off-chain vote storage means the operator remains trusted
- blockchain anchoring proves receipt existence, not election fairness
- demographic reporting can still create privacy risk if groups are too small
- the system has no anti-coercion protections
- the system has no end-to-end verifiable tallying

### Production reality

A real civic voting platform would require:

- formal threat modeling
- external audits
- legal approval
- robust cryptographic protocols
- operational segregation of duties
- incident response and observability
- independent verification mechanisms

## 17. Step-by-Step Build Sequence

If another engineer uses this guide as a build manual, they should follow this order:

1. Initialize the Go project and server bootstrap.
2. Add configuration and database wiring.
3. Write SQL migrations.
4. Seed mock voters and one referendum.
5. Implement mock `SPID/CIE` login.
6. Add auth middleware and sessions.
7. Add current referendum retrieval.
8. Implement vote submission transactionally.
9. Derive anonymous age and area buckets.
10. Add vote receipt creation.
11. Integrate EVM testnet anchoring.
12. Add read-only admin reporting endpoints.
13. Add synthetic anchoring fallback for demo mode.
14. Write integration tests for the main flows.

That order keeps the system demonstrable at every stage.

## 18. Common Mistakes To Avoid

- building real identity integration too early
- storing `voter_id` directly in the anonymous ballot table
- placing plaintext vote data on-chain
- keeping analytics too granular
- designing too many referendum types for the first version
- skipping seeded data and ending with an empty demo
- forgetting to label synthetic blockchain behavior clearly

## 19. Next Steps

Once the POC guide has been followed, the next sensible expansions are:

- add a small web UI
- add a queue for background blockchain anchoring
- add stronger admin authentication
- improve audit logs
- add contract deployment scripts
- document a migration path toward a more privacy-preserving design

For now, the correct goal is clarity, not sophistication. The POC should teach how such a system could be structured, where trust boundaries live, and why blockchain alone does not solve digital voting.
