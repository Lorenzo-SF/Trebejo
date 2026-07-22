# Trebejo v2.4.0 — Plan de Ejecución

> **Última actualización**: 2026-07-22
> **Auditoría original**: `AUDIT.md` (2026-07-19)
> **Auditoría complementaria**: revisión tras batch de calidad (2026-07-21)
> **Auditoría complementaria v2**: revisión + agrupación por impacto (2026-07-22)
> **Estado**: 5/5 comandos pasan. Pendientes: refactors gordos + tests.

---

## 0. Estado actual (verificado 2026-07-21)

| Check | Resultado |
|-------|-----------|
| `mix format --check-formatted` | ✅ 0 cambios |
| `mix compile --warnings-as-errors` | ✅ 0 warnings |
| `mix credo --strict --format=json` | ✅ 0 issues |
| `mix test --cover` | ✅ 178 tests, 0 fail, coverage **47.5%** |
| `mix dialyzer` | ✅ 0 errors |

CHANGELOG `[Unreleased]` actualizado. Git history normalizado. README.es.md creado.

---

## 1. Resumen

| Severidad | Total | Realizadas | Pendientes |
|-----------|-------|------------|------------|
| 🔴 P0 | 1 | 1 | 0 |
| 🟠 P1 | 2 | 2 | 0 |
| 🟡 P2 | 7 | 5 | 2 |
| 🟢 P3 | 5 | 1 | 4 |
| **Refactors estructurales** | — | — | 2 |
| **Total tareas** | **15 + 2** | **9** | **8** |

**Esfuerzo restante estimado**: ~16h (incluye refactors gordos).

### Vista por impacto (ver §11 para detalle)

| Impacto | # tareas | Descripción |
|---------|----------|-------------|
| 🟢 LOCAL | 15 | Solo afecta a trebejo internamente |
| 🟡 MEDIO | 6 | Afecta a 1-2 consumers (candil, botica, delfos, alaja) |
| 🔴 CRÍTICO | 1 | `Git.Local.split` (TRE-15) — afecta a delfos |

**Conclusión**: trebejo es shell-wrappers layer. Solo el split de `Git.Local` (TRE-15) tiene blast radius ≥3 (delfos usa `git churn`, `clone`, etc.). El resto son fixes internos sin tocar API pública, salvo TRE-22 (password security) que sí cambia comportamiento observable.

---

## 2. Tareas realizadas en este batch

### ✅ TRE-01: Fix `parse_tasklist/1` crash en Windows
- **Commit**: `30eeb3c` ("fix(trebejo): harden Proc parsing and reduce nesting depth")
- **Qué se hizo**:
  - `lib/trebejo/proc.ex:163` `parse_tasklist/1` ya no crashea con MatchError
  - Reemplazado destructure con safe parsing usando `String.split/2` + per-row helper `parse_tasklist_row/1`
  - Filas malformadas se loggean con `Logger.warning` y se saltan

### ✅ TRE-02: Eliminar silent drops en parsing
- **Commit**: `30eeb3c`
- **Qué se hizo**:
  - `lib/trebejo/proc.ex:135` `parse_ps_output/1` ya no traga líneas malformadas en silencio
  - Ahora emite `Logger.warning` con la línea problemática
  - `parse_tasklist/1` idem

### ✅ TRE-03: Reducir nesting depth en `logs/2`
- **Commit**: `30eeb3c`
- **Qué se hizo**:
  - `lib/trebejo/proc.ex:91` `logs/2` extraída en helpers `logs_linux/2` y `logs_macos/2`
  - Body depth 3 → 2 (cumple credo)

### ✅ TRE-04: Corregir `@spec` de `Packages.installed?/2`
- **Commit**: `ebda228` ("fix(trebejo): correct @spec for Packages.installed?/2")
- **Qué se hizo**:
  - `@spec installed?(manager, package) :: boolean | {:error, String.t()}` → `@spec installed?(manager, package) :: boolean()`
  - Todas las cláusulas retornan boolean, no `{:error, _}`

