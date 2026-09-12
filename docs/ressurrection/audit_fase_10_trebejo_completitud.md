# trebejo — audit completitud (iter-040)

> **Fecha**: 2026-09-12
> **Tamaño**: 5,043 LOC, ~40 módulos
> **Tests**: 22 archivos
> **Meta**: trebejo 100% terminado

---

## Estado actual

| Área | LOC | Estado |
|------|-----|--------|
| `trebejo.ex` (facade) | ~100 | ✅ |
| `git/local.ex` | 679 | ✅ |
| `git/local/history.ex` | 226 | ✅ |
| `git/local/branches.ex` | 166 | ✅ |
| `git/local/clone.ex` | ~150 | ✅ |
| `git/credentials.ex` | ~100 | ✅ |
| `docker.ex` | 283 | ✅ |
| `stream.ex` | 257 | ✅ (iter-028 fix) |
| `github.ex` | 217 | ✅ |
| `proc.ex` | 222 | ✅ |
| `os.ex` | 184 | ✅ |
| `postgres.ex` | 171 | ✅ |
| `kubernetes.ex` | ~150 | ✅ |
| `redis.ex` | ~150 | ✅ |
| `network.ex` | ~150 | ✅ |
| `packages.ex` | ~150 | ✅ |
| `compress.ex` + 7 formatos | ~700 | ✅ |
| `image.ex` | ~150 | ✅ |
| `ssh.ex` | ~150 | ✅ |
| `git/credentials.ex` | ~100 | ✅ |
| `safe_command.ex` | ~80 | ✅ |
| `file/` | ~250 | ✅ |
| `mox.ex` | ~50 | ✅ |
| `breaker.ex` | ~80 | ✅ |
| `error.ex` | ~50 | ✅ |

22 tests files, sin TODOs.

## Gap identificado (iter-040)

### P1 — `Trebejo.Git.Local.History.commits_between/3` no existe
**Archivo**: `lib/trebejo/git/local/history.ex`
**Tipo**: feature gap
**Impacto**: los consumidores (delfos, zaguan) tienen que usar `log/2` + parse
manualmente para commits entre dos SHAs.  Una API `commits_between(from, to)`
sería útil.

### Plan iter-040

1. P1: `commits_between/3` con `from_sha`, `to_sha`, opts.
2. Tests: 3-4 nuevos.
3. Doc.
