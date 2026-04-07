# Workflow Recipes

## Unfamiliar Unity project

1. Run `unity-cli status`.
2. Run `unity-cli list`.
3. Read recent logs with `unity-cli console --filter all --lines 50 --stacktrace short`.
4. Query the current state with small `unity-cli exec` expressions before making changes.

## Code edit then verify

1. Change the source files in the workspace.
2. Run `unity-cli editor refresh --compile`.
3. Read compile output with `unity-cli console --filter all --stacktrace short`.
4. Enter play mode with `unity-cli editor play --wait` when the change needs runtime validation.
5. Re-read the console and stop play mode if needed.

## YAML asset edit then repair

1. Patch the `.prefab`, `.unity`, `.asset`, or `.mat` file as text.
2. Run `unity-cli reserialize <path...>`.
3. Run `unity-cli editor refresh` if the asset database needs to notice the change immediately.
4. Verify the result with a focused `exec`, a scene query, or play mode.

## Query and mutate with `exec`

1. Start with a read-only expression.
2. Add `--usings` only for namespaces the snippet truly needs.
3. Expand to a multi-statement mutation only after the read-only query proves the target exists.
4. Return a small confirmation payload so the next step can verify what changed.

Examples:

```bash
unity-cli exec "GameObject.Find(\"Player\") != null"
unity-cli exec "var go = GameObject.Find(\"Player\"); go.tag = \"Player\"; return new { go.name, go.tag };"
unity-cli exec "World.All.Count" --usings Unity.Entities
```

## Custom tool first

1. Check `unity-cli list` for an existing project tool.
2. Call the tool directly with `--params`.
3. Fall back to `exec` only when no tool already captures the operation.
4. If the same fallback keeps recurring, suggest promoting it into a custom `[UnityCliTool]`.

## Performance pass

1. Run `unity-cli profiler enable`.
2. Reproduce the behavior in Edit Mode or Play Mode.
3. Inspect hot spots with `unity-cli profiler hierarchy --frames 30 --min 0.5 --depth 3`.
4. Narrow the search with `--root <substring>` or `--parent <itemId>`.
5. Disable or clear the profiler when done.
