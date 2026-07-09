defmodule Trebejo do
  @moduledoc """
  Trebejo — Shell command wrappers and system utilities.

  Trebejo provides high-level wrappers around common shell commands
  (Docker, Git, SSH, Kubernetes, system inspection) built on top of
  `Arrea.Command` for execution and `Apero` for pure utilities.

  ## Architecture

  Trebejo is the shell layer of the stack:

  ```
  Trebejo (shell wrappers)
    ├── arrea (command execution)
    └── apero (pure utilities: Env, Crypto, File.Path, etc.)
  ```

  Unlike `Apero` (which stays dependency-free except for stdlib/hex),
  Trebejo depends on `Arrea.Command` for all shell execution.

  ## Modules

  ### Containers & Infra
  - `Trebejo.Docker` — Docker / Podman lifecycle management
  - `Trebejo.Kubernetes` — kubectl wrappers

  ### Git
  - `Trebejo.Git` / `Trebejo.Git.Local` — repository management

  ### System
  - `Trebejo.OS` — OS information (arch, kernel, memory, CPU count)
  - `Trebejo.Proc` — process listing, signalling, VM introspection
  - `Trebejo.SSH` — SSH command execution
  - `Trebejo.Network` — port checks, DNS, HTTP probes
  - `Trebejo.Compress` — zip/tar/gzip compression

  ### File
  - `Trebejo.File` — file watching (via Arrea.WorkerSupervisor)

  ## Migration from Apero

  Trebejo v1.0.0 extracts all shell-dependent functionality from Apero v2.x.
  Consumers that previously called `Apero.Docker.*`, `Apero.Git.*`,
  the shell-based OS functions (arch, kernel, memory, etc.) or the
  shell-based Proc functions (ps, kill, lsof, etc.) should now import
  those functions from `Trebejo.*`.

  For a complete migration guide see Apero's CHANGELOG.
  """
end
