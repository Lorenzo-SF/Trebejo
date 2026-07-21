# Trebejo — Code Quality Audit

> **Generated**: 2026-07-18 | **Stack**: Elixir 1.19 / OTP 28  
> **Scope**: Full codebase audit — security, correctness, typespecs, coverage, OTP compliance

---

## Summary

| Metric | Value |
|--------|-------|
| **Coverage** | 47.8% |
| **Credo issues** | 0 |
| **Dialyzer** | not run |
| **Test count** | 162 pass, 0 fail |
| **P0 findings** | 3 |
| **P1 findings** | 4 |
| **P2 findings** | 6 |

---

## 🔴 P0 — Critical

### 1. SafeCommand bypassed by all consumer modules

**File**: All modules (`docker.ex`, `git/local.ex`, `compress.ex`, `proc.ex`)  
**Lines**: Every `Util.run_cmd_legacy` call

**Problem**: `safe_command.ex` declares itself *"the single entry point for all command execution"* (L3–9), but zero consumer modules use it. Every module calls `Util.run_cmd_legacy/3` directly, which hardcodes `validate: false` (`util.ex:34`). The command-name validation regex at `safe_command.ex:25` is dead code.

```
SafeCommand.execute/3  ──→  called only by SafeCommand's own tests
       ↑ (never called by consumers)
Consumer modules ──→  Util.run_cmd_legacy (validate: false)
```

**Impact**: Any future safety hardening of the entry point is invisible to real callers. The Arrea.Command validator is also bypassed.

**Fix**: Route all modules through `SafeCommand.execute/3`, or delete SafeCommand and move its validation into `Util.run_cmd/3`.

---

### 2. `Docker.compose_ps/1` — broken pipe-artifact

**File**: `docker.ex:193`

```elixir
case Util.run_cmd_legacy(runtime_binary(), ["compose", "ps", "|", Keyword.get(opts, :cd, ".")]) do
```

Passes `"|"` as a literal argument to `docker compose ps | <cd_path>`. There is no shell pipe — it's a raw argument. `docker compose ps` accepts no such arguments. **Always fails at runtime.**

**Diagnosis**: Looks like a corrupted migration from a shell string like `"docker compose ps | grep something"`.

**Fix**: Remove `"|"` and the trailing path. If directory context is needed, pass it as `cd:` option.

---

### 3. `Git.Local.clone_repository/2` — inconsistent command construction

**File**: `git/local.ex:405`

```elixir
cmd_line = "git clone --quiet #{shell_quote(url)} #{shell_quote(target_path)}"
case run_system_cmd("git", cmd_line, env: env) do
```

Every other Git function uses `run_git/2` (L760) which builds args as `["git" | Enum.map(git_args, &shell_quote/1)]`. This one constructs a raw string. While `shell_quote` protects individual values, `run_system_cmd` takes `"git"` as binary name, then passes the full `cmd_line` as argv — duplicated binary spec.

---

## 🟠 P1 — High

### 4. Password on argv (side-channel leak)

**Files**: `compress.ex:123` (`-P`), `compress.ex:142` (`-P`), `compress.ex:300` (`-p#{password}`), `compress.ex:315` (`-p#{password}`)

Passwords are literal argv entries to `zip`, `unzip`, and `7z`. While correctly shell-quoted (no injection risk), they are **visible to all users** via `/proc/<pid>/cmdline` on Linux.

**Fix**: Write passwords via stdin (`zip --password-stdin` for zip 3.5+; `7z -p` reads from stdin if no arg given). Or use env vars with restricted procfs.

---

### 5. macOS `logs/2` predicate interpolation

**File**: `proc.ex:90`

```elixir
["show", "--predicate", "process == '#{service}'", "--last", "#{lines}m"]
```

`service` is interpolated into a predicate string. Currently safe because `run_cmd_legacy` → `shell_quote` wraps the entire predicate in single quotes. If a future refactor routes this through `System.cmd` directly, this becomes an injection vector.

**Fix**: Parameterize the predicate or add an explicit guard that `service` matches `\A[\w.\-/]+\z`.

---

### 6. Typespec bugs

| File:Line | Issue |
|-----------|-------|
| `safe_command.ex` | `run_legacy/3` spec says `keyword()` opts but default not specified |
| `compress.ex:398` | `run/3` is `defp` and untyped — central dispatch |
| `proc.ex` | `ps/1` says `{:ok, [map()]}` but error is `{:error, binary()}` — spec too broad |
| `git/local.ex` | `set_user_info/2` returns `:ok` unconditionally but ignores `run_git` errors — semantic spec bug |

---

### 7. Test quality — tautological assertions

**All `docker_test.exs` tests** (21 tests) use the pattern:
```elixir
assert match?({:ok, _}, result) or match?({:error, _}, result)
```
This passes for **any** outcome. Zero behavioral assertions. Same pattern in `git/local_test.exs` (type-shape checks only) and `proc_test.exs` (ok-or-error tautology).

**SafeCommand**: Only 4 tests. No tests for `run_legacy/3`, non-binary inputs, or `shell_quote` edge cases.

---

## 🟡 P2 — Medium

### 8. `Util.shell_quote/1` has zero dedicated tests

**File**: `util.ex:18–21`

Single-quote escaping is the **foundation of all injection safety** in Trebejo. Untested edge cases:
- String containing `'` (e.g. `O'Brien`)
- Empty string `""` → becomes `''''`
- Strings with newlines or backslashes

---

### 9. `setup_ssh_key/1` — path-with-spaces risk

**File**: `git/local.ex:732`

```elixir
safe_ssh_cmd = "ssh -i #{ssh_key}"
```

