# Command Surface (testplay-runner)

## Connection and targeting

- Run `testplay check` first to validate the environment, Unity path, and project path before touching Unity.
- Expect configuration to be loaded from `testplay.json` in the project root.
- Assume `testplay run` will automatically create and use a shadow workspace (`.testplay-shadow-<run_id>/`) to avoid locking issues when the Unity Editor is open.
- Add `--clear-cache` to force a cold start if the Library cache (`.testplay/cache/Library/`) needs to be invalidated.
- Remember that agents never see shadow paths; all `absolute_path` fields in the JSON output are automatically remapped to source project paths.

## Core commands

### `init`

- Use `testplay init` to generate a `testplay.json` configuration file with sensible defaults for a new project.
- Expect it to fail (Exit 5) if `testplay.json` already exists. Use `--force` to overwrite.

### `check`

- Use `testplay check` to validate the setup before running tests.
- Expect Exit 0 when ready.
- Expect Exit 1 if a dependency is missing, and fix it based on the `hint` field.
- Expect Exit 5 if the configuration is invalid, and fix `testplay.json`.

### `list`

- Use `testplay list` to statically scan `*.cs` files for test attributes without running Unity.
- Use it to quickly find candidate test names.

### `run`

- Use `testplay run` to execute Unity tests using the configured `test_platform` (`edit_mode` or `play_mode`).
- Rely on specific exit codes to determine the next action:
  - Exit 0: All tests passed. Proceed.
  - Exit 2: Compile failure. Fix the source based on `errors[].absolute_path` and `line`.
  - Exit 3: Test failure. Fix the test logic based on `tests[].absolute_path` and `line`.
  - Exit 4: Timeout. Check `timeout_type` ("compile", "test", or "total") in the JSON result.
- Monitor `testplay-status.json` during the run to track real-time progress (`compiling` -> `running` -> `done`).

### `result`

- Use `testplay result` to list stored run history without re-running Unity.

### `version`

- Use `testplay version` to print the current testplay version as JSON.
