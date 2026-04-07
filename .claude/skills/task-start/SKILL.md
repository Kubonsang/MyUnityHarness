---
name: task-start
description: feature_list.json의 태스크 ID를 기반으로 GNF_ 구현 세션을 시작합니다. 오케스트레이터로서 파이프라인을 지휘합니다.
argument-hint: "[TASK-ID]"
---

1. **환경 사전 검증 (Fail-Fast)**
   - 가장 먼저 `testplay check`를 실행하십시오. `ready: false`가 반환된다면 작업을 즉시 중단하고 힌트를 해결하십시오.

2. **태스크 확인 및 할당**
   - `feature_list.json`에서 `$ARGUMENTS`와 일치하는 태스크를 찾아 상태를 `in_progress`로 변경합니다.

3. **서브 에이전트 위임 (Sub-Agent Delegation)**
   - **[절대 규칙]** 메인 에이전트인 당신은 컴파일 에러나 테스트 실패를 직접 고치며 컨텍스트를 낭비하지 마십시오.
   - 코드를 수정한 후 검증이 필요할 때, 다음 명령어로 서브 에이전트를 호출하여 작업을 하청 주십시오:
     `claude --agent qa-engineer "testplay run --shadow 실행하고, 에러 나면 스스로 다 고쳐서 완벽히 통과하면 그때 요약해서 보고해."`
   - 서브 에이전트가 성공 리포트를 반환하면 다음 단계로 넘어갑니다.

4. **완료 및 문서화 (Context GC)**
   - 서브 에이전트의 검증이 완벽히 증명된 경우에만 태스크 상태를 `done`으로 변경하십시오.
   - `done` 처리된 태스크는 활성 컨텍스트 창을 가볍게 유지하기 위해 `feature_archive.json`으로 완전히 잘라내어(Move) 분리하십시오.