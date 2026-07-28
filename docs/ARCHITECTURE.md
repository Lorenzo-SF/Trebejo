# Trebejo — Architectural Reference

> System command wrappers for Elixir — shell-based operations
> All execution goes through Arrea. All core utilities come from Apero.

---

## 1. What is Trebejo

Trebejo is the **shell operations** library of the Lorenzo-SF ecosystem.
It wraps every system command that the ecosystem needs: Docker/Podman,
Git, package managers, compression, SSH, Kubernetes, process inspection,
file watching, OS info, image rendering, and network probes.

**Key rule**: Trebejo executes shell commands. If an operation can be done
without the shell, it belongs in Apero. Trebejo is the complement to Apero.

**Critical path**: All shell execution goes through `Arrea.Command.execute/2`.
No direct `System.cmd` calls.

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    Trebejo (doc-only hub)                     │
│  lib/trebejo.ex — module index, no functions                 │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │  Docker  │  │   Git    │  │   SSH    │  │Kubernetes  │  │
│  │          │  │          │  │          │  │            │  │
│  │ runtime  │  │ clone    │  │ exec/3   │  │ available  │  │
│  │ compose  │  │ commit   │  │ scp/4    │  │ pods       │  │
│  │ ps/exec  │  │ churn    │  │          │  │ apply      │  │
│  │ volumes  │  │ merge    │  │          │  │            │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │Compress  │  │ Packages │  │   Proc   │  │   Network  │  │
│  │          │  │          │  │          │  │            │  │
│  │ zip/tar  │  │ apt/brew │  │ ps/kill  │  │ ping/port  │  │
│  │ gzip/zst │  │ pacman.. │  │ lsof     │  │ scan_ports │  │
│  │ 7z/rar   │  │ install  │  │ logs     │  │            │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │    OS    │  │  Image   │  │   File   │  │  Util      │  │
│  │          │  │          │  │          │  │            │  │
│  │ arch     │  │ sixel    │  │ watch/3  │  │ shell_q    │  │
│  │ meminfo  │  │ ascii    │  │ disk_use │  │ run_cmd    │  │
│  │ cpu      │  │ png_conv │  │          │  │ safe_exec  │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │              SafeCommand Layer                        │    │
│  │                                                      │    │
│  │  execute/3  — structured result                      │    │
│  │  run_legacy/3 — tuple result (back-compat)           │    │
│  │  Validates command names (safe charset regex)        │    │
│  │  Shell-quotes all args (POSIX single-quote)         │    │
│  │  All calls go through Arrea.Command.execute/2        │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Subsystems

### 3.1 Docker (Trebejo.Docker)
- Auto-detects runtime: docker vs podman
- Image: pull, build, tag, push, inspect, prune
- Container: run, start, stop, rm, exec, state, ps, logs, top, stats, inspect
- Compose: up, down, restart, pull, build, ps, logs, exec
- Volume: create, inspect, ls, rm, prune
- Network: create, inspect, ls, rm, connect, disconnect
- System: df, info, version, prune

### 3.2 Git (Trebejo.Git.Local)
- Clone, commit, pull, push, fetch
- Branch: create, delete, merge, list, checkout, stash
- History: log, blame, diff, show, churn metrics
- Config: user info, credential setup
- Merge conflict: conflict_files, merge_abort, mark_resolved
- Utility: ensure_clone, sync, remote info, tag

### 3.3 SSH (Trebejo.SSH)
- `exec/3`: Remote command execution over SSH
- `scp/4`: File copy via SCP
- Supports identity key, port, user config

### 3.4 Kubernetes (Trebejo.Kubernetes)
- `available?/0`: kubectl in PATH
- `pods/2`: List pods with namespace
- `apply/2`: Apply manifests
- `delete/4`: Delete resources

### 3.5 Compress (Trebejo.Compress)
- Formats: zip, tar (gzip/bzip2/xz/zstd), gzip, gunzip, zstd, xz, bzip2, 7z, rar
- Auto-detects format from extension
- Password support for zip/7z
- Operations: extract, create (zip, tar, compress), list contents

### 3.6 Packages (Trebejo.Packages)
- 12 managers: apt, brew, pacman, dnf, yum, zypper, apk, pkg, winget, choco, port, nix
- Auto-detects preferred manager via `Apero.Packages`
- `install/1,3`, `installed?/1,2`

