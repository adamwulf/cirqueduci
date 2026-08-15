# cirqueduci

A command-line tool for the [CircleCI](https://circleci.com) v2 REST API. View
current and recent pipelines, trigger them, approve manual-approval gates, watch
them to completion, and pull step logs and artifacts.

`cirqueduci` is built as a Swift package: all logic lives in the `CircleCIKit`
library (fully unit-tested against mocked API replies — no live network in
tests), and the CLI executable is a thin wrapper that parses arguments and
formats output.

## Installation

Install globally using [Mint](https://github.com/yonaskolb/Mint):

```bash
mint install adamwulf/cirqueduci@main --force
```

Or build from source:

```bash
swift build -c release
cp .build/release/cirqueduci /usr/local/bin/
```

## Authentication

`cirqueduci` reads a CircleCI [personal API token](https://app.circleci.com/settings/user/tokens)
from the environment variable `CIRCLECI_API_KEY` (with `CIRCLECI_TOKEN` accepted
as a fallback). If neither is set, it searches **up** the directory hierarchy for
a `.env` file and reads the same keys from it:

```bash
# .env
CIRCLECI_API_KEY=your_circleci_personal_token
```

The token is sent to CircleCI as the `Circle-Token` header.

## Usage

Every listing command accepts `--format table|json|jsonl|id` (default `table`).
Project slugs use the v2 form, e.g. `gh/museapphq/Muse`.

```bash
# Who am I / my orgs
cirqueduci me
cirqueduci me --orgs

# List followed projects, or show one
cirqueduci projects
cirqueduci projects gh/museapphq/Muse

# List pipelines for a project (optionally by branch), an org, or by id
cirqueduci pipelines --project gh/museapphq/Muse --branch main --limit 10
cirqueduci pipelines --org gh/museapphq --mine
cirqueduci pipelines <pipeline-id>

# See everything with activity in a recent window, with each pipeline's workflow rollup
cirqueduci recent --project gh/museapphq/Muse                       # last 24h (default)
cirqueduci recent --project gh/museapphq/Muse --hours 6 --running   # only what's still in progress

# Drill down: pipeline -> workflows -> jobs
cirqueduci workflows <pipeline-id>
cirqueduci jobs <workflow-id>
cirqueduci jobs <workflow-id> --approvable      # only manual-approval gates

# Job details, steps, and logs (needs the project slug + build job number)
cirqueduci job 40796 --project gh/museapphq/Muse
cirqueduci steps 40796 --project gh/museapphq/Muse
cirqueduci logs 40796 --project gh/museapphq/Muse
cirqueduci logs 40796 --project gh/museapphq/Muse --step "Spin up environment" --raw

# Artifacts and test metadata
cirqueduci artifacts 40796 --project gh/museapphq/Muse
cirqueduci artifacts 40796 --project gh/museapphq/Muse --download ./artifacts
cirqueduci tests 40796 --project gh/museapphq/Muse

# Trigger (start) a pipeline
cirqueduci trigger --project gh/museapphq/Muse --branch main
cirqueduci trigger --project gh/museapphq/Muse --tag v1.2.3 --param deploy=true

# Approve a manual-approval gate (e.g. the release-mac gate)
cirqueduci approve <workflow-id>                      # when there is one gate
cirqueduci approve <workflow-id> --job approve-mac-release
cirqueduci approve <workflow-id> --approval-request-id <id>

# Cancel / rerun a workflow
cirqueduci cancel <workflow-id>
cirqueduci rerun <workflow-id>

# Watch until finished (polls; prints status each interval; exit code reflects result)
cirqueduci watch <pipeline-id>                          # a whole pipeline's workflows
cirqueduci watch 40796 --project gh/museapphq/Muse      # a single build job, by its number
# Exit codes: 0 = success, 1 = finished but unsuccessful, 2 = timed out. Default interval 60s.
```

### End-to-end (agent) flow

```bash
# start a build, capture its pipeline id, watch it, approve the release gate, pull logs
PIPELINE=$(cirqueduci trigger --project gh/museapphq/Muse --branch main --format id)
cirqueduci watch "$PIPELINE"
WORKFLOW=$(cirqueduci workflows "$PIPELINE" --format id | head -1)
cirqueduci approve "$WORKFLOW" --job approve-mac-release
cirqueduci logs 40796 --project gh/museapphq/Muse
```

## Architecture

- **`CircleCIKit`** (library) — the API client, request/response models, `.env`
  discovery, token resolution, and output formatting. The HTTP layer is abstracted
  behind an `HTTPTransport` protocol so the client is unit-tested with canned JSON
  and no live network.
  - `CircleCIAPI` — low-level client: one page per call, returns `Result`.
  - `CircleCIClient` — high-level facade: throws, paginates, returns arrays.
- **`cirqueduci`** (executable) — a thin [ArgumentParser](https://github.com/apple/swift-argument-parser)
  command tree. No business logic; it calls into `CircleCIKit` and formats output.

## Development

```bash
swift build
swift test
```

Tests inject a `StubTransport` that returns canned JSON, so the whole client —
URL building, headers, pagination, decoding — is verified offline.
