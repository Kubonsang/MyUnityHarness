# 46. STATUS-FIX-04: Stealth 해제 순서 설계 의도 명확화

## 세션 목표
PR#2 리뷰 지적: `PlayerHealth.ApplyDamage`에서 Stealth가 Invincible 체크 이전에 해제되어, 무적 중에도 피격 시 은신이 풀리는 동작의 의도가 불명확하다는 지적.
코드 순서가 의도적임을 주석으로 명시.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerHealth.cs` | Stealth 해제 코드에 설계 의도 주석 추가 |

---

## 설계 결정

**현재 동작 유지** (순서 변경 없음):
```csharp
// Stealth: 피격(탐지) 시 즉시 해제 — 무적 여부와 무관하게 해제.
// 설계 의도: 무적은 피해를 막는 것이지 탐지를 막는 것이 아님.
// 공격을 받은 순간 은신이 풀리며, 피해 차단 여부는 그 이후에 판정한다.
Status?.RemoveEffect(StatusEffectType.Stealth);

if (_isInvincible || ...) return; // Invincible 체크
```

**근거**:
- `status_effects_plan.md`: "공격하거나 **피해를 받으면** 즉시 해제"
- 무적(Invincible)은 피해 차단 메커니즘, 은신(Stealth)은 탐지 메커니즘 — 독립적
- RPG 관례: 공격 대상이 된 순간(탐지) = 은신 해제, 피해 차단은 그 이후 판정

---

## 검증

### 컴파일 ✅
`unity-cli editor refresh --compile` → 에러 없음

코드 순서 변경 없음 — 런타임 동작 변화 없음. 주석 추가만.

STATUS-FIX-04 → `done` ✅

---

## 다음 권장 태스크
- **MONSTER-FIX-01**: `MonsterFSM._agent.speed` 변경 감지 후 설정
