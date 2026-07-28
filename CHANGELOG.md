# Changelog

## Unreleased

### Fixed

- `Trebejo.Proc.parse_tasklist/1` no longer raises `MatchError` on Windows rows with a number of columns other than 5. Bad rows are now logged and skipped.
- `Trebejo.Proc.parse_ps_output/1` and `parse_tasklist/1` emit `Logger.warning` instead of silently dropping malformed input.
- `Trebejo.Proc.logs/2` body depth reduced to 2 by extracting `logs_linux/2` and `logs_macos/2` helpers; the file-level credo disable for `CyclomaticComplexity` is no longer needed.
- `Trebejo.Packages.installed?/2` `@spec` tightened from `boolean | {:error, String.t()}` to `boolean()` — no clause actually returns `{:error, _}`.

### Removed

- `Trebejo.SafeCommand.run_legacy/3` — dead code, only referenced in its own docstring. Use `Trebejo.Util.run_cmd_legacy/3` directly.

## 1.0.0 (2026-07-09)

### Initial release

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

## Added safe command wrapper

- Introduced `Trebejo.SafeCommand` to validate and safely execute system commands.
- Provides `execute/2` with basic safety checks.
- Updated documentation accordingly.
