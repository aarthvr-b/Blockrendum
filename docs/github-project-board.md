# GitHub Project Board for Blockrendum

This document is the source of truth for the `Project Blockrendum` workflow.

## Board layout

Use a simple kanban with these statuses:

- `Backlog`: approved but not ready
- `Ready`: clear acceptance check, no blockers
- `In Progress`: currently being worked
- `Blocked`: waiting on an external dependency or decision
- `Done`: implemented and accepted

## Operating rules

- Keep `In Progress` limited to 1-2 items.
- Default new tasks to `Backlog`.
- Move a task to `Ready` only when its acceptance check is concrete.
- Prefer `XS` tasks. Split any task that spans multiple sessions.
- Use GitHub Issues as the task source and the Project as the status view.

## Project fields

Create these single-select fields in the GitHub Project:

### `Status`

- `Backlog`
- `Ready`
- `In Progress`
- `Blocked`
- `Done`

### `Area`

- `Setup`
- `API`
- `Data`
- `Auth`
- `Voting`
- `Blockchain`
- `Admin`
- `Docs`

### `Size`

- `XS`
- `S`

### `Outcome`

- `Foundation`
- `Demo Flow`
- `Audit`
- `Reporting`

### `Priority`

- `P0`
- `P1`
- `P2`

## Labels

Create these repo labels:

- `area:setup`
- `area:api`
- `area:data`
- `area:auth`
- `area:voting`
- `area:blockchain`
- `area:admin`
- `area:docs`
- `size:xs`
- `size:s`
- `type:task`
- `type:decision`
- `type:spike`
- `blocked`

## First delivery wave

The first active wave is backend foundation plus a minimal voting slice:

1. local setup and Go skeleton
2. API bootstrap and health endpoint
3. core data model and seeded demo data
4. simulated identity flow
5. referendum read endpoint
6. vote submission with duplicate-vote protection
7. receipt hash generation with pending audit status

Admin reporting, blockchain confirmation depth, and frontend work stay in the backlog until that slice works end to end.

## Repo automation

The repo includes a manual workflow at `.github/workflows/seed-project.yml`.

Use it to seed labels and issues from `docs/github-project-issues.tsv` into the GitHub Project.

Required setup:

- Add a repository secret named `PROJECT_AUTOMATION_TOKEN`
- Use a classic personal access token with `repo` and project access
- Set `project_number` in the workflow dispatch form if you want to avoid project lookup by title
