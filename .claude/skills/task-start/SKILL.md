---
name: task-start
description: feature_list.json의 태스크 ID를 기반으로 GNF_ 구현 세션을 시작합니다. 오케스트레이터로서 파이프라인(기획->구현->QC->QA->Vibe->문서->커밋)을 지휘합니다.
argument-hint: "[TASK-ID]"
---

1. **환경 사전 검증 (Fail-Fast)**
   - 가장 먼저 `testplay check`와 `unity-cli status`를 차례로 실행하십시오. `ready: false`가 반환되거나 에디터 통신에 실패하면 작업을 즉시 중단하고 힌트를 해결하십시오.

2. **태스크 확인 및 할당**
   - `feature_list.json`에서 `$ARGUMENTS`와 일치하는 태스크를 찾아 상태를 `in_progress`로 변경합니다.

3. **사전 설계 위임 (Sub-Agent Delegation 1: Architect)**
   - 방대한 코드 탐색으로 당신의 컨텍스트를 낭비하지 마십시오. 다음 명령어로 기획을 하청 줍니다:
     `claude --agent system-architect "현재 태스크 [태스크ID]의 요구사항과 코드베이스를 분석해서, docs/blueprints/[태스크ID]_blueprint.md 파일에 구현 설계도를 작성하고 돌아와."`

4. **비즈니스 코어 로직 작성 및 엔진 동기화**
   - 아키텍트가 설계도 작성을 완료했다고 보고하면, 당신은 `Read` 툴로 해당 설계도(`.md`)를 읽으십시오.
   - 설계도의 가이드에 따라 **당신이 직접 C# 코어 로직을 작성하고 파일에 저장(Edit)**합니다.
   - **[필수 동기화]** 코드 작성이 끝나면, 다음 명령어를 실행하여 유니티 에디터가 새 코드를 완벽히 컴파일하도록 강제하십시오: `unity-cli editor refresh --compile`

5. **정적 품질 검수 루프 (Sub-Agent Delegation 2: QC)**
   - 컴파일이 완료되면, 테스트를 돌리기 전에 코드 품질을 검사합니다:
     `claude --agent quality-controller "방금 구현한 [태스크ID] 관련 파일들을 설계도와 대조해서 아키텍처/성능/NGO 리스크를 찾고 docs/issues/[태스크ID]_bug_report.md 에 명세서를 써와."`
   - QC 에이전트가 리포트를 반환하면 이를 읽고 지적된 치명적 결함을 수정한 뒤, 다시 4번의 `refresh --compile` 과정을 거치십시오. 결함이 없다면 다음으로 넘어갑니다.

6. **동적 테스트 파이프라인 위임 (Sub-Agent Delegation 3: QA)**
   - 품질 검증이 끝난 코드를 대상으로 다음 명령을 실행하십시오:
     `claude --agent qa-engineer "방금 구현한 [태스크ID] 코드를 분석해서 1. Assets/Tests/PlayMode/[태스크ID]_Tests.cs 생성 (기존파일 수정금지). 2. Tests.asmdef 업데이트. 3. testplay run --shadow --filter [태스크ID]_Tests 실행. 4. 에러 시 무한 자동 복구 후 최종 결과만 보고해."`

7. **육안 검증을 위한 씬/프리팹 셋업 (Visual QA Setup with Vibe Coding)**
   - 코어 로직 및 테스트가 통과하면, 클라이언트(개발자)가 유니티 에디터에서 Play 버튼만 누르면 즉시 결과를 육안으로 확인할 수 있도록 환경을 세팅합니다.
   - **[절대 규칙: 텍스트 수정 금지]** `.prefab`이나 `.unity` 파일의 YAML 텍스트를 `Edit` 도구로 직접 수정하지 마십시오. 반드시 `unity-cli-vibe-coding` 가이드에 따라 조작하십시오.
   - **[씬 및 에셋 배치]** `unity-cli exec`를 사용하여 다음을 수행합니다:
     * `PrefabUtility.InstantiatePrefab` 또는 `GameObject.Instantiate`로 기능을 씬에 배치.
     * 카메라가 오브젝트를 바로 비출 수 있도록 `transform.position` 조정.
   - **[상태 저장 및 강제 동기화]** 조작이 끝났다면 다음을 차례로 실행하십시오:
     1. `unity-cli exec "UnityEditor.SceneManagement.EditorSceneManager.SaveOpenScenes();"`
     2. `unity-cli reserialize <조작한_경로>`
     3. `unity-cli editor refresh --compile`
   - **[가이드라인 제공]** 클라이언트에게 "어떤 씬을 열고 플레이하면 되는지" 브리핑하십시오.

8. **문서화 위임 (Sub-Agent Delegation 4: Tech Writer)**
   - 셋업이 완료되면, 다음 명령어로 세션 기록을 지시하십시오:
     `claude --agent tech-writer "doc-section-normalize 스킬을 사용해서 방금 완료된 태스크($ARGUMENTS)에 대한 공식 문서를 docs/ 폴더에 작성하고 요약 보고해."`

9. **형상 관리 및 커밋 위임 (Sub-Agent Delegation 5: Git Operator)**
   - 문서화가 완료되면 형상 관리를 하청 주십시오:
     `claude --agent git-operator "현재 태스크 [태스크ID]와 관련된 모든 변경 사항을 스테이징하고, Conventional Commits 규격(예: feat: [TASK-ID] 내용)에 맞춰 커밋을 남긴 뒤 해시만 보고하고 종료해."`

10. **가비지 컬렉션 및 종료 (Context GC)**
   - 깃 오퍼레이터로부터 커밋 해시 보고를 받으면, 태스크 상태를 `done`으로 변경하십시오.
   - 활성 컨텍스트를 비우기 위해 즉시 해당 JSON 블록을 `feature_archive.json`으로 완전히 이동시킨 후 세션을 최종 종료합니다.