# Blockrendum

Blockrendum is an educational proof of concept for a digital referendum platform inspired by the Italian voting context. The idea is simple: a citizen logs in with a flow similar to `SPID` or `CIE`, casts a vote in a referendum, and the system records an auditable blockchain-backed receipt while keeping the ballot itself anonymous.

This repository is not meant to propose a production-ready national voting system. Its purpose is to explore how such a platform could be structured, where trust boundaries would live, and which parts of the system belong on-chain versus off-chain.

## Why This Project Exists

Traditional referendum voting is still largely physical and paper-based. That process has strengths, but it also feels distant from the digital identity systems and online public services that already exist.

Blockrendum explores a practical question:

> What could a modern referendum voting platform look like if identity verification, ballot submission, and auditability were designed as separate concerns?

The answer in this POC is:

- authenticate the voter through a simulated digital identity flow
- enforce one-person-one-vote in the backend
- store the ballot separately from personal identity
- keep only anonymous demographic insights for reporting
- anchor a receipt hash on a blockchain testnet for traceability

## Core Idea

The system is intentionally modest. It does not try to solve all of digital democracy.

Instead, it demonstrates a small but meaningful architecture:

1. A voter authenticates through a simulated `SPID` or `CIE` flow.
2. The backend verifies eligibility.
3. The voter casts a `yes` or `no` vote in a referendum.
4. The system stores the vote without a direct personal identifier attached to it.
5. A receipt hash is generated and anchored on an EVM-compatible blockchain testnet.
6. Admin reporting can show turnout and anonymous demographic breakdowns without revealing who voted for what.

## What The POC Includes

- Simulated login modeled after Italian digital identity systems
- A single active referendum with a simple yes/no ballot
- Backend duplicate-vote prevention
- Anonymous vote storage
- Coarse demographic reporting such as age band and area of residence
- Blockchain-backed receipt anchoring for audit visibility
- Seeded mock data so the demo does not start empty
- Read-only admin/reporting endpoints

## What It Deliberately Does Not Include

- Real `SPID` integration
- Real `CIE` integration
- Production-grade cryptographic voting protocols
- End-to-end verifiable tallying
- Coercion resistance
- Legal or institutional compliance for real elections
- Full national-scale security architecture

Those omissions are deliberate. A real remote voting system is a much bigger challenge than "put votes on a blockchain." This project treats blockchain as one auditing component, not as the complete solution.

## Technology Direction

The intended implementation direction for this project is:

- `Go` for the API backend
- `PostgreSQL` for persistence
- `go-ethereum` for EVM blockchain interaction
- An EVM public testnet for receipt anchoring

This is a good fit for a POC because Go keeps the backend compact and fast, PostgreSQL makes relational data easy to reason about, and EVM tooling is mature enough for simple contract interactions.

## Architectural Principles

### 1. Identity and ballot must be separated

The system should know whether a voter has already used their ballot, but it should avoid storing a direct identity-to-choice link in the final vote record.

### 2. Blockchain should anchor proof, not expose the vote

The blockchain is used to anchor a receipt hash or emit an event that proves a vote record existed at a certain point. The vote itself should remain off-chain.

### 3. Reporting should be useful but privacy-aware

The project may store anonymous demographic buckets such as:

- age band
- broad residence area

It should not store high-granularity personal data alongside the ballot.

### 4. The system should be easy to demo

Since this is a concept repository, it should be demonstrable with mock voters, seeded referendum data, and sample results.

## Example User Flow

1. A demo voter logs in through a mocked `SPID` or `CIE` endpoint.
2. The backend checks that the referendum is active and that the voter is eligible.
3. The voter submits a `yes` or `no` choice.
4. The backend stores the anonymous vote record.
5. The backend marks the voter as having voted.
6. A receipt hash is generated and anchored, or queued for anchoring, on a blockchain testnet.
7. Admin APIs can later show turnout, anonymous aggregates, and receipt status.

## Example Data Boundaries

The educational value of this project depends heavily on keeping boundaries clear.

### Identity domain

Contains information needed for authentication and eligibility:

- provider type
- provider subject
- birth date
- residence region
- eligibility status
- whether the voter has already voted

### Ballot domain

Contains anonymous vote data only:

- referendum id
- choice
- age band
- broad residence area
- receipt hash
- audit status

### Audit domain

Contains blockchain anchoring metadata:

- receipt hash
- transaction hash
- chain id
- block number
- confirmation status

## Why Blockchain Is Used Here

The blockchain part of the project is intentionally narrow.

It is not used to magically make the entire voting system trustworthy. Instead, it provides:

- immutable-style anchoring of vote receipts
- a visible audit trail
- an easy way to demonstrate that a record was committed externally

That makes it useful for a demo, but not sufficient for a real public election.

## Repository Status

This repository is currently focused on design and implementation planning for the POC. The intended deliverables are:

- a clean backend API in Go
- a clear data model
- a small smart contract or event-based receipt anchor
- seeded demo data
- educational documentation that explains how the system works

## Project Positioning

Blockrendum should be presented as:

- an educational backend concept
- a civic-tech exploration
- a software architecture exercise
- a conversation starter around digital voting design

It should not be presented as:

- a production e-voting system
- a secure replacement for official referendum infrastructure
- proof that blockchain alone solves digital voting

## Possible Future Extensions

- a small web frontend for demo voting
- stronger admin authentication
- background jobs for blockchain anchoring
- contract deployment scripts
- more advanced privacy-preserving reporting
- documentation comparing this POC with real-world voting requirements

## Short Repo Description

Go-based POC for a digital referendum system with simulated SPID/CIE login, anonymous voting, and blockchain-backed audit receipts.

## License

License to be decided.
