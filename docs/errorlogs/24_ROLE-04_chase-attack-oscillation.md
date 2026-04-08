# ROLE-04: Chase→Attack 진동으로 타겟 전환 반응 지연

## 증상
어그로 최고값이 바뀌어 타겟이 전환되어도 몬스터가 즉각 이동하지 않음.
Attack→Chase 전환은 발생하지만 다음 틱에 다시 이전 타겟으로 되돌아가며 진동 발생.

## Root Cause
`TickChase`에서 `dist <= _data.attackRange`(예: 2.0m)에 도달하면 Attack 진입 후 `ResetPath()`.
이때 기존 타겟(이전 공격 대상)이 여전히 근거리에 있어 근접 어그로(proximity aggro)가 계속 누적됨.
새 타겟으로 전환하더라도 다음 틱에 기존 타겟이 다시 최고 어그로가 되어 Attack→Chase→Attack 반복.
몬스터가 실제 이동 없이 제자리에서 상태만 반복.

## 수정 내용
`Assets/Scripts/Monster/MonsterFSM.cs`

- `[SerializeField] private float _attackStartRange = 0.6f` 추가 — Chase→Attack 진입 거리를 `_data.attackRange`와 분리
- `OnNetworkSpawn`: `_agent.stoppingDistance = _attackStartRange` 설정
- `TickChase`: `dist <= _data.attackRange` → `dist <= _attackStartRange` 로 교체

몬스터가 0.6m 이내에 들어와야 Attack 전환. Chase 상태 유지 시간이 길어져 타겟 전환 반응이 즉각적으로 개선됨.

## 검증 결과
재검증 필요 (ROLE-04 status → in_progress 유지).
`_attackStartRange` 값은 Inspector에서 조정 가능. 권장: 0.5~1.0m.
