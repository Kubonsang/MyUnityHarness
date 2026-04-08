# 32. ITEM-01-A: ItemData SO 설계 및 패시브/액티브 ItemType 분리

## 세션 목표
`ItemType` enum과 `ItemData` ScriptableObject를 신규 생성해
아이템의 패시브/액티브 분류 및 기본 스탯 구조를 정의한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Item/ItemType.cs` | **신규** — `Passive` / `Active` enum |
| `Assets/Scripts/Item/ItemData.cs` | **신규** — `itemId`, `itemType`, `allowedRoles`, `cooldown` 필드를 갖는 ScriptableObject |

---

## 핵심 설계

### ItemType

```csharp
public enum ItemType { Passive, Active }
```

- `Passive`: 장착 시 `IItemEffect.OnEquipped` 자동 발동, 쿨다운 없음
- `Active`: 플레이어 발동 시 `IItemEffect.OnActivated` 호출, `cooldown` 적용

### ItemData 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `itemId` | `int` | `ItemRegistry` 배열 인덱스와 일치 (중복 불가) |
| `itemName` | `string` | 인게임 표시 이름 |
| `itemType` | `ItemType` | Passive / Active 분류 |
| `allowedRoles` | `RoleType[]` | 비어있으면 전 직업 허용 (WeaponData와 동일 패턴) |
| `cooldown` | `float` | Active 전용. Passive는 무시 |

### 미포함 필드 (의존성 대기)

- `ItemSkillData[] skills` — SKILL-01에서 `ItemSkillData` ScriptableObject 정의 후 추가 예정. 현재 TODO 주석으로 표시.

---

## 에디터 설정

Assets 우클릭 → Create → GNF → Item Data 로 에셋 생성 가능.

---

## 검증 절차

1. Unity 에디터 재컴파일 후 오류 없음 확인.
2. Assets 우클릭 → Create → GNF → `Item Data` 메뉴 노출 확인.
3. 에셋 생성 후 Inspector에서 `itemId`, `itemType`, `allowedRoles`, `cooldown` 필드 편집 가능 확인.
4. 검증 완료 시 feature_list.json ITEM-01-A → `done`

---

## 다음 권장 태스크

- **ITEM-01-B**: `IItemEffect` 인터페이스 + `PlayerContext` 정의