### ✅ TRE-05: Eliminar dead `SafeCommand.run_legacy/3`
- **Commit**: `026c882` ("chore(trebejo): remove dead run_legacy/3 from SafeCommand")
- **Qué se hizo**:
  - `lib/trebejo/safe_command.ex:73` `SafeCommand.run_legacy/3` eliminado
  - Solo estaba referenciado en su propio docstring

### ✅ TRE-06: Eliminar `# credo:disable-for-this-file CyclomaticComplexity`
- **Commit**: `30eeb3c`
- **Qué se hizo**:
  - `lib/trebejo/proc.ex:2` directiva deshabilitada eliminada
  - Ya no es necesaria tras el refactor de `logs/2`

### ✅ TRE-09: `mix format` pass
- **Commit**: `90a7518` ("chore(trebejo): mix format")
- **Qué se hizo**: 2 líneas reformateadas en `lib/trebejo/git/local.ex`

### ✅ README + CHANGELOG
- **Commit**: `83cb9d6` + `9d95b5a`
- **Qué se hizo**:
  - `README.md`: tabla de módulos corregida (`Trebejo.K8s` → `Trebejo.Kubernetes`), módulos añadidos (`Trebejo.Git.Local`, `Trebejo.Image`, `Trebejo.SafeCommand`, `Trebejo.Util`), footer sobre SafeCommand actualizado
  - `README.es.md` creado (mirror en español)
  - `CHANGELOG [Unreleased]`: 4 fixed + 1 removed

---

## 3. Tareas pendientes

### TRE-07: Add property tests for compress module
- **Hallazgo**: P2 — compress sin property tests
- **Severidad**: 🟡 P2
- **Estado**: pendiente

### TRE-08: Reduce nesting en `compress.ex`
- **Hallazgo**: P2 — `compress/3` tiene nested case
- **Severidad**: 🟡 P2
- **Estado**: pendiente
- **Ficheros**: `lib/trebejo/compress.ex`

### TRE-10: Tests for `safe_command.ex` `shell_quote/1`
- **Hallazgo**: P3 — falta cobertura de casos edge
- **Severidad**: 🟢 P3
- **Estado**: pendiente

### TRE-11: Verify `git/local.ex` split worth it
- **Hallazgo**: P3 — 825 líneas
- **Severidad**: 🟢 P3
- **Estado**: pendiente
- **Nota**: ver también TRE-15 (refactor estructural)

### TRE-12: Fix typos en README y comments
- **Hallazgo**: P3 — typos
- **Severidad**: 🟢 P3
- **Estado**: pendiente

### TRE-13: Translate Spanish comments to English
- **Hallazgo**: P3 — comentarios en español
- **Severidad**: 🟢 P3
- **Estado**: pendiente

### TRE-14: Add @doc to `Trebejo.Image`
- **Hallazgo**: P3 — sin @doc
- **Severidad**: 🟢 P3
- **Estado**: pendiente

---

## 4. Refactors estructurales

### TRE-15: Split `lib/trebejo/git/local.ex` (825 líneas)
- **Hallazgo**: **god-module de 825 líneas, 60 funciones**
- **Severidad**: 🔴 Estructural
- **Ficheros**:
  - `lib/trebejo/git/local.ex` (825 líneas)
  - `lib/trebejo/git/` (nuevo)
- **Esfuerzo estimado**: 10-12h
- **Análisis estructural actual**:
  - Funciones de clone: `clone/2`, `clone_into/3`, `clone_with_branch/3`, `clone_shallow/3`
  - Funciones de commit/sync: `commit/3`, `push/2`, `pull/2`, `fetch/2`
  - Funciones de branches: `branch/2`, `checkout/2`, `merge/2`, `rebase/2`
  - Funciones de credentials: `set_credentials/2`, `get_credentials/0`
  - Funciones de churn: `churn/1`, `churn_by_author/1`, `top_files/2`
  - Helpers gh/glab: `gh_pr/2`, `glab_mr/2`
