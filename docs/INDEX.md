# Trebejo — Document Index

> Shell command wrappers for Elixir

| Document | Description |
|----------|-------------|
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Complete design reference: subsystems (Docker, Git, SSH, K8s, Compress, Packages, Proc, Network, OS, Image, File, SafeCommand, Util), dependencies, execution stack |
| [`AUDIT.md`](./AUDIT.md) | Code quality audit: SafeCommand bypassed, broken compose_ps, passwords on argv, tautological tests, 47.8% coverage, top 5 fixes |
| [`README.md`](../README.md) | English README — installation, usage, module overview |
| [`docs/README.es.md`](./README.es.md) | Spanish README |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history and release notes |
| [`LICENSE.md`](../LICENSE.md) | MIT License |
| [`plan_trebejo.md`](./plan_trebejo.md) | Historical implementation plan (safe command layer) |

### Ecosystem context

Trebejo is the **shell operations layer** of the Lorenzo-SF ecosystem.
It depends on Apero (core utilities) and Arrea (command execution).
It is consumed by Candil (OS arch detection), Botica (network probes),
and Delfos (Docker, Git churn). See the
[dependency graph](../docs/ARCHITECTURE.md#5-consumed-by).
