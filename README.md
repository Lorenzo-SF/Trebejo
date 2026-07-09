# Trebejo

Shell-dependent system utilities extracted from [Apero](https://hex.pm/packages/apero).

## Why Trebejo?

Apero was split into two packages:

| Package | Contents |
|---------|----------|
| **apero** (≥ 3.0.0) | Pure stdlib wrappers — Env, Conf, Retry, Crypto, Cache, File trees/paths, OS type/hostname, Proc which/command\_exists? |
| **trebejo** | Shell-dependent operations — Docker, Git, SSH, K8s, Compress, Network, OS info (arch, distro, kernel, cpu, memory), Proc listing/signalling, File watch |

## Modules

| Module | Description |
|--------|-------------|
| `Trebejo.Docker` | Docker container management |
| `Trebejo.Git` | Git repository operations |
| `Trebejo.SSH` | SSH connections and remote commands |
| `Trebejo.K8s` | Kubernetes resource management |
| `Trebejo.Compress` | Archive creation and extraction |
| `Trebejo.Network` | Network interface and connectivity |
| `Trebejo.OS` | OS metadata: arch, distro, kernel, CPU, memory, info, root, WSL/container detection |
| `Trebejo.Proc` | Process listing, signalling, lsof, fuser, log access |
| `Trebejo.File` | File system watching |
| `Trebejo.File.IO` | Disk usage reporting |

> Pure functions are delegated to `Apero.*` — this package depends on apero.

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

