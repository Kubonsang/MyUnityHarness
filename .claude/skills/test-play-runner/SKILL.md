---
name: testplay-runner
description: testplay CLI를 실행하여 Unity 컴파일 및 런타임 테스트를 수행합니다.
disable-model-invocation: true
---

# Unity Testplay 검증 워크플로우

1. **환경 검증**: `testplay check`를 먼저 실행하여 Exit 0이 나오는지 확인하십시오.
2. **테스트 실행**: `testplay run`을 실행하십시오.
3. **결과 대기 및 위임**:
   - 명령이 실행되면 결과는 `stdout`에 JSON 형태로 출력됩니다.
   - Exit 0이면 테스트 통과입니다.
   - 만약 Exit 2(컴파일 에러)나 Exit 3(테스트 실패)이 발생하더라도 **당신(메인 에이전트)이 직접 고치려 하지 마십시오**. 
   - 에러가 발생하면 시스템 훅(Hook)이 자동으로 `testplay-parser` 서브 에이전트를 호출하여 원본 파일을 수정할 것입니다. 당신은 수정이 완료될 때까지 대기한 후 다음 작업을 진행하십시오.