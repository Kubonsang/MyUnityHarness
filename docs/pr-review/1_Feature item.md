# PR Review: feature-ITEM → main

**브랜치**: `feature-ITEM` → `main`
**리뷰 일자**: 2026-03-17
**커밋 범위**: `e20d807` ~ `03309a8` (6 커밋)

---

## 개요

아이템 시스템 전체 구현 (ITEM-01 ~ ITEM-04):

- `IItemEffect` 파이프라인 (Passive/Active 분기)
- `ItemRegistry` ScriptableObject 기반 중앙 레지스트리
- `PlayerInventory` NetworkList 기반 서버 권위 인벤토리
- `UseItem` 입력 바인딩 + 쿨다운 시스템
- `MaxPacketQueueSize` 버그 수정 (128 → 512)

---

## 변경 파일 목록

| 파일 | 변경 유형 |
|------|-----------|
| `Assets/Scripts/Item/IItemEffect.cs` | 신규 |
| `Assets/Scripts/Item/ItemData.cs` | 신규 |
| `Assets/Scripts/Item/ItemType.cs` | 신규 |
| `Assets/Scripts/Item/ItemRegistry.cs` | 신규 |
| `Assets/Scripts/Item/NetworkItemSlot.cs` | 신규 |
| `Assets/Scripts/Item/PlayerContext.cs` | 신규 |
| `Assets/Scripts/Item/PlayerInventory.cs` | 신규 |
| `Assets/Scripts/Item/Effects/HpBonusEffect.cs` | 신규 |
| `Assets/Scripts/Item/Effects/HPBonusEffect` | 신규 (문제 파일) |
| `Assets/Scripts/Player/PlayerInputHandler.cs` | 수정 |
| `Assets/Scripts/Network/NetworkConnectionLogger.cs` | 수정 |

---

## 이슈 목록

### [CRITICAL] `HPBonusEffect` 파일에 `.cs` 확장자 없음

**파일**: `Assets/Scripts/Item/Effects/HPBonusEffect`

Unity는 이 파일을 C# 스크립트로 인식하지 않아 컴파일되지 않는다.
내용은 `HpBonusEffect.cs`의 구버전 초안으로, 메서드 본문이 모두 비어있다.

```
Assets/Scripts/Item/Effects/HPBonusEffect       ← 확장자 없음, 삭제 대상
Assets/Scripts/Item/Effects/HpBonusEffect.cs    ← 실제 구현체
```

**조치**: 해당 파일 삭제.

---

### [HIGH] `IsRoleAllowed`에서 `GetComponent` 미캐시

**파일**: `Assets/Scripts/Item/PlayerInventory.cs:218`

```csharp
private bool IsRoleAllowed(ItemData data)
{
    ...
    var modifier = GetComponent<RoleStatModifier>(); // 호출마다 탐색
    ...
}
```

`ServerAddItem`이 호출될 때마다 `GetComponent<RoleStatModifier>()`를 실행한다.
`OnNetworkSpawn`에서 `_roleModifier`로 캐시해야 한다.

**조치**: `PlayerInventory`의 `OnNetworkSpawn`에서 캐시 추가.

---

### [MEDIUM] `NetworkItemSlot.Equals`가 ItemId만 비교

**파일**: `Assets/Scripts/Item/NetworkItemSlot.cs:18`

```csharp
public bool Equals(NetworkItemSlot other) => ItemId == other.ItemId;
```

동일 아이템을 여러 개 보유할 경우, `NetworkList` 내부가 `IEquatable`을 사용하는 경로에서 첫 번째 슬롯만 식별한다.
`ServerRemoveItem`은 인덱스 기반으로 올바르게 처리하지만, 중복 아이템 정책이 명시되어 있지 않다.

**조치**: 중복 아이템 불가 정책을 코드/주석으로 명시하거나, 슬롯 고유 ID 필드 추가 고려.

---

### [MEDIUM] `OnUseItem`이 slot 0으로 하드코딩

**파일**: `Assets/Scripts/Player/PlayerInputHandler.cs:77`

```csharp
private void OnUseItem(InputAction.CallbackContext ctx) =>
    _inventory?.RequestUseItem(0); // 항상 0번 슬롯
```

멀티슬롯 인벤토리에서 1번 슬롯 이후의 아이템은 키보드 입력으로 사용할 수 없다.
`feature_list.json`에 슬롯 선택 입력 태스크가 등록되어 있지 않다면 추가 필요.

**조치**: 후속 태스크로 `feature_list.json`에 등록 후 추적.

---

### [LOW] `HpBonusEffect`가 `ApplyRoleBonus`를 재사용

**파일**: `Assets/Scripts/Item/Effects/HpBonusEffect.cs:22`

```csharp
ctx.Health.ApplyRoleBonus(_bonusHp);
```

`ApplyRoleBonus`는 직업 보너스 전용 메서드다. 아이템 효과가 동일 경로를 통하면 직업 보너스와 아이템 보너스가 혼재되어 디버깅이 어려워진다.

**조치**: 향후 `PlayerHealth.ApplyItemBonus` 분리 고려 (현재는 허용 가능).

---

### [LOW] `PlayerContext.cs` 위치

**파일**: `Assets/Scripts/Item/PlayerContext.cs`

`PlayerContext`는 Item 전용이 아닌 플레이어 전체 컴포넌트 묶음이다.
`Assets/Scripts/Player/`가 의미상 더 적합하다.

**조치**: 향후 정리 시 이동 고려 (현재는 허용 가능).

---

## 잘 된 점

- **서버 권위 설계 준수**: 모든 상태 변경은 서버에서만 처리, 클라이언트는 RPC 요청만
- **`[ServerRpc]` 기본 `RequireOwnership = true`** 활용으로 소유자 검증 자동화
- **`UseRejectedClientRpc` 패턴**: 쿨다운 거부 피드백을 오너에게만 전달하는 올바른 설계
- **`OnNetworkSpawn` 조기 반환** 패턴으로 클라이언트에서 `_ctx` 미사용 보장
- **`#if UNITY_EDITOR` Testing 블록**으로 에디터 테스트 도구 분리
- **`MaxPacketQueueSize` 수정** 위치가 적절 (`NetworkConnectionLogger.Awake`)
- **`ItemRegistry.OnEnable`에서 딕셔너리 빌드**: 런타임 조회 O(1) 보장

---

## 이슈 요약

| 심각도 | 항목 | 조치 필요 여부 |
|--------|------|----------------|
| CRITICAL | `HPBonusEffect` 확장자 없는 파일 존재 | 즉시 삭제 |
| HIGH | `IsRoleAllowed` 내 `GetComponent` 미캐시 | 수정 필요 |
| MEDIUM | `NetworkItemSlot.Equals` 중복 ItemId 처리 미명시 | 정책 명시 또는 수정 |
| MEDIUM | `OnUseItem` slot 0 하드코딩 | 후속 태스크 등록 |
| LOW | `ApplyRoleBonus` 의미 혼재 | 향후 분리 고려 |
| LOW | `PlayerContext.cs` 위치 | 향후 이동 고려 |
