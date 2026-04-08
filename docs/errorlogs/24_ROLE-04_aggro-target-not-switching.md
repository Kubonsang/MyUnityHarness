# ROLE-04: 어그로 최고값 변경 시 타겟 즉각 전환 안 됨

## 증상
Tank가 DPS보다 어그로가 높아진 상태에서 몬스터가 즉각 Tank를 추적하지 않음.
Tank가 움직여야 비로소 몬스터가 따라옴.
공격 중에는 어그로가 변경되어도 타겟이 전혀 바뀌지 않음.

## Root Cause

두 가지 원인:

1. **TickChase — NavMesh 경로 재계산 지연**
   `_target`은 매 틱 `GetAITarget()`으로 갱신되지만, 타겟이 바뀌어도 `SetDestination()`만 호출하면
   NavMeshAgent가 기존 경로를 유지하며 즉각 재계산하지 않음.
   새 타겟이 이동해 목적지 좌표가 달라질 때까지 경로가 갱신되지 않음.

2. **TickAttack — 타겟 재평가 없음**
   `_attackTimer` 만료 전까지 `GetAITarget()` 호출 자체가 없어 어그로 변경이 무시됨.

## 수정 내용

`Assets/Scripts/Monster/MonsterFSM.cs`

- `TickChase()`: `newTarget != _target`이면 `_agent.ResetPath()` 호출 후 `SetDestination()` → 경로 즉각 재계산
- `TickAttack()`: 매 틱 `GetAITarget()` 호출 → 타겟이 바뀌면 즉시 Chase(또는 Idle) 전환

## 검증 결과
수정 후 재검증 필요 (status → in_progress).
