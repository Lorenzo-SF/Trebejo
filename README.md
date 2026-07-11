# Trebejo

Shell-dependent system utilities extracted from [Apero](https://hex.pm/packages/apero).

## Why Trebejo?

Apero was split into two packages:

| Package | Contents |
|---------|----------|
| **apero** (≥ 3.0.0) | Pure stdlib wrappers — Env, Conf, Retry, Crypto, Cache, File trees/paths, OS type/hostname/distro/container/WSL, Proc which/command\_exists? |
| **trebejo** | Shell-dependent operations — Docker, Git, SSH, K8s, Compress, Network, OS info (arch, kernel, cpu, memory, root), Proc listing/signalling, File watch |

## Modules

| Module | Description |
|--------|-------------|
| `Trebejo.Docker` | Docker container management |
| `Trebejo.Git` | Git repository operations |
| `Trebejo.SSH` | SSH connections and remote commands |
| `Trebejo.K8s` | Kubernetes resource management |
| `Trebejo.Compress` | Archive creation and extraction |
| `Trebejo.Network` | Network interface and connectivity |
| `Trebejo.OS` | OS metadata: arch, kernel, CPU, memory, root — shell-based. Pure OS detection (type, hostname, distro, WSL, container) via `Apero.OS` |
| `Trebejo.Proc` | Process listing, signalling, lsof, fuser, log access |
| `Trebejo.Packages` | Package installation and detection |
| `Trebejo.File` | File system watching |
| `Trebejo.File.IO` | Disk usage reporting |

> Shell-based functions use `Arrea.Command` for execution. Pure detection (OS type, hostname, distro) lives in `Apero.OS` — call it directly.

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

