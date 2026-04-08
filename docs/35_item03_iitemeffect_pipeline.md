# 35. ITEM-03: 패시브 아이템 장착 시 IItemEffect 자동 호출 체계 구현

## 세션 목표
`PlayerInventory.ServerAddItem/RemoveItem`에서 `IItemEffect.OnEquipped/OnUnequipped`를 자동 호출하고,
검증용 더미 패시브 효과 `HpBonusEffect`를 구현한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Item/ItemRegistry.cs` | `EffectEntry[]` 직렬화 배열 추가 — Inspector에서 (itemId, 효과 SO) 쌍 할당 가능 |
| `Assets/Scripts/Item/PlayerInventory.cs` | TODO ITEM-03 주석 2개 활성화 — `OnEquipped` / `OnUnequipped` 호출 |
| `Assets/Scripts/Item/Effects/HpBonusEffect.cs` | **신규** — `ScriptableObject, IItemEffect` 구현체. `bonusHp` Inspector 설정 |

---

## 핵심 설계

### IItemEffect 호출 파이프라인

```
ServerAddItem(itemId)
    → _slots.Add(...)
    → _registry.GetEffect(itemId)?.OnEquipped(_ctx)   ← 활성화

ServerRemoveItem(itemId)
    → _slots.RemoveAt(i)
    → _registry.GetEffect(itemId)?.OnUnequipped(_ctx)  ← 활성화
```

### ItemRegistry EffectEntry

```csharp
[System.Serializable]
private struct EffectEntry
{
    public int             itemId;
    public ScriptableObject effect;   // IItemEffect 구현 SO
}
[SerializeField] private EffectEntry[] _effectEntries;
```

`BuildMaps()`에서 `effect is IItemEffect` 캐스팅 후 `_effectMap[itemId] = effect` 등록.
타입 불일치 시 경고 로그.

### HpBonusEffect

```csharp
[CreateAssetMenu(menuName = "GNF/Item Effects/HP Bonus Effect")]
public class HpBonusEffect : ScriptableObject, IItemEffect
{
    [SerializeField] private int _bonusHp = 50;

    OnEquipped   → ctx.Health.ApplyRoleBonus(+_bonusHp)
    OnUnequipped → ctx.Health.ApplyRoleBonus(-_bonusHp)
    OnActivated  → (빈 구현, Passive)
}
```

`PlayerHealth.ApplyRoleBonus(int)`를 재활용: `_maxHp += bonus`, `_currentHp = _maxHp`.

---

## 에디터 설정

1. Assets 우클릭 → Create → GNF → Item Effects → `HP Bonus Effect` 에셋 생성. `bonusHp` 설정.
2. `ItemRegistry` 에셋 Inspector → `_effectEntries` 배열에 (itemId=0, effect=위 에셋) 추가.
3. `_items` 배열에 itemId=0인 ItemData 에셋 연결 (Passive 타입).

---

## 검증 절차

1. Unity 에디터 재컴파일 후 오류 없음 확인.
2. 위 에디터 설정 완료.
3. Host 실행 → `PlayerInventory` Inspector → `Test/Request Pickup Item` (itemId=0) 호출.
4. 서버 Console:
   - `[PlayerInventory] 아이템 추가: ... (id=0, client=...)` 확인
   - `[HpBonusEffect] 장착 — 최대 HP +50` 확인
5. HP UI 또는 Inspector에서 MaxHp 증가 확인.
6. `Test/Server Remove Item` → `[HpBonusEffect] 해제 — 최대 HP -50` 확인.
7. 검증 완료 시 feature_list.json ITEM-03 → `done`

---

## 다음 권장 태스크

- **ITEM-04-A**: UseItem 입력 바인딩 처리 (액티브 아이템용)
