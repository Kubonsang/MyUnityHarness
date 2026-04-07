---
name: task-start
description: feature_list.json의 태스크 ID를 기반으로 GNF_ 구현 세션을 시작합니다. 블루프린트 로드, 구현, 서브 에이전트를 통한 QA 검증, 문서화까지의 파이프라인을 지휘합니다.
argument-hint: "[TASK-ID (예: ROLE-03, WEAPON-01-A)]"
disable-model-invocation: true
---

# Target Task: $ARGUMENTS

이 스킬은 GNF_ 프로젝트의 구현 세션을 기계적으로 실행하기 위한 오케스트레이션 매뉴얼입니다. 진행 단계마다 사용자에게 현재 어떤 문서를 참고하여 무슨 행동을 하고 있는지 보고하십시오.

## Workflow

1. **초기화 및 분석**
   - `feature_list.json`에서 `$ARGUMENTS`에 해당하는 태스크를 확인하고 `status`를 `in_progress`로 변경합니다.
   - 태스크 ID 카테고리를 추출해 `docs/blueprints/XXX.md`를 읽습니다.
   - 네트워크(`networkvariable-vs-rpc`), 퍼포먼스(`unity-runtime-performance-review`) 등 필요한 도메인 스킬이 있다면 능동적으로 호출하여 읽습니다.

2. **구현 진행**
   - 수립된 계획과 아키텍처에 따라 코드를 작성하고 수정합니다.

3. **기계적 검증 (서브 에이전트 위임)**
   - 구현이 완료되면, `@agent-qa-engineer` (또는 `qa-engineer` 서브 에이전트)를 호출하여 작성된 코드에 대한 컴파일 및 런타임 검증을 지시하십시오.
   - "현재 변경한 파일에 대해 컴파일 오류가 없는지, 그리고 주어진 태스크 조건대로 런타임에서 작동하는지 검증해달라"고 요청합니다.

4. **완료 및 문서화**
   - QA 에이전트가 `PASS`를 반환하면 `/doc-section-normalize`를 사용하여 `docs/`에 세션 문서를 작성합니다.
   - 문서에는 수정 파일, 런타임 경로 영향, 논리 검증 내용이 포함되어야 합니다.
   - 검증이 완벽히 증명된 경우에만 `feature_list.json`의 상태를 `done`으로 변경하십시오. 실패 시 `test_failure`로 기록합니다.