# 40. STATUS-03: 디버프 6종 효과 로직

## 세션 목표
Wound / Stun / Poison / Burn / Fatigue / Slow 디버프의 실제 게임플레이 효과를 서버 권위로 구현한다.
`StatusBehaviour` 틱 콜백, `PlayerHealth` / `PlayerController` / `MonsterFSM` 소비 지점에 각 효과를 연결한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Status/StatusBehaviour.cs` | `OnEffectTick(StatusEffectType, int)` virtual 추가; `TickEffects()`에서 틱마다 호출 |
| `Assets/Scripts/Status/PlayerStatus.cs` | `PlayerHealth` 캐싱 + `OnEffectTick` override — Poison DoT(스택×5), Burn DoT(8/틱) |
| `Assets/Scripts/Status/MonsterStatus.cs` | `MonsterHealth` 캐싱 + `OnEffectTick` override — Poison DoT, Burn DoT |
| `Assets/Scripts/Player/PlayerHealth.cs` | `PlayerStatus` 캐싱; `ApplyDamage`에 Fatigue +25% 증폭; `ApplyHeal`에 Burn 차단·Wound 40% 감소 |
| `Assets/Scripts/Player/PlayerController.cs` | `PlayerStatus` 캐싱; `ApplyMovement`에 Stun 차단·Slow 40% 속도 감소 |
| `Assets/Scripts/Monster/MonsterFSM.cs` | `MonsterStatus` 캐싱; `Tick()`에 Stun 조기 반환·Slow `agent.speed` 보정 |

---

## 핵심 설계

### 틱 콜백 패턴 (StatusBehaviour)
`TickEffects()`는 초당 1회 활성 효과 목록을 순회한다.
만료 감산 **이전**에 `OnEffectTick(type, stacks)`를 호출해 DoT가 마지막 틱까지 발동되게 한다.

```
TickEffects()
  for each effect:
    OnEffectTick(type, stacks)   ← Poison/Burn 데미지 적용
    effect.RemainingDuration -= 1f
    if 만료 → RemoveAt
```

`StatusBehaviour`의 기본 구현은 no-op. `PlayerStatus` / `MonsterStatus`가 override해 각 health 컴포넌트에 `ApplyDamage` 호출.

### 효과별 소비 지점 요약

| 디버프 | 소비 위치 | 구현 방식 |
|--------|-----------|-----------|
| Wound | `PlayerHealth.ApplyHeal` | 힐량 × 0.6 (40% 감소) |
| Burn | `PlayerHealth.ApplyHeal` | 힐 완전 차단(return) + `OnEffectTick` 8 데미지/틱 |
| Poison | `OnEffectTick` | 스택 × 5 데미지/틱 (최대 5스택 → 최대 25/틱) |
| Fatigue | `PlayerHealth.ApplyDamage` | 받는 피해 × 1.25 |
| Stun | `PlayerController.ApplyMovement`, `MonsterFSM.Tick` | 해당 메서드 전체 skip |
| Slow | `PlayerController.ApplyMovement`, `MonsterFSM.Tick` | 이동속도 × 0.6 (40% 감소) |

### Null 안전성
`PlayerHealth` / `PlayerController` / `MonsterFSM` 모두 `_status` / `_monsterStatus`가 null일 경우 조건 분기를 건너뛰도록 null 체크 포함.
→ 컴포넌트가 빠진 프리팹에서도 NullReferenceException 없음.

### 서버 권위 경계
- 모든 소비 지점은 이미 `if (!IsServer) return;`으로 서버 전용.
- `HasEffect()`는 `NetworkList` 읽기 — 클라이언트에서 호출해도 안전하나, 효과 적용 경로 자체가 서버에서만 실행됨.

---

## 검증 절차

### 컴파일 검증 ✅
`unity-cli editor refresh --compile` → `unity-cli console --filter error` → 에러 없음 확인

### 수식 검증 (exec) ✅
`unity-cli exec`로 각 디버프 계산 수식 직접 실행:

| 디버프 | exec 결과 |
|--------|-----------|
| Wound: `heal 20 * 0.6` | **12 [PASS]** |
| Fatigue: `damage 20 * 1.25` | **25 [PASS]** |
| Poison: `3stacks * 5` | **15 [PASS]** |
| Slow: `speed 5 * 0.6` | **3.00 [PASS]** |
| Burn DoT per tick | **8 [PASS]** |

### 코드 리뷰 검증 ✅
- **Burn heal block**: `PlayerHealth.ApplyHeal` — `HasEffect(Burn)` 시 `return` (차단 경로 확인)
- **Stun block**: `PlayerController.ApplyMovement`, `MonsterFSM.Tick` — `HasEffect(Stun)` 시 즉시 `return`

### NGO PlayMode 테스트 ✅
`Assets/Tests/PlayMode/Status03DebuffTests.cs` — 4/4 PASS

| 테스트 | 결과 |
|--------|------|
| Wound_ReducesHealBy40Percent | **PASS** |
| Burn_BlocksHealCompletely | **PASS** |
| Fatigue_AmplifiesIncomingDamageBy25Percent | **PASS** |
| Poison_DealsDotDamagePerStackPerTick | **PASS** |

완료 → feature_list.json STATUS-03 → `done` ✅ (PlayMode 테스트 4/4 PASS)

---

## 주의 사항
- **MonsterStatus 프리팹 부착 필요**: MonsterFSM Stun/Slow 동작을 위해 몬스터 프리팹에 `MonsterStatus` 컴포넌트가 있어야 함. 현재 미부착 상태면 효과 미발동(null 체크로 크래시는 없음).
- **Wound는 MonsterHealth 미연동**: `MonsterHealth.ApplyHeal` 미구현으로 몬스터의 힐 감소 미적용. 몬스터 힐 기능 추가 시 별도 연동 필요.
- **SlowSpeedReductionFactor 중복 상수**: `PlayerController`와 `MonsterFSM`에 각각 선언. 리밸런싱 시 두 파일 모두 수정 필요.

---

## 다음 권장 태스크
- **STATUS-04**: 버프 5종(Invincible, Stealth, Valor, Haste, Fortify) 효과 로직
