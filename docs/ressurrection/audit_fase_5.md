# trebejo — ressurrection_fase_5: análisis meticuloso

> **Fecha**: 2026-09-12
> **Rama**: `ressurrection_fase_5`
> **Tamaño**: 40 módulos, ~5K LOC

---

## 1. Dominio

trebejo es la **capa shell-dependent** del ecosistema. Comandos Docker, Git,
SSH, Kubernetes, etc. vía `System.cmd/Port.open`.

**Migración zaguan → trebejo**: zaguan tiene `Zaguan.SafeExec` (shell wrapper con
blacklist). Migrar a `Trebejo.SafeExec` (¿no existe? verificar).

---

## 2. Análisis

### P0-1 — `Trebejo.Stream.port_to_chunks/2` cierra port en idle

**Archivo**: `lib/trebejo/stream.ex:191-203`
**Tipo**: bug lógico severo
**Impacto**: `after 5000` mataba cualquier stream inactivo durante 5s. `tail -f`
con output lento era killed prematurely. **`Keyword.get([], :_unused, 5_000)`
es un smell claro de código escrito con prisa**.
**Fix**: eliminar el `after` (que solo cerraba por timeout). El port se cierra
cuando el caller termina o llama `close/1`.

---

## 3. Auto-review

- ✅ Fix crítico aplicado.
- ✅ Stream ya no mata streams idle.
