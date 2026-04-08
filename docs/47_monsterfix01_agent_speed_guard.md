# 47. MONSTER-FIX-01: MonsterFSM._agent.speed 변경 감지 후 설정

## 세션 목표
PR#2 리뷰 지적: `MonsterFSM.Tick()`에서 매 AI 틱마다 `_agent.speed`를 무조건 재설정 — 속도 변화가 없어도 NavMeshAgent 내부 재계산 유발.
`Mathf.Approximately` 비교 추가로 실제 변화가 있을 때만 재설정.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/MonsterFSM.cs` | Tick() 내 speed 재설정 전 Mathf.Approximately 비교 추가 |

---

## 변경 내용

**수정 전**:
```csharp
_agent.speed = _data.moveSpeed * speedMult;
```

**수정 후**:
```csharp
float newSpeed = _data.moveSpeed * speedMult;
if (!Mathf.Approximately(_agent.speed, newSpeed))
    _agent.speed = newSpeed;
```

---

## 설계 결정

- `NavMeshAgent.speed` setter는 값이 같아도 내부 경로 재계산을 트리거할 수 있음
- Slow/Haste 효과가 없는 일반 상태(상시 5f → 5f)에서 매 틱 재설정은 낭비
- `Mathf.Approximately`는 부동소수점 허용 오차(~0.00001f) 기반 비교 → float 곱셈 오차에 안전

---

## 검증

### 컴파일 ✅
`unity-cli editor refresh --compile` → `error CS` 없음 (LobbyRoleSelector warning은 기존 무관)

### 논리 검증 ✅
`unity-cli exec`으로 속도 보정 계산 + Mathf.Approximately 동작 확인:
- `slow=3.00 haste=7.00 combined=4.20`
- 동일 속도: `Approximately` → true (재설정 없음)
- 다른 속도: `!Approximately` → true (재설정 수행)

MONSTER-FIX-01 → `done` ✅

---

## 다음 권장 태스크
- **ITEM-FIX-01**: `PlayerInventory.IsRoleAllowed` 내 `GetComponent<RoleStatModifier>` → Awake/OnNetworkSpawn 캐싱
