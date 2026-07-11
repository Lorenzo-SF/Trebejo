defmodule Trebejo do
  @moduledoc """
  Trebejo — Shell command wrappers and system utilities.

  Trebejo provides high-level wrappers around common shell commands
  (Docker, Git, SSH, Kubernetes, system inspection) built on top of
  `Arrea.Command` for execution.

  ## Architecture

  Trebejo is the shell layer of the stack:

  ```
  Trebejo (shell wrappers)
    └── arrea (command execution)
  ```

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
  """
end
