# 39. ITEM-05: PlayerInventory 캐싱 누락 수정

## 세션 목표
PR 리뷰에서 지적된 두 가지 캐싱 누락을 수정한다.
- `IsRoleAllowed()` 내 `GetComponent<RoleStatModifier>()` 반복 호출 → `Awake()` 캐싱
- `UseRejectedClientRpc` 호출 시 `new[] { OwnerClientId }` 반복 배열 할당 → `OnNetworkSpawn()` 캐싱

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Item/PlayerInventory.cs` | `_roleStatModifier` / `_ownerRpcParams` 필드 추가, `Awake()` 추가, `IsRoleAllowed()` · `ServerUseItem()` 수정 |

---

## 핵심 설계

### 수정 전후 비교

**`IsRoleAllowed()` (Before)**
```csharp
var modifier = GetComponent<RoleStatModifier>(); // 호출마다 탐색
RoleType playerRole = modifier?.RoleData?.roleType ?? RoleType.DPS;
```

**`IsRoleAllowed()` (After)**
```csharp
// Awake()에서 캐싱됨
RoleType playerRole = _roleStatModifier?.RoleData?.roleType ?? RoleType.DPS;
```

**`ServerUseItem()` (Before)**
```csharp
var rpcParams = new ClientRpcParams            // 매 호출마다 struct + 배열 생성
{
    Send = new ClientRpcSendParams { TargetClientIds = new[] { OwnerClientId } }
};
UseRejectedClientRpc(data.itemName, remaining, rpcParams);
```

**`ServerUseItem()` (After)**
```csharp
UseRejectedClientRpc(data.itemName, remaining, _ownerRpcParams); // OnNetworkSpawn에서 1회 생성
```

### 캐싱 위치 선택 이유
- `_roleStatModifier`: 런타임 중 컴포넌트가 추가/제거되지 않으므로 `Awake()`에서 1회 캐싱.
- `_ownerRpcParams`: `OwnerClientId`는 `OnNetworkSpawn()` 이후 고정값 → 서버 분기 안에서 1회 생성.

---

## 검증 절차

코드 리뷰 기반 검증 (에디터 실행 불필요):
1. `IsRoleAllowed()` 내 `GetComponent` 호출 없음 확인 ✓
2. `ServerUseItem()` 내 `new ClientRpcParams` / `new[]` 할당 없음 확인 ✓
3. 완료 → `feature_list.json` ITEM-05 → `done`

---

## 다음 권장 태스크
- **ITEM-06**: `_slots.OnListChanged` 구독 등록 및 늦은 접속 클라이언트용 초기 슬롯 순회 스텁 추가