If `ssh_key` contains spaces (e.g. `~/.ssh/my keys/id_rsa`), the resulting git config `core.sshCommand` value is `ssh -i /home/user/.ssh/my keys/id_rsa` — git interprets `/home/user/.ssh/my` and `keys/id_rsa` as separate args.

**Fix**: Wrap `ssh_key` in quotes when embedding in the command string, or validate at input that path contains no spaces.

---

### 10. `existing_repos/1` — fragile pattern matching

**File**: `git/local.ex:88–101`

Matches both 2- and 3-element tuples because `ensure_clone/2` can return `{:repo_exists, map()}` or `{:repo_error, map(), term()}`. The `{:repo_exists, _, _}` pattern silently discards a third element — which could mask an error.

---

### 11. `compress.ex` — tar flag mixing

**File**: `compress.ex:173, 196`

Bundled flags (`"-czvf"`) and long options (`"--zstd"`) are mixed in the same args list. Works because tar parses them, but fragile. Should use `["-c", "-z", "-v", "-f"]` consistently.

---

### 12. `mix.exs` — Arrea local override

**File**: `mix.exs:42`

```elixir
{:arrea, path: "../arrea", override: true}
```

Tests run against local checkout, not published version. CI breaks if arrea changes incompatibly. Should be called out explicitly.

---

## 🟢 P3 — Low

### 13. Password in 7z format string

**File**: `compress.ex:300`

`-p#{password}` — fine as argv (shell_quoted). Add `@doc` warning about procfs visibility.

### 14. Coverage tool config

**File**: `mix.exs:27` — `ExCoveralls` specified but not required for `mix test --cover`. Minor.

---

## 📊 Coverage Detail

| Module | Coverage | Notes |
|--------|----------|-------|
| `util.ex` | ~90% | `shell_quote` untested |
| `safe_command.ex` | ~80% | Only unit tests, no integration |
| `compress.ex` | ~60% | Most password paths untested |
| `docker.ex` | ~30% | 21 tautological tests |
| `git/local.ex` | ~50% | Tautological type-shape checks |
| `proc.ex` | ~40% | Ok/error tautology |
| **Overall** | **47.8%** | |

---

## 🔧 Top 5 Fixes (Priority Order)

1. **Route all commands through `SafeCommand.execute/3`** (or merge into `Util.run_cmd/3`) — architecture fix
2. **Fix `compose_ps`** — remove pipe artifact, add real test
3. **Fix `clone_repository`** — use `run_git/2` consistently
4. **Write `shell_quote` property tests** — foundation of all injection safety
5. **Replace tautological test assertions** with behavioral assertions that verify actual command outcomes

---

## Cómo usar esta auditoría

### Interpretación

- **P0 (🔴)**: Debe corregirse antes de cualquier release. Riesgo de crash, seguridad, o pérdida de datos.
- **P1 (🟠)**: Debe corregirse en el próximo ciclo. Degradación significativa de calidad o seguridad.
- **P2 (🟡)**: Debe corregirse cuando se toque el módulo afectado. Deuda técnica.
- **P3 (🟢)**: Conveniencia o estilo. Bajo impacto.

### Flujo de trabajo autónomo

Este documento, junto con `ARCHITECTURE.md` (diseño del proyecto) e `INDEX.md` (navegación de docs), contiene toda la información necesaria para abordar las correcciones de forma autónoma:

1. **Lee ARCHITECTURE.md** primero — entiende el diseño, subsistemas y decisiones clave.
2. **Lee INDEX.md** — localiza los archivos y módulos relevantes.
3. **Vuelve a esta auditoría** — prioriza por severidad (P0 → P1 → P2 → P3).
4. **Para cada hallazgo**: el fichero y línea están indicados. El código fuente relevante está en `lib/`.
5. **Ejecuta `mix test --cover`** antes y después para medir el impacto.
6. **Ejecuta `mix credo --all`** para garantizar que no introduces nuevas violaciones.
7. **Si el hallazgo implica cambiar una interfaz pública**, verifica los proyectos consumidores (listados en ARCHITECTURE.md §consumed-by).

### Dependencias entre proyectos

Trebejo depende de **arrea** (ejecución de comandos vía `Arrea.Command`) y **apero** (utilidades base). Se recomienda leer las auditorías en este orden:
1. `../apero/docs/AUDIT.md` — fundación
2. `../arrea/docs/AUDIT.md` — orquestación de comandos
3. Este documento — operaciones shell

Trebejo es consumido por **candil** (detección de OS/arch), **botica** (probes de red), y **delfos** (Docker, Git churn). Si modificas una interfaz pública de trebejo (SafeCommand, Docker, Git), verifica que estos proyectos siguen compilando y pasando sus tests.

### Checklist por severidad

**Al corregir un P0**:
- [ ] Aísla la causa raíz (línea exacta)
- [ ] Escribe un test que reproduzca el fallo **antes** de corregir
- [ ] Aplica la corrección
- [ ] Verifica que el test pasa
- [ ] Ejecuta `mix test --cover` — la cobertura no debe disminuir
- [ ] Ejecuta `mix credo --all` — cero nuevas violaciones
- [ ] Si cambia una interfaz pública, verifica proyectos consumidores

**Al corregir un P1**:
- [ ] Identifica todos los lugares donde se aplica el patrón (grep por el código similar)
- [ ] Testea el cambio (unitario + integración si aplica)
- [ ] Verifica `mix test --cover` no baja
- [ ] Si afecta a consumidores, ejecuta sus tests también

**Al corregir P2/P3**:
- [ ] Corrige cuando toques el módulo por otra razón (boy-scout rule)
- [ ] No merecen un esfuerzo dedicado si no hay un bug reportado
