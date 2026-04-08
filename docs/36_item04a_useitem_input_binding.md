# 36. ITEM-04-A: UseItem 입력 바인딩 처리 (액티브 아이템용)

## 세션 목표
F키(Keyboard) / leftShoulder(Gamepad) 입력으로 인벤토리 슬롯 0의 액티브 아이템을 서버에 사용 요청하는 바인딩 체계 구현.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/InputSystem_Actions.inputactions` | `UseItem` Button 액션 추가, F키·leftShoulder 바인딩 추가 |
| `Assets/InputSystem_Actions.cs` | `m_Player_UseItem` 필드, `FindAction`, `@UseItem` property, `AddCallbacks`·`UnregisterCallbacks`, `IPlayerActions.OnUseItem` 추가 |
| `Assets/Scripts/Player/PlayerInputHandler.cs` | `_inventory` 필드 캐싱, `UseItem.performed` 구독/해제, `OnUseItem()` 콜백 추가 |
| `Assets/Scripts/Item/PlayerInventory.cs` | `RequestUseItem(int)`, `UseItemServerRpc`, `ServerUseItem` 추가 |

---

## 핵심 설계

### 입력 흐름
```
F / leftShoulder
  → PlayerInputHandler.OnUseItem()
    → PlayerInventory.RequestUseItem(slotIndex=0)
      → UseItemServerRpc (클라이언트일 때) / ServerUseItem (호스트일 때)
        → 슬롯 범위 · ItemType.Active 검증
        → IItemEffect.OnActivated(_ctx)
        → [로그] "[PlayerInventory] UseItem: {name}"
```

### 현재 제약
- 슬롯 인덱스 고정값 `0` — 다중 액티브 아이템 슬롯 선택은 ITEM-04-B에서 확장.
- 쿨다운 검증 없음 — `TODO ITEM-04-B` 표시 후 ITEM-04-B에서 구현.

### InputSystem_Actions.cs 수동 수정 이유
Unity Input System의 `.inputactions` 파일 변경은 에디터에서 "Generate C# Class" 를 눌러야 자동 반영되지만, 이 프로젝트는 `.cs` 파일을 버전 관리하므로 수동으로 패턴에 맞게 추가했다.

---

## 검증 절차

1. Unity 에디터에서 Play Mode 진입 (Host 실행)
2. Player 프리팹에 `PlayerInventory` 컴포넌트가 있고 `ItemRegistry` 에셋 할당 확인
3. `ServerAddItem(itemId)` 로 `itemType = Active`인 아이템을 슬롯 0에 추가
4. F 키 누름 → Console에 `[PlayerInventory] UseItem: {아이템이름}` 로그 출력 확인
5. `itemType = Passive`인 아이템만 있을 때 F 키 → 로그 없음 (Active 아님 필터링)
6. 완료 → `feature_list.json` ITEM-04-A → `done`

---

## 주의 사항
- `InputSystem_Actions.cs`는 에디터에서 "Generate C# Class" 시 덮어써질 수 있음. 덮어써지면 UseItem 관련 코드를 재추가해야 함.
- 슬롯 인덱스 `0` 하드코딩 — ITEM-04-B 이전에는 인벤토리 첫 번째 슬롯만 사용 가능.

---

## 다음 권장 태스크
- **ITEM-04-B**: 서버 사이드 아이템 쿨다운 관리 검증 (`ServerUseItem` 내 `TODO ITEM-04-B` 활성화)
- **STATUS-01**: `StatusEffectData` SO 및 `IStatusEffectable` 인터페이스 생성
