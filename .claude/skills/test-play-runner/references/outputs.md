# Output Results & Parsing Guide (testplay-runner)

`testplay run` 실행 후 반환되는 표준 출력(stdout)은 반드시 아래와 같은 구조의 JSON 포맷을 가집니다. 
에이전트는 반환된 `exit_code`에 따라 해당하는 JSON 필드를 파싱하여 후속 조치를 취해야 합니다.

## 1. All tests pass (Exit 0)
모든 테스트가 통과했을 때의 출력 형태입니다. 이 경우 다음 단계로 진행하십시오.

```json
{
  "schema_version": "v1",
  "success": true,
  "exit_code": 0,
  "errors": [],
  "tests": [
    {
      "name": "PlayerTakesDamage",
      "status": "Passed",
      "duration_ms": 15,
      "absolute_path": "/path/to/project/Assets/Tests/PlayerTests.cs",
      "line": 42
    }
  ]
}
```

## 2. Test Failure (Exit 3)
로직 문제로 테스트가 실패했을 때의 출력 형태입니다.
**에이전트 행동 지침:** `tests` 배열을 순회하며 `status`가 `"Failed"`인 항목을 찾으십시오. 해당 항목의 `message`를 읽고, `absolute_path`와 `line`을 이용해 테스트 코드를 분석하고 비즈니스 로직을 수정하십시오.

```json
{
  "schema_version": "v1",
  "success": false,
  "exit_code": 3,
  "errors": [],
  "tests": [
    {
      "name": "PlayerTakesDamage",
      "status": "Failed",
      "message": "Expected: 90\n  But was:  100",
      "duration_ms": 12,
      "absolute_path": "/path/to/project/Assets/Tests/PlayerTests.cs",
      "line": 42
    }
  ],
  "new_failures": ["PlayerTakesDamage"]
}
```

## 3. Compile Failure (Exit 2)
C# 문법이나 참조 오류로 인해 컴파일 단계에서 실패했을 때의 출력 형태입니다.
**에이전트 행동 지침:** 테스트는 실행조차 되지 않았으므로 `tests` 배열은 비어 있습니다. 대신 `errors` 배열을 순회하여 `message`를 읽고, `absolute_path`와 `line`을 찾아 컴파일 오류(예: CS0103 등)를 우선적으로 해결하십시오.

```json
{
  "schema_version": "v1",
  "success": false,
  "exit_code": 2,
  "errors": [
    {
      "type": "compile",
      "message": "error CS0103: The name 'player' does not exist in the current context",
      "absolute_path": "/path/to/project/Assets/Scripts/GameManager.cs",
      "line": 15
    }
  ],
  "tests": []
}