- **Plan de split**:
  - `lib/trebejo/git/local.ex` (~150 líneas): fachada
  - `lib/trebejo/git/clone.ex` (~200 líneas): clone + clone_into + clone_with_branch + clone_shallow
  - `lib/trebejo/git/sync.ex` (~150 líneas): commit + push + pull + fetch
  - `lib/trebejo/git/branches.ex` (~150 líneas): branch + checkout + merge + rebase
  - `lib/trebejo/git/credentials.ex` (~80 líneas): credentials
  - `lib/trebejo/git/churn.ex` (~120 líneas): churn + top_files + analysis
  - `lib/trebejo/git/platform.ex` (~100 líneas): gh/glab wrappers (PR/MR API)
- **Pasos detallados**:
  1. **Fase 1**: Extraer `clone.ex`
  2. **Fase 2**: Extraer `sync.ex`
  3. **Fase 3**: Extraer `branches.ex`
  4. **Fase 4**: Extraer `credentials.ex` + `platform.ex`
  5. **Fase 5**: Extraer `churn.ex`
  6. **Fase 6**: Local como fachada
- **Verificación**:
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
  - `mix credo --strict`
  - `mix test --cover` (mantener coverage)
- **Riesgos**: MEDIO. Git es crítico pero local. Tests deben cubrir todos los sub-módulos.

---

### TRE-16: Split `lib/trebejo/compress.ex` (428 líneas, 13 wrappers)
- **Hallazgo**: **428 líneas con 13 wrappers** de herramientas de compresión (zstd, xz, bzip2, gzip, 7z, rar, zip, tar, etc.)
- **Severidad**: 🟡 Estructural
- **Ficheros**:
  - `lib/trebejo/compress.ex` (428 líneas)
  - `lib/trebejo/compress/` (nuevo)
- **Esfuerzo estimado**: 4-6h
- **Análisis estructural actual**:
  - 13 wrappers: `zstd/2`, `xz/2`, `bzip2/2`, `gzip/2`, `sevenzip/2`, `rar/2`, `zip/2`, `tar/2`, etc.
  - Cada wrapper tiene `compress/2`, `decompress/2`, `list/1`, `extract/2` aprox
- **Plan de split**:
  - `lib/trebejo/compress.ex` (~100 líneas): fachada + dispatcher
  - `lib/trebejo/compress/zstd.ex` (~70 líneas)
  - `lib/trebejo/compress/xz.ex` (~50 líneas)
  - `lib/trebejo/compress/bzip2.ex` (~50 líneas)
  - `lib/trebejo/compress/gzip.ex` (~50 líneas)
  - `lib/trebejo/compress/sevenzip.ex` (~70 líneas)
  - `lib/trebejo/compress/rar.ex` (~50 líneas)
  - `lib/trebejo/compress/zip.ex` (~50 líneas)
  - `lib/trebejo/compress/tar.ex` (~80 líneas)
- **Pasos**:
  1. Por cada wrapper, extraer a módulo separado con sus 4 funciones (compress/decompress/list/extract)
  2. Crear `Behaviour` para definir interfaz común
  3. `compress.ex` despacha según `format` atom
- **Verificación**: `mix test --cover` + `mix credo --strict`
- **Riesgos**: BAJO. Wrappers son aislados. Backwards compat con `Compress.zstd/2` etc.

---

## 5. Coverage gaps (subir de 47.5% → 70%+)

### TRE-17: Tests para `git/local.ex`
- **Hallazgo**: 825 líneas pero coverage desconocido
- **Severidad**: 🟡 Mantenibilidad
- **Ficheros**: `test/trebejo/git/local_test.exs` (verificar si existe)
- **Esfuerzo**: 3-4h
- **Plan**:
  - Tests por cada función pública (60 funciones)
  - Mockear shell calls con Mimic
  - Property tests para parsing

### TRE-18: Tests para `compress.ex` (13 wrappers)
- **Ficheros**: `test/trebejo/compress_test.exs`
- **Esfuerzo**: 2h
- **Plan**: 1 test por wrapper (happy path), cubrir con mocks

---

## 6. Dependencias externas

