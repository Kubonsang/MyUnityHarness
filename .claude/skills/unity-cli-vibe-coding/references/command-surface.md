# Command Surface

## Connection and targeting

- Run `unity-cli status` first to confirm the connector is alive.
- Expect instance discovery to come from `~/.unity-cli/instances`.
- Assume the default target is the most recently updated non-stopped editor.
- Add `--project <substring>` to pin commands to a project path match.
- Add `--port <port>` to bypass discovery and talk to a specific editor directly.
- Remember that most commands wait for a fresh heartbeat before sending, so compiling or reloading editors often recover automatically.

## Core commands

### `status`

- Print the current editor state, project path, Unity version, and PID.
- Use it to confirm that a previous action actually landed.

### `list`

- Run `unity-cli list` to get the schema for every built-in and custom tool.
- Treat the output as the canonical source for command names, descriptions, and parameter names.

### `exec`

- Use `unity-cli exec "<C# code>"` for one-off inspection or mutation inside the Editor.
- Rely on auto-return for a single expression.
- Add an explicit `return` for multi-statement snippets.
- Pass extra namespaces with `--usings Unity.Entities,UnityEditor.SceneManagement`.
- Expect output serialization to flatten public fields, stop after depth 4, and truncate long enumerables at 100 items.

Examples:

```bash
unity-cli exec "Selection.activeGameObject?.name ?? \"nothing selected\""
unity-cli exec "EditorSceneManager.GetActiveScene().name" --usings UnityEditor.SceneManagement
unity-cli exec "var go = new GameObject(\"Marker\"); go.tag = \"EditorOnly\"; return go.name;"
```

### `console`

- Use `unity-cli console` for recent errors and warnings.
- Add `--filter all` to include standard logs.
- Add `--lines <n>` to limit the number of entries.
- Use `--stacktrace short` for useful callsites without Unity internals.
- Escalate to `--stacktrace full` only when the filtered trace is not enough.
- Use `--clear` to wipe the console before a focused repro.

### `editor`

- Use `unity-cli editor play --wait` to enter play mode and confirm the state change.
- Use `unity-cli editor stop` or `unity-cli editor pause` for runtime control.
- Use `unity-cli editor refresh --compile` after code edits when you need compilation to finish before continuing.

### `menu`

- Use `unity-cli menu "<Menu/Path>"` for existing Unity editor commands.
- Expect `File/Quit` to be blocked for safety.

### `reserialize`

- Use `unity-cli reserialize <path...>` immediately after text-editing `.prefab`, `.unity`, `.asset`, or `.mat` files.
- Use `unity-cli reserialize` with no arguments only when you truly want to rewrite the entire project.

### `profiler`

- Use `unity-cli profiler enable` before capturing fresh frame data.
- Use `unity-cli profiler hierarchy --frames 30 --min 0.5 --depth 3` for averaged hot spots.
- Use `--root <substring>` to focus on a specific system or marker.
- Use `unity-cli profiler status` to inspect capture bounds.
- Use `unity-cli profiler clear` when old frames would pollute the read.

## Direct tool calls

- Remember that unknown top-level CLI commands are forwarded directly to the connector as tool names.
- Prefer `--params '{...}'` for direct tool calls.
- If flags are more convenient, use `snake_case` flag names so Unity can resolve them.
- Expect `--params` keys to win when the same key also appears as a flag.

Examples:

```bash
unity-cli manage_editor --action set_active_tool --tool_name Move
unity-cli manage_editor --action add_tag --tag_name Enemy
unity-cli manage_editor --params '{"action":"add_layer","layer_name":"Gameplay"}'
unity-cli my_custom_tool --params '{"target":"Player","enabled":true}'
```

## Built-in advanced actions worth remembering

- Use `manage_editor` directly for actions that do not have a friendly subcommand.
- Available direct-only actions include `set_active_tool`, `add_tag`, `remove_tag`, `add_layer`, and `remove_layer`.
- Use `refresh_unity --compile request` when you want the low-level tool name rather than the `editor refresh --compile` wrapper.

## Custom tool discovery rules

- Expect tool names to default to `snake_case` from the C# class name.
- Expect `unity-cli list` to show `name`, `description`, `group`, and `parameters`.
- Prefer custom tools over large `exec` snippets when a project already exposes the operation you need.
- Promote repeated `exec` workflows into a custom `[UnityCliTool]` when you need repeatability or a stable schema.

## Execution model and quirks

- Expect the connector to listen on `127.0.0.1`, starting at port `8090`.
- Expect commands to run on the Unity main thread.
- Expect concurrent CLI calls to serialize through a single queue inside the connector.
- If a transition command returns an ambiguous success, verify with `status`, `console`, or a follow-up query.
