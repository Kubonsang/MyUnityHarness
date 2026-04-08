# 25. ROLE-04 디버그: AggroSystem 재설계 + MonsterFSM Hit 상태

## 세션 목표
ROLE-04 검증 중 발견된 proximity aggro 누적 문제와 타겟 전환 지연을 해결하고,
MonsterFSM에 Hit 상태를 추가해 피격 시 어그로 기반 타겟 재평가를 즉각 반영한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/AggroSystem.cs` | proximity aggro 누적 → 거리 보정치(snapshot) 방식으로 재설계 |
| `Assets/Scripts/Monster/MonsterFSM.cs` | Hit 상태 추가, 피격 이벤트 구독, 타겟 교체 시 ResetPath() |
| `Assets/Scripts/Monster/MonsterAnimationController.cs` | `MonsterAnimState.Hit` 추가, 기본 매핑 `"Hit"` 추가 |

---

## 핵심 설계

### AggroSystem 어그로 구조 변경

**변경 전**: proximity aggro를 `_aggroTable`에 매 틱 누적 (`+= proximityPerSec / dist × dt`)
- 근거리 플레이어(dist < 1m)는 시간이 지날수록 어그로가 폭발적으로 누적됨
- 데미지 어그로로 어그로 1위를 빼앗아도 다음 틱에 proximity로 즉시 회복됨

**변경 후**: 별도 딕셔너리 `_proximityModifier`에 현재 거리 기반 보정치를 매 틱 덮어씀

```
유효 어그로 = _aggroTable[id] + _proximityModifier[id]

_proximityModifier[id] = _proximityAggro × (1 - dist / detectionRange)
  → 탐지 범위 최근접: 최대 _proximityAggro (기본 5)
  → 탐지 범위 끝:    0
  → 누적되지 않음 — 이동하면 즉시 값이 바뀜
```

### MonsterFSM Hit 상태 흐름

```
피격 → OnHit() [MonsterHealth.OnDamageDealt 구독]
     → EnterState(Hit): ResetPath() + Hit 애니 + _hitStunTimer 설정

TickHit(): _hitStunDuration(0.2s) 경과 후
     → GetAITarget() (어그로 테이블 이미 갱신된 상태)
     → dist ≤ _attackStartRange → Attack
     → dist >  _attackStartRange → Chase
     → 타겟 없음               → Idle
```

이벤트 핸들러 실행 순서:
1. `AggroSystem.OnDamageDealt` → `_aggroTable` 갱신
2. `MonsterFSM.OnHit` → 최신 어그로 기준으로 Hit 상태 진입

### MonsterFSM Chase 타겟 전환 개선

타겟이 바뀔 때 `_agent.ResetPath()` 호출 → 기존 경로 즉시 폐기 → 새 타겟 방향으로 즉각 이동 시작.

---

## 에디터 설정

몬스터 Animator Controller에 `"Hit"` 스테이트 추가 필요.
없으면 Hit 애니메이션은 재생되지 않지만 FSM 로직(타겟 재평가 및 전환)은 정상 동작.

`AggroSystem` Inspector:
- `_proximityAggro` (구 `_proximityAggroPerSecond`): 기본 5. 높을수록 근거리 플레이어 우선도 ↑

---

## 검증 절차

1. Host(Tank aggroMultiplier=3.0) + Client(DPS aggroMultiplier=0.5) 시작
2. DPS가 몬스터를 먼저 공격 → 몬스터가 DPS 추적 확인
3. Tank가 공격 1회 → 몬스터가 즉시 Hit 상태 진입 후 Tank 방향 전환 확인
4. Tank 근거리: Attack 전환 / Tank 원거리: Chase 전환 확인
5. DPS가 계속 공격해도 Tank 어그로 우위 유지 확인 (proximity 보정치가 데미지 어그로를 압도 못함)
6. 완료 → feature_list.json ROLE-04 → `done`

---

## 주의 사항

- `_proximityAggro` 기본값(5)과 `_aggroPerDamage`(1) × `aggroMultiplier`(3.0) × 데미지(10) = 30의 비율 확인 필요. 수치가 너무 차이나면 proximity 보정치가 무의미해질 수 있음.
- Hit 상태 중 연속 피격 시 `_hitStunTimer`가 매번 리셋되어 Hit 상태가 연장될 수 있음. 연속 피격이 빈번하면 `Tick()` 내 사망 체크 이후 Hit 상태가 장시간 지속될 수 있으니 Inspector에서 `_hitStunDuration` 조정.

---

## 다음 권장 태스크

- **ROLE-05-A**: DPS 전용 무적 플래그(isInvincible) 통합
