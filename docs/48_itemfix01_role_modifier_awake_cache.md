# 48. ITEM-FIX-01: PlayerInventory RoleStatModifier Awake 캐싱

## 세션 목표
PR#2 리뷰 지적: `PlayerInventory.IsRoleAllowed`에서 `GetComponent<RoleStatModifier>()`를 매 호출마다 실행.
Awake에서 캐싱하고, null 시 명시적 경고 로그 추가.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Item/PlayerInventory.cs` | `_roleStatModifier` 필드 추가, `Awake()` 신규, `IsRoleAllowed` 내 GetComponent 제거 |

---

## 변경 내용

**추가된 필드 + Awake**:
```csharp
private RoleStatModifier _roleStatModifier;

private void Awake()
{
    _roleStatModifier = GetComponent<RoleStatModifier>();
    if (_roleStatModifier == null)
        Debug.LogWarning($"[PlayerInventory] RoleStatModifier가 없습니다 — 직업 제한 없이 모든 아이템 허용됩니다. ({gameObject.name})", this);
}
```

**IsRoleAllowed 수정**:
```csharp
// Before:
var modifier = GetComponent<RoleStatModifier>();
RoleType playerRole = modifier?.RoleData?.roleType ?? RoleType.DPS;

// After:
RoleType playerRole = _roleStatModifier?.RoleData?.roleType ?? RoleType.DPS;
```

---

## 설계 결정

- `IsRoleAllowed`는 `ServerAddItem` 경로에서 아이템 습득 시마다 호출 — GetComponent 재호출 제거
- null 시 기본 roleType(`DPS`)으로 fallback → 기존 동작 유지
- null 경고 로그: 프리팹 설정 오류를 개발 단계에서 조기 발견

---

## 검증

### 컴파일 ✅
`unity-cli editor refresh --compile` → `error CS` 없음

### 논리 검증 ✅
`unity-cli exec`으로 IsRoleAllowed 분기 확인:
- `allowedRoles` 비어있음 → 허용 ✅
- `allowedRoles`에 DPS 포함 → DPS 플레이어 허용 ✅
- `allowedRoles`에 Tank만 있음 → DPS 플레이어 거부 ✅

ITEM-FIX-01 → `done` ✅

---

## 다음 권장 태스크
- **SKILL-01**: 스킬 시스템 ConditionType/EffectType Enum 및 SO 뼈대
