# 34. ITEM-02: PlayerInventory 서버 권위 NetworkList 슬롯 동기화

## 세션 목표
`NetworkItemSlot`, `ItemRegistry`, `PlayerInventory`를 구현해
아이템 슬롯 상태를 서버 권위 `NetworkList`로 모든 클라이언트에 동기화한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Item/NetworkItemSlot.cs` | **신규** — `INetworkSerializable` struct: `ItemId int` |
| `Assets/Scripts/Item/ItemRegistry.cs` | **신규** — `ItemData[]` Inspector 할당 + 런타임 `IItemEffect` 등록 SO |
| `Assets/Scripts/Item/PlayerInventory.cs` | **신규** — `NetworkList<NetworkItemSlot>`, `ServerAddItem`, `ServerRemoveItem`, `RequestPickup` ServerRpc |
| `Assets/Scripts/Item/PlayerContext.cs` | `PlayerInventory` 필드 추가 (생성자 4인자로 확장) |

---

## 핵심 설계

### NetworkItemSlot

```csharp
public struct NetworkItemSlot : INetworkSerializable
{
    public int ItemId;
    public void NetworkSerialize<T>(BufferSerializer<T> s) where T : IReaderWriter
        => s.SerializeValue(ref ItemId);
}
```

int 1개만 직렬화하므로 대역폭 최소화.

### ItemRegistry

- `[SerializeField] ItemData[] _items` — Inspector에서 모든 ItemData 에셋 할당
- `OnEnable()`에서 `Dictionary<int, ItemData>` 빌드 (itemId → ItemData)
- `RegisterEffect(int, IItemEffect)` — ITEM-03에서 효과 구현체가 호출
- itemId 중복 시 경고 로그

### PlayerInventory 아이템 추가 흐름

```
[클라이언트 IsOwner]
    RequestPickup(itemId)
        ├─ IsServer → ServerAddItem(itemId)
        └─ !IsServer → PickupItemServerRpc → ServerAddItem(itemId)

[서버 ServerAddItem]
    슬롯 여유 확인 (_maxSlots)
    ItemRegistry.GetData(itemId) 유효성 확인
    IsRoleAllowed(data) 직업 제한 확인
    _slots.Add(new NetworkItemSlot { ItemId = itemId })
    → NetworkList가 모든 클라이언트에 자동 전파
    // TODO ITEM-03: IItemEffect.OnEquipped
    // TODO SKILL-02: SkillConditionMonitor.AddEntries
```

### 직업 제한 패턴

`PlayerCombat.IsRoleAllowed()`와 동일 패턴 (`allowedRoles`가 비어있으면 전 직업 허용).

### UseItem / 쿨다운

ITEM-04 범위. `PlayerInventory`에 TODO 주석으로 위치 표시.

---

## 에디터 설정

1. Assets 우클릭 → Create → GNF → `Item Registry` 에셋 생성.
2. `_items` 배열에 ItemData 에셋 할당.
3. PlayerPrefab Inspector에서 `PlayerInventory._registry`에 위 에셋 연결.

---

## 검증 절차

1. Unity 에디터 재컴파일 후 오류 없음 확인.
2. ItemData 에셋 생성 (itemId=0, itemName="테스트 아이템").
3. ItemRegistry 에셋 생성 → _items[0]에 ItemData 할당.
4. PlayerPrefab에 `PlayerInventory` 추가 → `_registry` 연결.
5. Host 실행 → 서버 코드에서 `playerInventory.ServerAddItem(0)` 직접 호출.
6. `[PlayerInventory] 아이템 추가: 테스트 아이템 (id=0, client=...)` 로그 확인.
7. Client 접속 → `_slots` NetworkList 동기화로 아이템 정보 수신 확인.
8. 검증 완료 시 feature_list.json ITEM-02 → `done`

---

## 다음 권장 태스크

- **ITEM-03**: 패시브 아이템 장착 시 `IItemEffect.OnEquipped` 자동 호출 (TODO 주석 활성화)
