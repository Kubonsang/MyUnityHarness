# GNF_ Project: Unity 6 Multiplayer RPG (Root Manual)

이 파일은 GNF_ 프로젝트의 최상위 지도(Map)이자 핵심 행동 강령입니다.
도메인별 상세 지침은 `.claude/` 폴더 아래 문서를 따릅니다.

## 1. Core Workflow (Strict)
모든 작업은 다음 루프를 기계적으로 준수해야 합니다.
1.  **Plan First:** 코드를 수정하기 전 반드시 Plan Mode(`Shift+Tab` 또는 `/plan`)로 진입하여 수정 계획을 수립합니다.
2.  **Cross-Review:** 계획이 수립되면 "네가 시니어 엔지니어라면 이 계획의 허점은 무엇이라고 생각하는가?"라고 자문하고 리뷰를 반영합니다.
3.  **Verification Loop:** 코드를 구현한 뒤, **"이게 된다는 걸 증명해 봐(Prove that it works)"**라는 지침에 따라 컴파일/런타임 증거를 수집합니다. 검증되지 않은 작업은 `done`으로 처리할 수 없습니다.

## 2. Tool & Agent Commands
*   병렬 작업이 필요할 경우 `--worktree` 플래그를 사용하여 독립된 환경(Git worktree)에서 충돌 없이 작업하세요.
*   특정 역할이 필요할 경우 서브 에이전트(`code-reviewer`, `api-designer` 등)에게 역할을 위임하세요.

## 3. 🚨 Mistake Log (학습 루프)
과거에 발생했던 치명적 실수들입니다. 세션 시작 시 반드시 숙지하고 절대 반복하지 마십시오.
*   *2026-03-12:* `GameObject.Find`를 Update 루프 내부에서 사용하여 심각한 프레임 드랍 발생 (절대 캐싱 사용할 것).
*   *2026-03-20:* 멀티플레이어 환경에서 클라이언트가 서버 검증 없이 권한(Authority) 상태를 직접 수정하여 동기화 깨짐 발생.

## 4. Cli program
아래 프로그램은 Unity 프로젝트에서 사용되는 CLI 프로그램입니다. `.claude/skills/` 에 각각 정리돼 있습니다.
* unity-cli: Unity 프로젝트의 빌드 및 에디터 조작을 위한 프로그램입니다. 
* testplay-runner: Unity 프로젝트의 런타임 테스트를 위한 CLI 프로그램입니다.