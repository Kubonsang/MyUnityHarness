# 33. ITEM-01-B: IItemEffect 인터페이스 및 PlayerContext 정의

## 세션 목표
아이템 효과 구현체가 따를 `IItemEffect` 인터페이스와,
효과 발동 시 플레이어 컴포넌트를 전달하는 `PlayerContext`를 정의한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Item/IItemEffect.cs` | **신규** — `OnEquipped` / `OnUnequipped` / `OnActivated` 인터페이스 |
| `Assets/Scripts/Item/PlayerContext.cs` | **신규** — `PlayerHealth`, `PlayerCombat`, `PlayerController` 컴포넌트 묶음 클래스 |

---

## 핵심 설계

### IItemEffect

```csharp
public interface IItemEffect
{
    void OnEquipped(PlayerContext ctx);    // 장착 시
    void OnUnequipped(PlayerContext ctx);  // 해제 시
    void OnActivated(PlayerContext ctx);   // 발동 시 (Active 전용)
}
```

- 모든 메서드는 **서버에서만** 호출된다.
- `OnActivated`는 `itemType == Active`인 경우에만 `PlayerInventory.UseItem()`이 호출.
- `Passive` 아이템의 구현체는 `OnActivated`를 빈 메서드로 두면 된다.

### PlayerContext

```csharp
public class PlayerContext
{
    public PlayerHealth     Health     { get; }
    public PlayerCombat     Combat     { get; }
    public PlayerController Controller { get; }
}
```

- `PlayerInventory.OnNetworkSpawn()`에서 `GetComponent<>()`로 한 번 생성 후 보관.
- `PlayerStatus` 필드는 STATUS-01 완료 후 추가 예정 (TODO 주석).

### 호출 흐름 (ITEM-02 이후 완성)

```
[장착]  PlayerInventory.AddItem(itemId)
            → ItemRegistry.GetEffect(itemId)
            → effect.OnEquipped(ctx)

[해제]  PlayerInventory.RemoveItem(itemId)
            → effect.OnUnequipped(ctx)

[발동]  PlayerInventory.UseItem(itemId)  ← Active 전용
            → 쿨다운 검증
            → effect.OnActivated(ctx)
```

---

## 검증 절차

1. Unity 에디터 재컴파일 후 오류 없음 확인.
2. 더미 구현체 `HpBonusEffect : IItemEffect` 작성 시 세 메서드 자동완성 제공 확인.
3. 검증 완료 시 feature_list.json ITEM-01-B → `done`

---

## 다음 권장 태스크

- **ITEM-02**: `NetworkItemSlot`, `PlayerInventory` NetworkList 슬롯 동기화
