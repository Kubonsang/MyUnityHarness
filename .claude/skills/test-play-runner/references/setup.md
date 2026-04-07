# Configuration Setup (testplay-runner)

## Initialization
- `testplay init` 명령어를 실행하면 합리적인 기본값을 가진 `testplay.json` 파일이 프로젝트 루트에 자동 생성됩니다.
- 만약 이미 파일이 존재한다면 Exit 5 에러가 발생합니다. 덮어쓰려면 `--force` 플래그를 사용하십시오.
- `unity_path`가 생략된 경우, CLI는 `UNITY_PATH` 환경 변수를 폴백(fallback)으로 사용합니다.

## `testplay.json` Schema & Example
에이전트인 당신이 설정 파일을 직접 수정하거나 분석해야 할 때 아래 구조를 참조하십시오.

```json
{
  "unity_path": "/Applications/Unity/Hub/Editor/6000.0.35f1/Unity.app/Contents/MacOS/Unity",
  "project_path": ".",
  "test_platform": "edit_mode",
  "result_dir": ".testplay/runs",
  "retention": {
    "max_runs": 30
  },
  "timeout": {
    "compile_ms": 60000,
    "test_ms": 120000,
    "total_ms": 300000
  }
}
```

### Configuration Rules
- **test_platform**: 반드시 `"edit_mode"` (기본값) 또는 `"play_mode"` 중 하나여야 합니다.
- **retention**: `max_runs`를 0으로 설정하면 과거 실행 기록(Run history) 자동 삭제가 비활성화됩니다.
- **timeout (Two-phase execution)**: `compile_ms`와 `test_ms`는 **반드시 함께 설정**되어야 합니다. 둘 중 하나만 설정하는 것은 설정 유효성 검사 오류(Config validation error)를 발생시킵니다. 둘 다 생략할 경우 `total_ms`에 의존하는 단일 페이즈(Single-phase) 실행이 적용됩니다.