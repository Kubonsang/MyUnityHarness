---
name: unity-cli-vibe-coding
description: Drive a Unity Editor from Claude Code through `unity-cli`. Use when working in a Unity project and you need to inspect editor or runtime state, run one-off C# inside the Editor, read console output, switch play mode, refresh or compile scripts, reserialize YAML assets after text edits, inspect profiler data, or discover and call custom `[UnityCliTool]` commands exposed by the project.
---

# Unity CLI Vibe Coding

Use `unity-cli` as the first control surface for live Unity work. Run all `unity-cli` commands via the **Bash tool**. Keep the loop tight: inspect the current state, make one focused change, sync Unity, then verify with console output, play mode, or profiler data.

## Start Here

1. Resolve the target editor.
- Run `unity-cli status`.
- If multiple editors may be open, add `--project <path-substring>` or `--port <port>` to every command in the loop.
- If `unity-cli` is not on `PATH`, use the local launcher available on the machine before proceeding.

2. Discover project-specific capabilities.
- Run `unity-cli list` at the start of an unfamiliar project.
- Prefer project custom tools over large `exec` snippets when a custom tool already expresses the intent.

3. Choose the smallest useful action.
- Use `console` for failures and warnings.
- Use `exec` for one-off queries or mutations.
- Use `menu` for existing editor commands.
- Use `reserialize` after editing Unity YAML assets as text.
- Use `profiler` only when the task is performance-sensitive.

## Operating Loop

1. Inspect.
- Query the scene, selection, assets, or editor state with `unity-cli exec "..."`
- Read logs with `unity-cli console --filter all --stacktrace short`
- Read available tools with `unity-cli list`

2. Change.
- Prefer a custom tool: `unity-cli my_tool --params '{"key":"value"}'`
- Otherwise use `unity-cli exec` for focused editor-side mutations
- Use `unity-cli menu "<Menu/Path>"` when a built-in menu item already does the job

3. Sync Unity.
- After C# or asset database changes, run `unity-cli editor refresh --compile` when you need scripts reimported and compilation confirmed
- After text edits to `.prefab`, `.unity`, `.asset`, or `.mat`, run `unity-cli reserialize <path...>`

4. Verify.
- Use `unity-cli editor play --wait` for play mode checks
- Re-read console output after the change
- Use profiler commands when the task depends on performance or frame cost

## Heuristics

- Prefer one `unity-cli` command at a time. The connector serializes requests anyway.
- Prefer `exec` for ad hoc work and promote recurring workflows into project custom tools.
- Keep `exec` snippets small. For multi-statement snippets, include an explicit `return`.
- Pass extra namespaces with `--usings Namespace.One,Namespace.Two` (comma-separated, no spaces).
- Use `console --stacktrace full` only when `short` is insufficient.
- Treat `unity-cli list` as the schema source for built-in and custom tools.
- Remember that unknown top-level CLI commands are forwarded as direct tool calls, so `unity-cli tool_name --flag value` is valid when the connector exposes `tool_name`.
- Prefer `--params '{...}'` or `snake_case` flag names for direct tool calls.
- Do not rely on `menu "File/Quit"`; it is blocked.
- Read [references/command-surface.md](references/command-surface.md) when you need exact command shapes or advanced built-in actions.
- Read [references/workflow-recipes.md](references/workflow-recipes.md) when you want a proven Unity iteration loop.

## GNF_ 프로젝트 특이사항

- **`exec` 동작 확인** — `unity-cli exec "return Time.time;"` 정상 동작. Roslyn 우려는 해당 없음.
- **`run_tests` 불안정** — Unity 재시작 후 목록에서 사라짐. 테스트 실행 용도로 사용하지 않는다.
- **`[UnityCliTool]` 사용 가능** — `UnityCliConnector.Editor.dll` 이 프로젝트에 설치됨. 네임스페이스: `UnityCliConnector`. Unity 재시작 후 `editor refresh --compile` 으로 재등록 필요.
- **`--usings` 주의** — 배열 `["x"]` 형식 오류 발생. 반드시 콤마 구분 문자열 `--usings System.Linq,UnityEngine` 사용.
- **`exec` 멀티라인** — 여러 문장은 세미콜론으로 연결하고 마지막에 `return` 명시.

## References

- Read [references/command-surface.md](references/command-surface.md) for exact command syntax, direct tool-call rules, and advanced built-in actions not covered by the friendly subcommands.
- Read [references/workflow-recipes.md](references/workflow-recipes.md) for common Unity vibe-coding loops: inspect, mutate, sync, verify, and profile.
