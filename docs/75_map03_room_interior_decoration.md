# 75. MAP-03: 룸 내부 장식 통합 (RoomBuilder)

## 세션 목표
배치된 각 룸 프리팹 내부를 RoomPreset 프리셋 또는 propPool 소품으로 장식한다. 룸 매크로 레이아웃(MAP-01/02)과 룸 인테리어(WFC/프리셋)를 분리하여, 룸 셸은 MAP이 배치하고 내부 소품은 기존 시스템이 담당하도록 연결한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/Dungeon/RoomBuilder.cs` | **신규** — MonoBehaviour. 룸 셸(바닥+벽+천장+doorway 아치) + RoomPreset/propPool 소품 배치. `corridorWallSides` 정보를 참조하여 doorway 벽면에는 solid 벽 대신 아치를 배치 |
| `Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs` | **수정** — `roomBuilder` 참조 필드 추가, `autoBuildRooms` 플래그 추가, `BuildDungeon()` 파이프라인에 `BuildRooms()` 호출 추가(BakeLayout → BuildCorridors → BuildRooms 순서 보장) |
| `Assets/Tests/PlayMode/MAP03_Tests.cs` | **신규** — 13개 PlayMode 테스트 |

---

## 핵심 설계

### WFCPrefabBuilder 재사용 불가 사유
`WFCPrefabBuilder`는 `#if UNITY_EDITOR` 가드와 `static` 메서드 구조로 인해 PlayMode 테스트 및 Runtime 환경에서 직접 재사용이 불가능하다. 동일한 `PlaceModel` 알고리즘(Editor: `AssetDatabase.LoadAssetAtPath` + `PrefabUtility.InstantiatePrefab` / Runtime: `Resources.Load` + `Instantiate`)을 `RoomBuilder`에 복제하여 Editor/Runtime 듀얼 지원을 구현했다.

### 4면 외벽 조립 로직
각 룸의 4면 벽(N/E/S/W)을 순회할 때 `room.corridorWallSides.Contains(wallSide)` 분기로 배치 방식을 결정한다.

| 조건 | 배치 방식 |
|------|-----------|
| `corridorWallSides`에 포함 | doorway 아치(`wall_doorway.fbx` 하단 + `wall.fbx` 상단) |
| 미포함 | solid 벽 전체 2단 배치 |

### 소품 배치 전략
`RoomPreset` 우선 → `propPool` 폴백 순서로 소품을 선택한다. 동일 `TileType` 룸이라도 RoomPreset에 복수의 테마가 등록되어 있으면 랜덤으로 다른 테마 조합이 선택된다.

### MAP 파이프라인 순서 보장
```
DungeonLayoutGenerator.BuildDungeon()
  └→ BakeLayout()         → DungeonLayout (rooms + corridors)
  └→ BuildCorridors()     → corridorWallSides 채움 (Phase 2에서 집계)
  └→ BuildRooms()         → corridorWallSides 읽어 doorway/solid 결정 후 룸 셸+소품 배치
```
`BuildCorridors()` 완료 후에만 `corridorWallSides`가 채워지므로, `BuildRooms()`는 반드시 `BuildCorridors()` 이후에 실행되어야 한다.

### 배치 로그
각 룸 배치 시 `Debug.Log($"[Room] {roomType} → {themeName} theme")` 형식으로 배정 로그를 출력한다. (예: `[Room] NormalRoom → Barracks theme`)

---

## testplay 검증
- **실행 명령어**: `testplay run --shadow --filter MAP03_Tests`
- **실행 결과**: 통과 (Exit 0), 13/13 PASS
- **검증 내용**:
  - `BuildRooms()` 실행 후 모든 룸에 소품이 최소 1개 이상 배치됨 확인
  - `corridorWallSides`에 등록된 벽면에는 doorway 아치가, 미등록 벽면에는 solid 벽이 배치됨 확인
  - 동일 `TileType` 룸 2개를 Bake할 때 서로 다른 테마 소품 조합이 선택될 수 있음 확인
  - RoomPreset이 없는 룸에서 propPool 폴백으로 소품이 배치됨 확인
  - `PlaceModel`이 Editor 환경(AssetDatabase)과 Runtime 환경(Resources.Load) 양쪽에서 정상 동작 확인
  - `BuildDungeon()` 파이프라인 순서(BakeLayout → BuildCorridors → BuildRooms)가 보장됨 확인
  - Console에 `[Room] NormalRoom → Barracks theme` 형식의 배정 로그 출력 확인
  - Bake 3회 실행 시 모든 룸 내부에 소품이 배치됨 확인

---

## 검증 절차

1. Scene의 `DungeonLayoutGenerator` 오브젝트에 `RoomBuilder` 컴포넌트 추가, Inspector에서 `roomBuilder` 참조 연결
2. `autoBuildRooms = true` 설정
3. Component 우클릭 → `Build Dungeon` 실행 (BakeLayout → BuildCorridors → BuildRooms 순서 자동 실행)
4. Scene View에서 각 룸 내부 확인:
   - (1) 모든 룸에 바닥·4면 벽·천장 존재
   - (2) 복도 연결 벽면에 doorway 아치, 나머지 벽면에 solid 벽 배치
   - (3) 룸 내부에 소품(barrel, crate 등) 또는 RoomPreset 테마 소품 배치
5. Bake 3회 반복 실행 후 동일 TileType 룸에서 서로 다른 테마 소품 조합 등장 여부 확인
6. Console에서 `[Room] NormalRoom → Barracks theme` 형식의 배정 로그 확인
7. 확인 완료 → feature_list.json MAP-03 → `done`

---

## 주의 사항
- `RoomBuilder.PlaceModel()`은 Editor에서는 `AssetDatabase`/`PrefabUtility`를 사용하고, Runtime에서는 `Resources.Load`를 사용한다. KayKit 에셋이 `assetBasePath`에 존재해야 정상 동작한다
- `RoomNode.corridorWallSides`는 `[System.NonSerialized]`이므로 직렬화되지 않는다. `BuildCorridors()` 호출 없이 `BuildRooms()`만 단독 실행하면 모든 벽면이 solid로 배치된다
- `WFCPrefabBuilder`의 `PlaceModel` 로직을 복제했으므로, 원본 변경 시 `RoomBuilder`에도 동일 변경을 반영해야 한다 (동기화 부채)
- 소품 배치에 `Random.Range`를 사용하므로 매 실행마다 배치가 달라진다. 시드 제어가 필요하면 `System.Random` 인스턴스 도입 필요

---

## 다음 권장 태스크
- **ROOM-05**: NavMesh 호환성 검증 — RoomBuilder로 배치된 소품 및 셸 지오메트리가 NavMesh Bake 결과에 정상 반영되는지 확인
