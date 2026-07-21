# Trebejo

Shell-dependent system utilities extracted from [Apero](https://hex.pm/packages/apero).

## Why Trebejo?

Apero was split into two packages:

| Package | Contents |
|---------|----------|
| **apero** (≥ 3.0.0) | Pure stdlib wrappers — Env, Conf, Retry, Crypto, Cache, File trees/paths, OS type/hostname/distro/container/WSL, Proc which/command\_exists? |
| **trebejo** | Shell-dependent operations — Docker, Git, SSH, Kubernetes, Compress, Network, OS info (arch, kernel, cpu, memory, root), Proc listing/signalling, File watch, Image, Package install |

## Modules

| Module | Description |
|--------|-------------|
| `Trebejo.Docker` | Docker / Podman container lifecycle |
| `Trebejo.Git` | Git repository operations (thin facade over `Trebejo.Git.Local`) |
| `Trebejo.Git.Local` | Low-level git CLI wrappers (commit, branch, log, churn, …) |
| `Trebejo.SSH` | SSH connections and remote command execution |
| `Trebejo.Kubernetes` | kubectl wrappers for cluster resources |
| `Trebejo.Compress` | Archive creation and extraction (zip, tar, gzip) |
| `Trebejo.Network` | Network interface and connectivity probes |
| `Trebejo.OS` | OS metadata: arch, kernel, CPU, memory, root — shell-based. Pure OS detection (type, hostname, distro, WSL, container) lives in `Apero.OS` |
| `Trebejo.Proc` | Process listing, signalling, lsof, fuser, log access |
| `Trebejo.Packages` | Package installation and querying (apt, brew, pacman, …) |
| `Trebejo.Image` | Container / VM image inspection helpers |
| `Trebejo.File` | File system watching via Arrea.WorkerSupervisor |
| `Trebejo.File.IO` | Disk-usage reporting |
| `Trebejo.SafeCommand` | Validated wrapper around `Arrea.Command.execute/2` — single entry point for all shell execution |
| `Trebejo.Util` | `run_cmd/3`, `run_cmd_legacy/3`, `run_ok/3` — all routed through `SafeCommand.execute/3` |

> Shell-based functions go through `Arrea.Command` via `Trebejo.SafeCommand` for consistent validation and POSIX-quoted arguments. Pure detection (OS type, hostname, distro) lives in `Apero.OS` — call it directly.

## Installation

Add `trebejo` to your `mix.exs`:

```elixir
def deps do
  [
    {:trebejo, "~> 1.0.0"}
  ]
end
```

## Documentation

Full docs at [https://hexdocs.pm/trebejo](https://hexdocs.pm/trebejo).

Generated with [ExDoc](https://github.com/elixir-lang/ex_doc).
