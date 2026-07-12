# Changelog

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