| Tarea | Dependencia |
|-------|-------------|
| TRE-15 | delfos (consume `Trebejo.Git.Local`?) |
| TRE-16 | ninguna |

Trebejo no depende de otros proyectos lorenzo-sf en runtime.

---

## 7. Riesgos globales

1. **TRE-15 git/local split**: módulo grande pero testing es relativamente fácil con mocks. Branch dedicada.
2. **TRE-16 compress split**: 13 nuevos módulos. Backwards compat crítica.
3. **Coverage baja (47.5%)**: muchos módulos sin tests. Tests son trabajo continuo.

---

## 8. Comandos de verificación

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict --format=json
mix test --cover                    # objetivo: ≥70%
mix dialyzer
```

---

## 9. CHANGELOG bullets para próximos lotes

Bajo `[Unreleased]`:

### Changed
- `Trebejo.Git.Local` split into Clone/Sync/Branches/Credentials/Churn/Platform (TRE-15)
- `Trebejo.Compress` split into per-format modules (TRE-16)

### Added
- Property tests for `Compress` (TRE-07)
- Tests for `Git.Local` (TRE-17)
- Tests for `Compress` wrappers (TRE-18)

### Fixed
- Tareas TRE-XX según se completen

NO bumpear versión.

---

## 10. AUDIT v2 — Hallazgos adicionales no abordados (2026-07-22)

> Tareas del `AUDIT.md` original que **no tienen contraparte** en las secciones §3-§5 (TRE-01..TRE-18).

### TRE-19: SafeCommand bypassed by all consumer modules
- **Hallazgo** (`AUDIT.md` §P0 #1):
  > `safe_command.ex` declara ser "the single entry point for all command execution" pero cero consumer modules lo usan. Cada módulo llama `Util.run_cmd_legacy/3` con `validate: false`. El regex de validación de `safe_command.ex:25` es dead code.
- **Severidad**: 🔴 P0 (architecture fix)
- **Ficheros**: `lib/trebejo/util.ex`, `lib/trebejo/safe_command.ex`, todos los consumers (`docker.ex`, `git/local.ex`, `compress.ex`, `proc.ex`, etc.)
- **Esfuerzo**: 4-6h
- **Pasos**:
  1. Decidir enfoque: (a) routear todos los módulos via `SafeCommand.execute/3`, o (b) eliminar `SafeCommand` y mover validación a `Util.run_cmd/3`
  2. Opción recomendada: (a) — `SafeCommand` ya existe, solo hay que conectarlo
  3. Reemplazar todas las llamadas a `Util.run_cmd_legacy` por `SafeCommand.execute/3`
  4. Tests de integración que verifiquen que `SafeCommand.execute/3` rechaza comandos maliciosos
- **Verificación**: `mix test` + `mix credo --all`
- **Impacto**: 🟢 LOCAL (cambio interno, mejora arquitectura)
- **Riesgos**: Medio. Cambio de path de ejecución puede afectar tests existentes.

### TRE-20: Fix `Docker.compose_ps/1` broken pipe-artifact
- **Hallazgo** (`AUDIT.md` §P0 #2): `docker.ex:193` pasa `"|"` como literal argument — siempre falla en runtime.
- **Severidad**: 🔴 P0 (runtime bug)
- **Ficheros**: `lib/trebejo/docker.ex`
- **Esfuerzo**: 30 min
- **Pasos**:
  1. Eliminar `"|"` y el path trailing en `docker.ex:193`
  2. Si se necesita context de directorio, pasarlo via `cd:` option
  3. Test que verifique que `compose_ps` ejecuta correctamente
- **Verificación**: `mix test test/trebejo/docker_test.exs`
- **Impacto**: 🟡 MEDIO (afecta a delfos que usa Docker)
- **Riesgos**: Bajo. Fix claro.

### TRE-21: Fix `Git.Local.clone_repository/2` inconsistent command construction
- **Hallazgo** (`AUDIT.md` §P0 #3): `git/local.ex:405` usa `run_system_cmd` con string raw; otros usan `run_git/2`. Inconsistencia arquitectural.
- **Severidad**: 🔴 P0 (architecture consistency)
- **Ficheros**: `lib/trebejo/git/local.ex`
- **Esfuerzo**: 1h
- **Pasos**:
  1. Refactor `clone_repository/2` para usar `run_git/2` consistentemente
  2. Eliminar `cmd_line` string raw
  3. Test que verifique que clone funciona con URLs con caracteres especiales
- **Verificación**: `mix test test/trebejo/git/local_test.exs`
- **Impacto**: 🟡 MEDIO (afecta a delfos que usa git clone)
- **Riesgos**: Bajo.

### TRE-22: Password on argv (side-channel leak)
- **Hallazgo** (`AUDIT.md` §P1 #4): passwords en `compress.ex:123, 142, 300, 315` son visibles via `/proc/<pid>/cmdline` en Linux.
- **Severidad**: 🟠 P1 (security)
- **Ficheros**: `lib/trebejo/compress.ex`
- **Esfuerzo**: 3-4h
- **Pasos**:
  1. Investigar soporte de `--password-stdin` en zip 3.5+
  2. Investigar `7z -p` con stdin
  3. Refactor `Compress.zip/2`, `unzip/2`, `sevenzip/2` para escribir password via stdin
  4. Tests con mock de stdin
- **Verificación**: `mix test test/trebejo/compress_test.exs`
- **Impacto**: 🟡 MEDIO (afecta a delfos, botica que usan compress)
- **Riesgos**: Medio. Cambio de API interna; verificar que zip/7z soportan stdin en versiones target.

### TRE-23: macOS `logs/2` predicate interpolation guard
- **Hallazgo** (`AUDIT.md` §P1 #5): `proc.ex:90` interpola `service` en predicate string — actualmente seguro por shell_quote pero frágil.
- **Severidad**: 🟠 P1 (security hardening)
- **Ficheros**: `lib/trebejo/proc.ex`
- **Esfuerzo**: 30 min
- **Pasos**:
  1. Añadir guard regex `\A[\w.\-/]+\z` en `logs/2` para `service`
  2. Si no coincide, retornar `{:error, :invalid_service_name}`
  3. Test con servicio válido + servicio inválido
- **Verificación**: `mix test test/trebejo/proc_test.exs`
- **Impacto**: 🟢 LOCAL (defensiva, no cambia API)

### TRE-24: Typespec fixes (P1 #6)
- **Hallazgo** (`AUDIT.md` §P1 #6): 4 typespec bugs en `safe_command.ex`, `compress.ex:398`, `proc.ex`, `git/local.ex`.
- **Severidad**: 🟠 P1
- **Ficheros**: 4 archivos
- **Esfuerzo**: 1h
- **Pasos**:
  1. `safe_command.ex`: añadir `default` a `run_legacy/3` opts spec
  2. `compress.ex:398`: tipar `run/3` o hacerlo `def` público con spec
  3. `proc.ex`: corregir spec de `ps/1` a `{:ok, [map()]} | {:error, binary()}`
  4. `git/local.ex`: corregir spec de `set_user_info/2` para que retorne `{:ok, _}` o `{:error, _}`
- **Verificación**: `mix dialyzer` (0 warnings)
- **Impacto**: 🟢 LOCAL

### TRE-25: Replace tautological test assertions
- **Hallazgo** (`AUDIT.md` §P1 #7): 21 tests en `docker_test.exs` + tests en `git/local_test.exs` y `proc_test.exs` usan `match?({:ok, _}, _) or match?({:error, _}, _)` — pasan para cualquier outcome.
- **Severidad**: 🟠 P1 (test quality)
- **Ficheros**: `test/trebejo/docker_test.exs`, `test/trebejo/git/local_test.exs`, `test/trebejo/proc_test.exs`
- **Esfuerzo**: 3-4h
- **Pasos**:
  1. Auditar cada test que usa el patrón tautológico
  2. Reemplazar con aserciones que validen contenido: `assert {:ok, output} = result; assert output =~ "expected_substring"`
  3. Mockear shell calls con Mimic o Mecc
  4. Para tests que dependen de binarios externos (docker, git), marcar con `@tag :integration` y excluirlos del CI
- **Verificación**: `mix test --cover` (cobertura debe mantenerse o subir)
- **Impacto**: 🟢 LOCAL

### TRE-26: Property tests para `Util.shell_quote/1`
- **Hallazgo** (`AUDIT.md` §P2 #8): `shell_quote/1` es la fundación de toda la seguridad de inyección pero no tiene tests dedicados.
- **Severidad**: 🟡 P2
- **Ficheros**: `test/trebejo/util_test.exs` (nuevo o ampliar)
- **Esfuerzo**: 1h
- **Pasos**:
  1. Tests para edge cases: empty string, strings con `'`, con newlines, con backslashes, con `$`, con `"`
  2. Property test con StreamData: para cualquier string, `shell_quote(s)` la hace safe para shell POSIX
  3. Test: `echo #{shell_quote(s)} | bash` ejecuta `s` literalmente sin inyección
