# 41. STATUS-04: 버프 5종 효과 로직

## 세션 목표
Invincible / Stealth / Valor / Haste / Fortify 버프의 실제 게임플레이 효과를 서버 권위로 구현한다.
`PlayerHealth`, `PlayerCombat`, `PlayerController`, `MonsterFSM`, `MonsterHealth`, `AggroSystem` 소비 지점에 각 효과를 연결한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerHealth.cs` | Invincible 상태 효과 체크 추가 + Fortify 피해 감소 + 피격 시 Stealth 해제 |
| `Assets/Scripts/Player/PlayerCombat.cs` | `_status` 캐싱 + Valor 피해 증폭 + 공격 시 Stealth 해제 |
| `Assets/Scripts/Player/PlayerController.cs` | Haste 이동속도 증가 (Slow와 독립 곱연산) |
| `Assets/Scripts/Monster/MonsterFSM.cs` | Haste 속도 보정 추가 + Valor 피해 증폭 + FindNearestPlayer Stealth 필터 |
| `Assets/Scripts/Monster/MonsterHealth.cs` | `MonsterStatus` lazy 프로퍼티 + Invincible 체크 + Fortify 피해 감소 |
| `Assets/Scripts/Monster/AggroSystem.cs` | Tick / GetTarget 루프에서 Stealth 플레이어 제외 |

---

## 핵심 설계

### 효과별 소비 지점 요약

| 버프 | 소비 위치 | 구현 방식 |
|------|-----------|-----------|
| Invincible | `PlayerHealth.ApplyDamage`, `MonsterHealth.ApplyDamage` | `_isInvincible OR HasEffect(Invincible)` 시 데미지 블록 |
| Stealth | `MonsterFSM.FindNearestPlayer`, `AggroSystem.Tick/GetTarget` | 은신 플레이어 탐지·어그로 제외. 공격/피격 시 `RemoveEffect(Stealth)` |
| Valor | `PlayerCombat.PerformAttack`, `MonsterFSM.ApplyAttackDamage` | 가하는 피해 × `(1 + 0.1 × stacks)` (최대 3스택 = 30%) |
| Haste | `PlayerController.ApplyMovement`, `MonsterFSM.Tick` | 이동속도 × `(1 + 0.4)` (Slow와 독립 곱연산) |
| Fortify | `PlayerHealth.ApplyDamage`, `MonsterHealth.ApplyDamage` | 받는 피해 × `(1 - 0.2)` |

### Invincible 이중 경로
`PlayerHealth._isInvincible` 플래그(ROLE-05 DPS 대시 용)와 `HasEffect(Invincible)` 상태 효과를 OR 조건으로 통합.
두 경로 중 하나만 참이어도 피해 면역. 기존 플래그 경로는 유지해 하위 호환 보장.

### Stealth 해제 조건
- 공격 시: `PlayerCombat.PerformAttack()` 진입 즉시 `RemoveEffect(Stealth)`
- 피격 시: `PlayerHealth.ApplyDamage()` 진입 즉시 `RemoveEffect(Stealth)` (무적/면역 여부 무관)

### Haste + Slow 동시 적용
`speedMult` 에 독립 곱연산 적용:
```
speedMult *= (1f - 0.4f) // Slow
speedMult *= (1f + 0.4f) // Haste
→ 1.0 × 0.6 × 1.4 = 0.84 (완전 상쇄 아님)
```

### 수식 검증 결과 (exec)

| 버프 | exec 결과 |
|------|-----------|
| Fortify: damage 25 × 0.8 | **20 [PASS]** |
| Valor x2 스택: damage 10 × 1.2 | **12 [PASS]** |
| Haste: speed 5 × 1.4 | **7.0 [PASS]** |

---

## 검증 절차

### 컴파일 검증 ✅
`unity-cli editor refresh --compile` → `unity-cli console --filter error` → 에러 없음

### 수식 검증 (exec) ✅
`unity-cli exec`로 Fortify / Valor / Haste 수식 검증 — 전부 PASS

완료 → feature_list.json STATUS-04 → `done` ✅

---

## 주의 사항
- **Stealth는 AggroSystem.GetTarget 필터만**: 스텔스 중 이미 어그로 테이블에 누적된 점수는 초기화되지 않음. 은신 해제 직후 기존 어그로로 즉시 타겟될 수 있음.
- **Invincible 중 Stealth 해제**: 피격 시 Stealth는 피해 무시 전에 해제됨 (무적이어도 탐지 가능해짐). 설계 의도에 맞지 않으면 해제 조건을 `if (amount > 0 && !invincible)` 로 변경 필요.
- **ValorDamageIncreasePerStack 중복 상수**: `PlayerCombat`과 `MonsterFSM`에 각각 선언. 밸런스 조정 시 두 파일 모두 수정 필요.
- **Fortify 상수 중복**: `PlayerHealth`와 `MonsterHealth`에 각각 선언. 동일.
- **MonsterStatus 프리팹 부착 필요**: MonsterFSM Haste/Valor 동작을 위해 몬스터 프리팹에 `MonsterStatus` 컴포넌트가 있어야 함. 미부착 시 null 체크로 크래시는 없음.

---

## 다음 권장 태스크
- **SKILL-01**: 스킬 시스템 ConditionType/EffectType Enum 및 SO 뼈대
