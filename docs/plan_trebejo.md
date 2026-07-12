# Plan for `@trebejo` (System Command Wrappers)

> **Goal** – Tighten the `Arrea.Command.execute/2` call path, ensure safety of system commands, and improve test coverage for the wrapper layer.

---

## 1. Preparation

| Step | Action | Outcome |
|------|--------|---------|
| 1.1 | Verify branch integrity | Clean repo |
| 1.2 | Ensure the working tree is clean (commit any in‑progress changes before starting) | Dependencies resolved |
| 1.3 | Confirm overrides in `trebejo/mix.exs` are present |
| 1.5 | Commit any pending changes in this repo before starting modifications |

## 2. Implementation

| Target | Task |
|--------|------|
| **Command Execution** | Update `Trebejo.File.watch/3` to invoke `Arrea.Command.execute/2` with a validation guard (`validate: true`). |
| **Safety Layer** | Introduce a small wrapper `Trebejo.SafeCommand.execute/2` that escapes arguments and rejects unsanitised strings. |
| **Documentation** | Add example usage in `README.md` for the safe wrapper.

## 3. Tests

| Test File | Coverage Goal | Assertions |
|-----------|---------------|------------|
| `test/trebejo/command_test.exs` | 100 % | • Correct parsing of command string
| | | • Validation rejects unsafe inputs

Run `mix test --cover`.

## 4. Documentation

* Update `README.md` to point to the new safe wrapper.
* Add entry in CHANGELOG: ``refined command safety layer``.

## 5. Quality

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict --format=json
mix test --cover
mix dialyzer
```

## 6. Commit & Push

```bash
git add -A
git commit -m "Add safer command execution layer for trebejo"
git push origin fix-tools-domains
```

---

**End of plan for `@trebejo`**