- **Verificación**: `mix test test/trebejo/util_test.exs`
- **Impacto**: 🟢 LOCAL (defensiva)
- **Nota**: TRE-10 cubre `safe_command.ex shell_quote/1` pero el AUDIT señala `util.ex:18-21` — módulos diferentes.

### TRE-27: `setup_ssh_key/1` path-with-spaces risk
- **Hallazgo** (`AUDIT.md` §P2 #9): `git/local.ex:732` concatena `ssh_key` sin quotes — paths con espacios rompen el comando.
- **Severidad**: 🟡 P2 (security)
- **Ficheros**: `lib/trebejo/git/local.ex`
- **Esfuerzo**: 30 min
- **Pasos**:
  1. En `setup_ssh_key/1`, wrappear `ssh_key` en quotes: `"ssh -i '#{ssh_key}'"`
  2. O validar que path no contenga espacios (raise con mensaje claro)
  3. Test con path que contiene espacios
- **Verificación**: `mix test test/trebejo/git/local_test.exs`
- **Impacto**: 🟡 MEDIO (afecta a delfos que configura SSH keys)

### TRE-28: `existing_repos/1` fragile pattern matching
- **Hallazgo** (`AUDIT.md` §P2 #10): `git/local.ex:88-101` matchea tuplas de 2 y 3 elementos silenciosamente.
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/trebejo/git/local.ex`
- **Esfuerzo**: 15 min
- **Pasos**:
  1. Auditar todos los call sites de `ensure_clone/2` para entender qué retorna
  2. Reemplazar pattern matching con uno explícito que diferencie `{:repo_exists, _}` vs `{:repo_error, _, _}`
  3. Logear `{:repo_error, _, reason}` con `Logger.warning`
- **Verificación**: `mix test test/trebejo/git/local_test.exs`
- **Impacto**: 🟢 LOCAL

### TRE-29: `compress.ex` — tar flag mixing
- **Hallazgo** (`AUDIT.md` §P2 #11): `compress.ex:173, 196` mezcla flags bundleados (`"-czvf"`) con long options (`"--zstd"`).
- **Severidad**: 🟡 P2 (polish)
- **Ficheros**: `lib/trebejo/compress.ex`
- **Esfuerzo**: 15 min
- **Pasos**:
  1. Reemplazar `"-czvf"` por `["-c", "-z", "-v", "-f"]` y `"-xzvf"` por `["-x", "-z", "-v", "-f"]`
  2. Tests
- **Verificación**: `mix test test/trebejo/compress_test.exs`
- **Impacto**: 🟢 LOCAL

---

## 11. Agrupación por impacto en el ecosistema (2026-07-22)

> **Pregunta**: si hago esta tarea, ¿tengo que tocar otros proyectos o se hace y ya?

### 🟢 LOCAL — "se hace y ya" (15 tareas)

| ID | Tarea |
|----|-------|
| TRE-07 | Property tests for compress |
| TRE-08 | Reduce nesting en `compress.ex` |
| TRE-11 | Verify `git/local.ex` split worth it |
| TRE-12 | Fix typos en README/comments |
| TRE-13 | Translate Spanish comments to English |
| TRE-14 | Add `@doc` to `Trebejo.Image` |
| TRE-17 | Tests para `git/local.ex` |
| TRE-18 | Tests para `compress.ex` (13 wrappers) |
| TRE-19 | SafeCommand bypassed by all consumers (architecture fix) |
| TRE-23 | macOS `logs/2` predicate interpolation guard |
| TRE-24 | Typespec fixes (4 archivos) |
| TRE-25 | Replace tautological test assertions |
| TRE-26 | Property tests para `Util.shell_quote/1` |
| TRE-28 | `existing_repos/1` fragile pattern matching |
| TRE-29 | `compress.ex` tar flag mixing |

**Workflow**: branch en `trebejo` → tests → commit → push.

---

### 🟡 MEDIO — "verificar 1-2 consumidores" (6 tareas)

| ID | Tarea | Consumidores | Smoke test |
|----|-------|--------------|------------|
| TRE-10 | Tests for `safe_command.ex shell_quote/1` | delfos (via SafeCommand) | `cd ../delfos && mix test` |
| TRE-16 | Split `compress.ex` (428 LoC, 13 wrappers) | botica, delfos (vía Compress) | `cd ../botica && mix test` + `cd ../delfos && mix test` |
| TRE-20 | Fix `Docker.compose_ps/1` broken pipe | delfos (vía Docker) | `cd ../delfos && mix test` |
| TRE-21 | Fix `Git.Local.clone_repository/2` inconsistency | delfos (vía git) | `cd ../delfos && mix test` |
| TRE-22 | Password on argv (side-channel leak) — security | delfos, botica (vía Compress) | `cd ../delfos && mix test` |
| TRE-27 | `setup_ssh_key/1` path-with-spaces risk | delfos (vía git SSH) | `cd ../delfos && mix test` |

**Workflow**: branch en `trebejo` → tests propios → smoke test → merge.

---

### 🔴 CRÍTICO — "branch dedicada + smoke tests en TODOS" (1 tarea)

| ID | Tarea | Consumidores | Blast radius |
|----|-------|--------------|--------------|
| **TRE-15** | Split `git/local.ex` (825 LoC) | delfos (vía `Trebejo.Git.Local.churn/2`, clone, etc.) | Delfos depende de git churn |

**Workflow**:
1. Branch dedicada: `refactor/tre-15-git-split`
2. Tests exhaustivos (la fachada `Local` debe mantener API 100%)
3. Smoke test obligatorio: `cd ../delfos && mix deps.get && mix compile --warnings-as-errors && mix test`

---

### 📊 Matriz resumen

| Impacto | # tareas | Esfuerzo | Branch dedicada | Smoke tests externos |
|---------|----------|----------|-----------------|----------------------|
| 🟢 LOCAL | 15 | ~14h | No | 0 proyectos |
| 🟡 MEDIO | 6 | ~9h | No (en trebejo) | 1-2 proyectos |
| 🔴 CRÍTICO | 1 | ~11h | **Sí** | **1 proyecto (delfos)** |
| **Total** | **22** | **~34h** | — | — |

### 🎯 Orden de ejecución sugerido

1. **Quick wins LOCAL** (1h): TRE-12, TRE-13, TRE-14, TRE-29
2. **Bug fixes LOCAL** (3h): TRE-19 (SafeCommand architecture), TRE-23 (predicate guard), TRE-24 (typespecs), TRE-27 (path-with-spaces — pero está en MEDIO), TRE-28 (pattern matching)
3. **Test quality LOCAL** (4-5h): TRE-25 (replace tautological), TRE-26 (shell_quote property tests), TRE-17, TRE-18
4. **Coverage** (1-2h): TRE-07 (compress properties), TRE-08 (nesting)
5. **MEDIO con smoke tests** (8-9h): TRE-10, TRE-16, TRE-20, TRE-21, TRE-22, TRE-27
6. **CRÍTICO** (10-12h): TRE-15 — split `git/local.ex` con smoke test en delfos