### 3.7 Process (Trebejo.Proc)
- `ps/1`: Cross-platform process listing
- `kill/2`: Signal processes
- `lsof/1`: Open files for a PID
- `fuser/1`: Processes using a file
- `logs/2`: journalctl / macOS log

### 3.8 Network (Trebejo.Network)
- `ping/2`: ICMP ping via system ping
- `port_open?/3`: TCP port check via `:gen_tcp`
- `scan_ports/3`: Port scanning

### 3.9 OS (Trebejo.OS)
- Shell-based system info:
  - `arch/0`: architecture (uname -m)
  - `kernel_version/0`: kernel version
  - `cpu_count/0`: processor count (nproc / sysctl)
  - `total_memory_mb/0`: RAM (sysctl / meminfo)
  - `root?/0`: running as root
  - `info/0`: consolidated info map

### 3.10 Image (Trebejo.Image)
- `render_sixel/3`: Sixel graphics via img2sixel
- `image_to_ascii/2`: ASCII art via img2txt
- `convert_to_png/3`: PNG conversion via ImageMagick
- Returns `:tool_not_found` if CLI missing

### 3.11 File (Trebejo.File)
- `watch/3`: Directory monitoring via `Apero.File.Watcher` + `Arrea.WorkerSupervisor`
- `Trebejo.File.IO.disk_usage/1`: Shell-based disk usage (df)

### 3.12 SafeCommand (Trebejo.SafeCommand)
- `execute/3`: Validates command name (safe charset regex), shell-quotes all args,
  calls `Arrea.Command.execute/2`, returns structured result
- `run_legacy/3`: Same validation, returns `{output, exit_code}` tuple for back-compat

### 3.13 Util (Trebejo.Util)
- `shell_quote/1`: POSIX single-quote escaping
- `run_cmd/3`: Arrea integration, returns `{:ok, out, code}`
- `run_cmd_legacy/3`: Returns `{out, code}` tuple
- `run_ok/3`: Returns `:ok` or error

---

## 4. Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| **Apero** | path: ../apero | OS detection, Proc, File, Packages |
| **Arrea** | path: ../arrea | Command execution (`Arrea.Command.execute/2`), WorkerSupervisor (file watching) |

Trebejo's only Lorenzo-SF dependencies are **Apero** (pure utilities) and
**Arrea** (command execution). All shell operations flow through Arrea.

---

## 5. Consumed by

| Project | What it uses |
|---------|--------------|
| **Candil** | `Trebejo.OS.arch/0` for llama.cpp GPU detection |
| **Botica** | `Trebejo.Network` for port probes, `Trebejo.Util` for command runner |
| **Delfos** | `Trebejo.Docker` for PG container management, `Trebejo.Git.Local.churn/2` for git churn analysis, `Trebejo.SafeCommand`, `Trebejo.Util` |
| **Alaja** | (optional) `Trebejo.Image` for Sixel/ASCII image rendering |

---

## 6. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **No direct System.cmd** | All execution through `Arrea.Command.execute/2` — consistent validation, timeout, telemetry, and error handling. |
| **Separation from Apero** | Apero = pure Elixir/Erlang, Trebejo = shell. Clear boundary: if it needs `System.cmd`, it's Trebejo's problem. |
| **SafeCommand as sole entry point** | Single gate for all shell execution. Command name validation (safe charset regex) + POSIX arg quoting prevents injection. |
| **Auto-detection (docker/podman, package managers)** | No configuration needed. Trebejo probes PATH and adapts. |
| **`:tool_not_found` return** | Graceful degradation when CLI tools are missing. No crashes. |
| **Arrea.LongRunning for file watching** | Debounced batch events, supervised process, no polling. |

---

## 7. Execution Stack

```
User code
  → Trebejo.SafeCommand.execute/3
    → validates command name
    → shell-quotes args
    → Trebejo.Util.run_cmd/3 → Arrea.Command.execute/2
      → Arrea.CircuitBreaker (optional)
      → Port.open (with timeout)
      → Telemetry events
      → Structured result
```

---

## 8. Current State

- 17 source modules, 14 test files
- Covers: Docker, Git, SSH, K8s, compress, packages, proc, network, OS, image, file
- Pending: `file_test.exs`, `image_test.exs`, `packages_test.exs`
- Critical path: all execution via Arrea, all validation via SafeCommand
