# Trebejo v2.4.0 — Plan de Ejecución

> **Última actualización**: 2026-07-21
> **Auditoría original**: `AUDIT.md` (2026-07-19)
> **Auditoría complementaria**: revisión tras batch de calidad (2026-07-21)
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