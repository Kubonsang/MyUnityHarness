# 40. ITEM-06: PlayerInventory OnListChanged 구독 및 늦은 접속 초기 슬롯 처리

## 세션 목표
PR 리뷰(NGO 리뷰어)에서 지적된 `_slots.OnListChanged` 미구독 문제를 수정한다.
늦게 접속한 클라이언트가 기존 인벤토리 슬롯을 처리할 수 있도록 초기 순회 스텁을 추가하고, 향후 UI 연동 경로를 확보한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Item/PlayerInventory.cs` | `OnNetworkSpawn`에 구독 + 초기 순회 추가, `OnNetworkDespawn` 추가, `OnSlotsChanged` / `OnSlotAdded` / `OnSlotRemoved` 추가 |

---

## 핵심 설계

### 문제 (ngo-sync-debug 스킬 "late-join state gap" 버킷)
NGO `NetworkList<T>`는 늦게 접속한 클라이언트에게 전체 상태를 자동 동기화하지만, 이 초기 동기화에서는 `OnListChanged` 콜백이 **호출되지 않는다**.
따라서 `OnNetworkSpawn` 이후 수동으로 기존 슬롯을 순회해야 한다.

### 구독 구조
```
OnNetworkSpawn()
  ├─ _slots.OnListChanged += OnSlotsChanged   ← 모든 인스턴스 (서버/클라이언트 공통)
  ├─ foreach (_slots) → OnSlotAdded(slot)      ← 늦은 접속 시 기존 슬롯 처리
  └─ if (!IsServer) return
      ├─ _ownerRpcParams 초기화
      └─ _ctx 초기화

OnNetworkDespawn()
  └─ _slots.OnListChanged -= OnSlotsChanged   ← 메모리 누수 방지

OnSlotsChanged(changeEvent)
  ├─ EventType.Add      → OnSlotAdded
  └─ EventType.Remove/RemoveAt → OnSlotRemoved

OnSlotAdded / OnSlotRemoved
  └─ Debug.Log + TODO UI-01
```

### 설계 선택
- 서버/클라이언트 모두 구독: UI는 어느 쪽에서도 표시 가능
- `EventType.Remove`와 `RemoveAt` 모두 처리: NGO는 인덱스 기반(`RemoveAt`)으로 이벤트를 발행하므로 `Value`는 제거된 슬롯 값

---

## 검증 절차

1. Unity 에디터에서 Play Mode 진입 (Host 실행)
2. `ServerAddItem(itemId)` 호출 → Console에 `[PlayerInventory] 슬롯 추가 감지: itemId=X` 출력 확인
3. 두 번째 클라이언트 접속 (또는 두 번째 에디터 인스턴스)
4. 클라이언트 접속 직후 Console에 기존 슬롯 수만큼 `슬롯 추가 감지` 로그 출력 확인 (초기 순회)
5. `ServerRemoveItem(itemId)` 호출 → `슬롯 제거 감지` 로그 출력 확인
6. 완료 → `feature_list.json` ITEM-06 → `done`

---

## 주의 사항
- `OnSlotRemoved`에서 `changeEvent.Value`는 제거된 슬롯의 복사값 — NGO가 `RemoveAt` 이벤트 시에도 `Value`를 채워줌.
- `OnSlotAdded` / `OnSlotRemoved`는 현재 로그 스텁 — UI 연동 시 `TODO UI-01` 지점에 구현.
- 서버 측 초기 순회: 서버가 스폰되는 시점에 `_slots`는 비어있으므로 초기 순회가 중복 실행되지 않음.

---

## 다음 권장 태스크
- **STATUS-01**: `StatusEffectData` SO 및 `IStatusEffectable` 인터페이스 생성
