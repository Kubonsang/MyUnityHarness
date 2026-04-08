# ROLE-04: proximity aggro 폭발로 타겟 전환 불가

## 증상
Tank가 데미지 어그로(×3.0)로 어그로 1위가 되어도
몬스터가 기존 타겟(근거리 플레이어)을 계속 공격함.
타겟 전환이 일어나더라도 다음 틱에 즉시 복구됨.

## Root Cause
proximity aggro 공식: `_proximityAggroPerSecond / dist`

`dist`가 0.1f 클램프였으므로 0.1m 거리에서 `0.5 / 0.1 = 5/sec`.
몬스터가 공격 중인 플레이어는 항상 근거리에 있어 proximity aggro가 무한정 누적.
데미지 어그로(1회 타격 기준)가 아무리 높아도 초당 5씩 쌓이는 근접 어그로를 극복할 수 없음.

## 수정 내용
`Assets/Scripts/Monster/AggroSystem.cs`

```
- float dist = Mathf.Max(0.1f, ...)
+ float dist = Mathf.Max(1f, ...)
```

분모 최솟값을 1.0f로 올려 proximity aggro를 최대 `_proximityAggroPerSecond`/sec로 고정.
1m 이하에서 거리가 줄어도 어그로가 더 이상 폭발적으로 증가하지 않음.

수치 비교:
- 0.1m 기준: 5/sec → 0.5/sec (10배 감소)
- 0.6m 기준: 0.83/sec → 0.5/sec
- 1m 이상: 변경 없음

## 검증 결과
재검증 필요 (ROLE-04 status → in_progress 유지).
Tank 1회 공격(데미지 10, aggroMultiplier 3.0 → 30 aggro) 후
DPS 플레이어가 1m 이내에 있어도 Tank가 약 60초(30 / 0.5/sec) 동안 어그로 우위 유지 예상.
