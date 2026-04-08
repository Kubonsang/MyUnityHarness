# 67. ROOM-01: RoomPreset ScriptableObject 확장 — RoomFlavor 테마 및 다중 TileType 호환

## 세션 목표
기존 RoomPreset이 단일 TileType만 지원하고 테마 구분이 없던 한계를 해소한다. RoomFlavor 테마 필드, 다중 TileType 호환 배열, 바닥/벽 장식 오버라이드 필드를 추가하고, WFCPrefabBuilder의 프리셋 조회 로직에 RoomFlavor 필터링을 연동하여 테마별 소품 배치를 지원한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/WFC/RoomPreset.cs` | `roomFlavor`(RoomFlavor) 필드 추가, `compatibleRoomTypes`(TileType[]) 다중 호환 배열 추가, `preferredFloors`(string[]) 바닥 힌트 추가, `wallFurnitureOverride`(string[]) 벽 장식 오버라이드 추가, `IsCompatibleWith(TileType)` 메서드 추가 |
| `Assets/Editor/WFCPrefabBuilder.cs` | `FindPresetsForType`에 `RoomFlavor flavorFilter` optional 파라미터 추가, 프리셋 적용 시 테마 배정 로그 출력 (`[Room] {type} → {flavor} theme`) |

---

## 핵심 설계

### RoomPreset 필드 구조
```
RoomPreset (ScriptableObject)
├── roomFlavor : RoomFlavor      ← 테마 (Tile.cs의 10종 enum 참조)
├── compatibleRoomTypes : TileType[]  ← 이 프리셋이 적용 가능한 방 종류 목록
├── preferredFloors : string[]   ← 테마에 어울리는 바닥 모델 (빈 배열이면 기본 풀 사용)
├── props : List<PropEntry>      ← 기존 소품 배치 리스트 (유지)
└── wallFurnitureOverride : string[]  ← 벽 붙박이 가구 오버라이드 (빈 배열이면 기본 풀 사용)
```

### IsCompatibleWith(TileType) 메서드
- `compatibleRoomTypes` 배열을 순회하여 주어진 TileType과 일치하는 항목이 있으면 `true` 반환
- 배열이 null이거나 비어 있으면 `false` 반환 (안전 폴백)
- LINQ 미사용 — `for` 루프로 구현하여 핫 패스 안전

### FindPresetsForType 필터링 흐름
```
FindPresetsForType(TileType type, RoomFlavor flavorFilter = None)
  → Assets/WFC/RoomPresets/ 폴더에서 모든 RoomPreset 에셋 로드
  → preset.IsCompatibleWith(type) 실패 시 제외
  → flavorFilter != None && preset.roomFlavor != flavorFilter 시 제외
  → 통과한 프리셋 리스트 반환
  → 호출부에서 여러 개면 랜덤 선택, 테마 로그 출력
```

### RoomFlavor enum (기존 Tile.cs에 정의, 10종)
- SpecialRoom 분위기: Treasure, Merchant, MagicStudy
- ObjectiveRoom 분위기: Prison, RitualRoom, Library
- NormalRoom 분위기: Barracks, Ruins, Storage
- Corridor 분위기: Waterway

---

## 검증 절차

1. QA 정적 분석 PASS — enum 참조 정상, 시그니처 호환, Assembly 방향 정상
2. `IsCompatibleWith` 로직 — null/빈 배열 안전 처리 확인
3. `FindPresetsForType` — `Assets/WFC/RoomPresets/` 폴더 미존재 시 빈 리스트 반환 (기존 동작 유지)
4. 완료 → feature_list.json ROOM-01 → `done`

---

## 주의 사항
- `preferredFloors`와 `wallFurnitureOverride`는 필드만 추가된 상태이며, WFCPrefabBuilder의 `AttachMacroModels`에서 실제로 이 필드를 참조하는 로직은 아직 미구현 (향후 태스크에서 연동 필요)
- ScriptableObject는 런타임 쓰기 금지 원칙(so-readonly) 준수 — 모든 필드가 에디터 전용 고정 데이터
- `compatibleRoomTypes` 배열이 비어 있으면 `IsCompatibleWith`가 항상 false를 반환하므로, 프리셋 생성 시 반드시 1개 이상의 TileType을 지정해야 함

---

## 다음 권장 태스크
- **ROOM-02 (예정)**: `preferredFloors` / `wallFurnitureOverride` 필드를 WFCPrefabBuilder의 AttachMacroModels에 실제 연동
- **WFC 테마 프리셋 에셋 생성**: 각 RoomFlavor별 RoomPreset .asset 파일 제작 (Treasure, Prison 등)
- **NET 연동**: 런타임 시 방 테마 정보를 NetworkVariable로 동기화하여 클라이언트 비주얼 일치
