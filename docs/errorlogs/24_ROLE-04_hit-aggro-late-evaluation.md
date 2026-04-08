# ROLE-04: Hit 상태 진입 후 타겟 재평가가 스턴 종료 시점으로 지연됨

## 증상
Hit 상태 진입 후 0.2초(hitStunDuration) 뒤에 GetAITarget()을 호출하므로,
그 사이 proximity aggro 변화에 의해 피격 시점과 다른 타겟으로 전환될 수 있음.
피격 → Hit 진입 → 스턴 종료 → 타겟 결정의 흐름에서 피격 직후 어그로 확정이 무의미해짐.

## Root Cause
TickHit()에서 타이머 만료 후 GetAITarget()을 호출.
OnHit() → AggroSystem.OnDamageDealt 갱신 직후의 어그로 상태가 보존되지 않음.

## 수정 내용
`Assets/Scripts/Monster/MonsterFSM.cs`

EnterState(Hit) 케이스에 `_target = GetAITarget()` 추가.
피격 시점(어그로 테이블 갱신 직후)에 타겟을 즉시 확정.
TickHit()은 타이머 대기 후 저장된 _target을 그대로 사용.

## 검증 결과
재검증 필요.
피격 → 0.2초 후 확정된 타겟(피격 시점 어그로 1위)으로 전환 예상.
