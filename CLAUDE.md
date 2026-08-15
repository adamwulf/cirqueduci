# CLAUDE.md

Guidance for Claude Code when it works in this repository.

## What this is

`cirqueduci` is a command-line tool for the CircleCI v2 REST API. It lists
pipelines, workflows, and jobs. It triggers pipelines, approves manual-approval
gates, watches pipelines until they finish, and pulls step logs, artifacts, and
test metadata.

The project is a Swift package with two targets. All logic is in the
`CircleCIKit` library. The `cirqueduci` executable is a thin wrapper. The
executable parses arguments, calls into `CircleCIKit`, and formats output. Do not
put business logic in the executable.

## Build and test

```bash
swift build
swift test
```

Tests do not use the live network. Each test injects a `StubTransport` that
returns canned JSON. This makes URL building, headers, pagination, and decoding
verifiable offline.

## Repository structure

- `Package.swift` — the package manifest. It declares the two targets, the two
  test targets, and the single dependency (`swift-argument-parser`).
- `Sources/CircleCIKit/` — the library. It holds the API client, the models, the
  HTTP layer, `.env` discovery, token resolution, and output formatting.
- `Sources/cirqueduci/` — the executable. It holds the root command and one file
  per subcommand.
- `Tests/CircleCIKitTests/` — the library tests, with shared helpers in
  `Support/`.
- `Tests/CLITests/` — the command-parsing tests for the executable.

### Inside `Sources/CircleCIKit/`

- `APIs/` — the client. There are two layers (see Architecture below):
  `CircleCIAPI` (low-level) and `CircleCIClient` (high-level facade). The facade
  has extensions for logs, watch, and artifacts.
- `Models/` — the `Codable` request and response types (pipelines, workflows,
  jobs, steps, artifacts, projects, and the `Paged` and `Status` helpers).
- `HTTP/` — the `HTTPTransport` protocol and its `URLSession` implementation.
  Tests replace the transport.
- `Helpers/` — output formatting (`OutputFormatter`, `Rows`) and JSON coding
  (`CircleCIJSON`).
- `CircleCIError.swift`, `DotEnv.swift`, `TokenResolver.swift` — the error type,
  the `.env` reader, and the token resolver.

### Inside `Sources/cirqueduci/`

- `Cirqueduci.swift` — the `@main` root command. It lists every subcommand,
  resolves the token once at start, and holds the shared `emit` helper and shared
  option groups.
- `Commands/` — one file per subcommand (for example `PipelinesCommand`,
  `TriggerCommand`, `ApproveCommand`, `WatchCommand`, `LogsCommand`).

## Architecture

The client has two layers. Keep the split when you add features.

- `CircleCIAPI` (low-level) — holds the token and the injectable
  `HTTPTransport`. It builds each request with the `Circle-Token` header and
  returns **one page** as `Result<Model, CircleCIError>`. Retry and backoff for
  429 and 5xx responses live here.
- `CircleCIClient` (high-level facade) — wraps `CircleCIAPI`. It `throws` typed
  errors, walks pages until the limit or the last page, and returns arrays.
  **Pagination lives only here**, not in the low-level client. This is the entry
  point the CLI and higher-level code use.

The design mirrors the `hunch` tool: `CircleCIAPI` is like `NotionAPI`, and
`CircleCIClient` is like `HunchAPI`. Unlike `hunch`, the initializers are public
and take the transport, so tests inject canned JSON.

## Conventions

- Every listing command accepts `--format table|json|jsonl|id`. The default is
  `table`.
- Project slugs use the v2 form, for example `gh/museapphq/Muse`.
- The token comes from the `CIRCLECI_API_KEY` environment variable (with
  `CIRCLECI_TOKEN` as a fallback). If neither is set, the tool searches up the
  directory tree for a `.env` file and reads the same keys. It sends the token as
  the `Circle-Token` header.
- Keep the executable thin. Add new behavior to `CircleCIKit` and call it from a
  command.

## More detail

See `README.md` for the full command reference and end-to-end examples.
