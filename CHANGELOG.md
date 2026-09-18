# Changelog

All notable changes to Trebejo are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-09-18

### Added

- **`Trebejo.Error`** — typed error wrapper around raw command
  failures (`lib/trebejo/error.ex`). The struct carries a `kind/0` of
  `:not_found | :permission_denied | :invalid_args | :timeout |
  :signal | :exit_nonzero | :port_closed | :circuit_open |
  :rate_limited | :bulkhead_full | :unknown`, plus the raw exit code,
  command line, stderr and duration. `Trebejo.Error.classify_exit/1`
  maps Unix exit codes to kinds (127 → `:not_found`, 126 →
  `:permission_denied`, 130/137/143/139 → `:signal`, etc).
- **`Trebejo.Stream`** — `Port.open/2`-based streaming runner
  (`lib/trebejo/stream.ex`). `open/3` returns a lazy `Stream.t()` of
  stdout chunks; `lines/3` yields complete lines. `:stderr` option is
  `:merge` only (`:separate` deprecated in 2.0, reserved for 2.1).
- **`Trebejo.Runner`** — behaviour for executing external commands
  with a swappable runner. The default `Trebejo.Util.Runner` delegates
  to `Trebejo.Util.run_cmd/3`; tests can install `Trebejo.Mox.Runner`
  via `Trebejo.Runner.set_runner/1`.
- **`Trebejo.Mox`** — minimal stubbing layer for tests. `stub_cmd/3`
  intercepts a specific `(cmd_name, args)` triple; `stub_cmd_pattern/2`
  matches a regex on the joined command line; `reset_stubs/0` clears.
  Stubs live in `Trebejo.Mox.Server` (an `Agent`).
- **`Trebejo.Breaker`** — circuit-breaker integration
  (`lib/trebejo/breaker.ex`). `with_breaker/3` wraps an arbitrary
  function in `Arrea.CircuitBreaker.call/3`, lazily starting the
  breaker on first use. Translates `Arrea` errors into
  `%Trebejo.Error{kind: :circuit_open | :timeout | :unknown}`.
- **`Trebejo.Postgres`** — `psql` / `pg_dump` / `pg_restore` wrapper
  (`lib/trebejo/postgres.ex`). `execute/2`, `dump/1`, `restore/1`,
  `stream/2`. Supports `:host`, `:port`, `:user`, `:database`,
  `:password` (passed as `PGPASSWORD` env var, never `-W`), `:format`,
  `:timeout`, `:breaker`.
- **`Trebejo.Redis`** — `redis-cli` wrapper (`lib/trebejo/redis.ex`).
  `run/2`, `ping?/1`, `monitor/1`. Supports `:host`, `:port`,
  `:database`, `:password` (via `-a` or `REDISCLI_AUTH` env var with
  `:auth, :env`), `:tls`, `:timeout`, `:breaker`.
- **`Trebejo.GitHub`** — `gh` CLI wrapper (`lib/trebejo/github.ex`)
  for the highest-ROI subcommands: `pr` (`pr_list`, `pr_view`,
  `pr_create`), `issue` (`issue_list`, `issue_view`, `issue_create`),
  `release` (`release_list`, `release_create`). Plus a generic
  `Trebejo.GitHub.run/2` for anything else.
- **Integration tests** — `test/integration_test.exs` probes real
  binaries (`git`, `docker`, `redis-cli`, `psql`, `gh`) with `@tag
  :integration`. Skip-by-default; run with `mix test --only
  integration`.
- **`Trebejo.SafeCommand`** — validated wrapper around
  `Arrea.Command.execute/2`: single entry point for all shell
  execution with basic safety checks.

### Changed

- **`Trebejo.Util.run_cmd/3`** now wraps every error path in a
  `%Trebejo.Error{}` and applies a default `:timeout` of 30 s
  (was unlimited; passthrough to `Arrea.Command`).
- **`Trebejo.Util.run_ok/3`** return type changed from
  `{:error, binary()}` to `{:error, %Trebejo.Error{}}`. Existing
  call-sites only pattern-match on `:ok` or `{:error, _}` so the
  change is source-compatible.
- **Trebejo 2.0 depends on `Arrea` 3.0** (required for
  `Arrea.CircuitBreaker` single-flight + `Arrea.Telemetry`).

### Removed

- `Trebejo.SafeCommand.run_legacy/3` — dead code, only referenced in its own docstring. Use `Trebejo.Util.run_cmd_legacy/3` directly.

### Fixed

- `Trebejo.Proc.parse_tasklist/1` no longer raises `MatchError` on Windows rows with a number of columns other than 5. Bad rows are now logged and skipped.
- `Trebejo.Proc.parse_ps_output/1` and `parse_tasklist/1` emit `Logger.warning` instead of silently dropping malformed input.
- `Trebejo.Proc.logs/2` body depth reduced to 2 by extracting `logs_linux/2` and `logs_macos/2` helpers; the file-level credo disable for `CyclomaticComplexity` is no longer needed.
- `Trebejo.Packages.installed?/2` `@spec` tightened from `boolean | {:error, String.t()}` to `boolean()` — no clause actually returns `{:error, _}`.

## [1.0.0] - 2026-07-09

### Added

Trebejo is the shell-command layer extracted from Apero v2.x.

- **`Trebejo.Docker`** — Docker/Podman lifecycle (from `Apero.Docker`)
- **`Trebejo.Git` / `Trebejo.Git.Local`** — Git repository management (from `Apero.Git`)
- **`Trebejo.OS`** — OS inspection including arch, kernel, memory, CPU count (shell-based parts from `Apero.OS`)
- **`Trebejo.Proc`** — Process listing, signalling, VM introspection (shell-based parts from `Apero.Proc`)
- **`Trebejo.SSH`** — SSH command execution (from `Apero.SSH`)
- **`Trebejo.Kubernetes`** — kubectl wrappers (from `Apero.Kubernetes`)
- **`Trebejo.Compress`** — zip/tar/gzip (from `Apero.Compress`)
- **`Trebejo.Network`** — network probes (from `Apero.Network`)
- **`Trebejo.File`** — file watching via Arrea.WorkerSupervisor (from Apero.File.watch, which moved to Trebejo.File)

All dependencies on `Arrea.Command` are internal to Trebejo. Apero remains a pure utility library with no Arrea dependency.

[2.0.0]: https://hex.pm/packages/trebejo/2.0.0
[1.0.0]: https://hex.pm/packages/trebejo/1.0.0
[Unreleased]: https://github.com/Lorenzo-SF/trebejo/compare/2.0.0...HEAD
