# 37. ITEM-04-B: 서버 사이드 아이템 쿨다운 관리 검증

## 세션 목표
서버에서 액티브 아이템 재사용을 `ItemData.cooldown` 초 동안 거부하고, 거부 사실을 오너 클라이언트에 ClientRpc로 알리는 체계 구현.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Item/PlayerInventory.cs` | `using System.Collections.Generic` 추가, `_cooldownEndTimes` 필드 추가, `ServerUseItem` 쿨다운 검증 활성화, `UseRejectedClientRpc` 추가 |

---

## 핵심 설계

### 쿨다운 메커니즘
- **저장**: `Dictionary<int, float> _cooldownEndTimes` — key=itemId, value=`Time.time + data.cooldown`
- **검증**: 사용 시도 시 `Time.time < endTime` 이면 거부
- **Update() 없음**: 타임스탬프 비교 방식 — 별도 틱 비용 제로

### 클라이언트 알림
쿨다운 거부 시 오너 클라이언트에만 `UseRejectedClientRpc` 전송 → 콘솔 로그 출력.
현재는 UI 표시 없음 (STATUS/SKILL 이후 확장 가능).

### 플로우
```
UseItemServerRpc(slotIndex)
  → ServerUseItem(slotIndex)
    ① 슬롯 범위 · ItemType.Active 검증
    ② _cooldownEndTimes[itemId] 조회
       쿨다운 중 → UseRejectedClientRpc(오너에게만) → return
       쿨다운 아님 → _cooldownEndTimes[itemId] = Time.time + cooldown
                  → IItemEffect.OnActivated(_ctx)
```

### 설계 선택 이유
- 청사진(`docs/blueprints/ITEM.md`)에 명시: "서버 로컬 Dictionary, NetworkVariable 불필요"
- `Time.time` 기반 타임스탬프: Update() 핫패스 없음, 메모리 효율적

---

## 검증 절차

1. Unity 에디터에서 Play Mode 진입 (Host 실행)
2. `ItemData.itemType = Active`, `ItemData.cooldown = 5f` 인 아이템을 슬롯 0에 추가 (`ServerAddItem`)
3. F 키 → Console: `[PlayerInventory] UseItem: {이름} (cooldown=5s)` 출력 확인
4. 5초 이내 F 키 재입력 → Console: `[PlayerInventory] 쿨다운 중 — {이름} (남은 Xs)` 출력 확인
5. 5초 후 F 키 → 다시 UseItem 로그 출력 (쿨다운 만료 정상 사용)
6. 완료 → `feature_list.json` ITEM-04-B → `done`

---

## 주의 사항
- `_cooldownEndTimes`는 서버 전용 — `OnNetworkDespawn` 시 자동 소멸 (명시적 Clear 불필요).
- 쿨다운 상태가 클라이언트에 동기화되지 않으므로 UI 쿨다운 게이지 구현 시 별도 채널 필요 (현재 범위 외).

---

## 다음 권장 태스크
- **STATUS-01**: `StatusEffectData` SO 및 `IStatusEffectable` 인터페이스 생성
