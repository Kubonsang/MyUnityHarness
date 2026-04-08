## 세션 목표
- `TEST-STATUS-01` 완료.
- `STATUS-FIX-05`, `STATUS-FIX-06` 회귀 방지용 `Stun` 검증을 `Assets/Tests/PlayMode`에 추가하고, 동일 시나리오를 Editor Play Mode에서 다시 재현해 통과 근거를 남긴다.

## 변경된 파일
- `feature_list.json`
- `Assets/Tests/GNF.Tests.PlayMode.asmdef`
- `Assets/Tests/PlayMode/Status01StunRegressionTests.cs`

## 핵심 설계
- 새 테스트 클래스 `Status01StunRegressionTests`를 추가했다.
- 플레이어 시나리오는 먼저 기본 공격이 실제로 피해를 주는지 확인한 뒤, 같은 하네스에서 `Stun` 적용 후 `Host` 입력 경로와 `SendAttackServerRpc()` 경로가 모두 피해를 막는지 검증한다.
- 몬스터 시나리오는 런타임에 임시 `NavMeshSurface`를 만들고 `NavMeshAgent`에 수동 경로를 설정한 뒤, `Stun` 적용 시 기존 경로 제거와 `isStopped = true`, 해제 후 잠금 해제를 확인한다.
- 테스트 어셈블리에서 `NavMeshSurface`를 사용하도록 `GNF.Tests.PlayMode.asmdef`에 `Unity.AI.Navigation` 참조를 추가했다.

## 검증 절차
- 컴파일: `unity-cli editor refresh --compile`
- 컴파일 에러 확인: `unity-cli console --filter error --stacktrace short`
- 결과: `[]`
- Editor Play Mode 등가 검증:
- 플레이어 결과: `baseline:100->90;hostBlocked:100->100;rpcBlocked:100->100`
- 몬스터 결과: `warped:True;calc:True;setPath:True;before:path=True|stopped=False;stun:path=False|stopped=True;recover:stopped=False`
- Play Mode 종료 후 콘솔 에러 재확인 결과: `[]`

## 주의 사항
- 이번 세션에서는 `unity-cli` 안정 경로가 없어 새 `PlayMode` 테스트 메서드를 Test Runner로 직접 실행하지는 않았다.
- 대신 새 테스트가 고정하려는 동일 시나리오를 Editor Play Mode에서 등가 수준으로 재현해 통과 결과를 기록했다.
- 이후 안정적인 테스트 실행 경로가 준비되면 `Status01StunRegressionTests`를 직접 실행해 회귀 방지 루틴에 편입하는 것이 좋다.

## 다음 권장 태스크
- `SKILL-01` `스킬 시스템 조건/효과(ConditionType/EffectType) Enum 및 SO 뼈대`
