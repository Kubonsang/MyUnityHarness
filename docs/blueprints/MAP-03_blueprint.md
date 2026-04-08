# MAP-03 룸 내부 장식 통합 — 구현 설계도

> 작성일: 2026-04-07
> 선행 태스크: MAP-01 (DungeonLayout 데이터), MAP-02 (CorridorBuilder, corridorWallSides 채움)
> 스코프: Delaunay 배치된 각 RoomNode에 룸 셸(바닥+벽+천장+doorway 아치) 조립 + RoomPreset/propPool 소품 배치
> 후행 태스크: ROOM-05 (NavMesh 호환성 검증)

---

## 1. 신규/수정 파일 목록

| 파일 경로 | 클래스 | 역할 | 신규/수정 |
|-----------|--------|------|-----------|
| `Assets/Scripts/Map/Dungeon/RoomBuilder.cs` | `RoomBuilder : MonoBehaviour` | MAP-03 메인 — RoomNode[] 입력, 룸 셸+소품 전체 조립 | **신규** |
| `Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs` | `DungeonLayoutGenerator` | `BuildDungeon()`에 `RoomBuilder.BuildRooms()` 호출 연결 | **수정 (최소)** |

> **WFCGenerator.cs, WFCPrefabBuilder.cs는 수정하지 않는다.** RoomBuilder는 Delaunay 시스템 전용 독립 컴포넌트다.
> RoomNode.corridorWallSides는 MAP-02의 CorridorBuilder가 채운다 — RoomBuilder는 읽기만 한다.

---

## 2. 아키텍처 개요 — MAP-01 → MAP-02 → MAP-03 파이프라인

```
DungeonLayoutGenerator.BuildDungeon()
        │
        ├── BakeLayout()
        │       └─→ DungeonLayout { rooms[], corridors[] }
        │
        ├── CorridorBuilder.BuildCorridors(layout, corridorContainer)   [MAP-02]
        │       └─→ RoomNode.corridorWallSides 채움 (RegisterDoorwaySides)
        │
        └── RoomBuilder.BuildRooms(layout, roomContainer)               [MAP-03]
                │
                ├── Phase 1: 각 RoomNode 순회
                │       └─→ BuildRoomGeometry(room, parent)
                │               ├── 바닥+천장 타일 그리드
                │               ├── 4면 외벽 조립 (BuildMacroWall)
                │               │       └─→ corridorWallSides 면 → Entrance 처리
                │               ├── 모서리 기둥
                │               ├── 벽 붙박이 가구 (doorway 없는 면만)
                │               └── 소품 배치 (PlaceInteriorProps)
                │
                └── Phase 2: 소품 배치
                        ├── FindPresetsForType() → RoomPreset 우선
                        └── propPool 랜덤 배치 (프리셋 없을 때 폴백)
```

### 레이어 분리 원칙

| 레이어 | 담당 클래스 | 역할 |
|--------|-------------|------|
| 매크로 레이아웃 | `DungeonLayoutGenerator` | RoomNode 배치, Delaunay 그래프 |
| 복도 | `CorridorBuilder` | 복도 지오메트리, doorway 정보 기록 |
| 룸 셸+인테리어 | `RoomBuilder` (MAP-03 신규) | 룸 바닥/벽/천장/소품 조립 |

---

## 3. 핵심 설계 결정

### 3.1 RoomBuilder 신규 클래스 vs WFCPrefabBuilder 재사용

**결론: RoomBuilder 신규 클래스 작성.**

| 항목 | WFCPrefabBuilder 재사용 | RoomBuilder 신규 |
|------|------------------------|-----------------|
| 런타임 실행 | `#if UNITY_EDITOR`로 감싸져 있어 런타임 불가 | `MonoBehaviour`로 런타임 빌드 가능 |
| 입력 데이터 | WFC 소켓 기반 (nW/eW/sW/wW 불리언) | RoomNode.corridorWallSides HashSet |
| 룸 크기 | roomScale(타일 수) 정수 파라미터 | RoomNode.size(미터) 직접 사용 |
| 에셋 로드 | `AssetDatabase.LoadAssetAtPath` (Editor only) | `PrefabUtility` / Resources 듀얼 분기 유지 |
| 메서드 가시성 | `static` — 외부에서 호출 불가 | `public` MonoBehaviour — Inspector 노출, 컴포넌트 참조 가능 |

WFCPrefabBuilder의 핵심 알고리즘(벽 반복, doorway 아치, 소품 거리 검사)은 **동일한 수치와 로직을 RoomBuilder에 복제**한다. 단, `AssetDatabase` / `PrefabUtility` 의존성은 `#if UNITY_EDITOR` 분기를 유지하여 빌드 호환성을 확보한다.

### 3.2 RoomNode.corridorWallSides를 이용한 doorway 벽 처리

MAP-02 `CorridorBuilder.RegisterDoorwaySides()`가 이미 각 RoomNode의 `corridorWallSides` HashSet에 복도가 연결되는 벽면 인덱스(0=N, 1=E, 2=S, 3=W)를 기록한다.

RoomBuilder는 4면 벽을 조립할 때 다음 분기를 사용한다:

```csharp
bool isEntrance = room.corridorWallSides.Contains(wallSide);
// isEntrance == true  → PlaceEntranceArch() (wall_doorway.fbx + solid wall 양측)
// isEntrance == false → BuildMacroWallSolid() (랜덤 변형 벽 + 장식)
```

WFCPrefabBuilder의 `BuildMacroWall(pivot, pos, roty, isWallFull, ...)` 패턴을 그대로 채택한다.

### 3.3 FindPresetsForType() 재사용 방법

WFCPrefabBuilder의 `FindPresetsForType()`은 `static` Editor 메서드라 직접 호출 불가. RoomBuilder에 **동일 로직을 인스턴스 메서드로 복제**한다:

```csharp
private List<RoomPreset> FindPresetsForType(TileType type)
{
    // AssetDatabase.FindAssets("t:RoomPreset", "Assets/WFC/RoomPresets") 동일 로직
    // #if UNITY_EDITOR 블록 내부에서만 실행
}
```

런타임(빌드)에서는 `Resources.LoadAll<RoomPreset>("WFC/RoomPresets")` 폴백 경로를 사용한다.

### 3.4 RoomFlavor 할당 로직

RoomNode에는 `roomFlavor = RoomFlavor.None` 이 기본값이다. RoomBuilder는 Bake 시 다음 규칙으로 테마를 배정한다:

1. `RoomPreset`을 조회해 해당 TileType에 호환되는 후보군을 수집.
2. 후보군이 1개 이상이면 `Random.Range`로 하나를 선택.
3. 선택된 프리셋의 `roomFlavor`를 `RoomNode.roomFlavor`에 기록.
4. 로그: `Debug.Log($"[Room] {type} {room.id} → {preset.roomFlavor} theme (preset: {preset.name})")`.
5. 후보군이 없으면 propPool 랜덤 배치로 폴백 (로그: `[Room] {type} {room.id} → default propPool`).

### 3.5 룸 셸 크기 계산

WFCPrefabBuilder는 `roomScale`(타일 수 정수)를 사용한다. RoomBuilder는 `RoomNode.size`(미터)로부터 roomScale을 역산한다:

```
largeRoom(40×40m): roomScale = 40 / 4 = 10 → half = 5
smallRoom(24×24m): roomScale = 24 / 4 =  6 → half = 3
일반식: half = Mathf.RoundToInt(room.size.x / 2f / TILE_SIZE)
```

`wallDist = half * TILE_SIZE + 1.5f` (WFCPrefabBuilder 동일)
- largeRoom: 5 * 4 + 1.5 = 21.5m
- smallRoom:  3 * 4 + 1.5 = 13.5m

---

## 4. 주요 메서드 시그니처

```csharp
// ── 메인 진입점 ────────────────────────────────────────────────────
/// <summary>
/// DungeonLayout의 모든 RoomNode에 대해 룸 셸+소품을 생성한다.
/// DungeonLayoutGenerator.BuildDungeon()에서 CorridorBuilder 이후 호출.
/// </summary>
public void BuildRooms(DungeonLayout layout, Transform container);

// ── 룸 단위 조립 ───────────────────────────────────────────────────
/// <summary>
/// 단일 RoomNode에 대한 바닥+벽+천장+doorway+소품 전체 조립.
/// </summary>
private void BuildRoomGeometry(RoomNode room, Transform parent);

// ── 바닥/천장 그리드 ───────────────────────────────────────────────
/// <summary>
/// half × half 그리드로 바닥과 천장 타일을 배치한다.
/// </summary>
private void PlaceFloorAndCeiling(Transform parent, Vector3 roomCenter,
    int half, string[] floorPool);

// ── 외벽 한 면 조립 ────────────────────────────────────────────────
/// <summary>
/// 하나의 벽면(side 0~3)을 조립한다.
/// corridorWallSides에 포함된 면은 Entrance 처리, 아니면 solid 벽.
/// </summary>
/// <param name="wallSide">0=N, 1=E, 2=S, 3=W</param>
/// <param name="tier">0=하단, 1=상단 (상단은 항상 solid)</param>
private void BuildRoomWall(Transform parent, RoomNode room, int wallSide,
    int tier, string wallModel);

// ── Entrance 아치 배치 ─────────────────────────────────────────────
/// <summary>
/// Entrance 면에 wall_doorway.fbx(중앙) + 양측 solid wall 배치.
/// WFCPrefabBuilder.PlaceEntranceArch()와 동일 로직.
/// </summary>
private void PlaceEntranceArch(Transform parent, Vector3 wallCenterPos,
    float rotY, string wallModel, int half);

// ── 소품 배치 오케스트레이션 ───────────────────────────────────────
/// <summary>
/// RoomPreset 우선, 없으면 propPool 랜덤 배치.
/// room.roomFlavor에 배정된 테마를 기록한다.
/// </summary>
private void PlaceInteriorProps(Transform parent, RoomNode room,
    Vector3 roomCenter, float wallDist);

// ── RoomPreset 조회 (Editor/Runtime 듀얼) ──────────────────────────
private List<RoomPreset> FindPresetsForType(TileType type);

// ── propPool 랜덤 배치 ─────────────────────────────────────────────
/// <summary>
/// WFCPrefabBuilder의 랜덤 배치 로직과 동일.
/// 소품 간 MIN_DIST_SQ(1.5m²) 검사, 탁상 소품 후처리 포함.
/// </summary>
private void PlaceRandomProps(Transform parent, Vector3 roomCenter,
    string[] propPool, float wallDist);

// ── 에셋 배치 헬퍼 ────────────────────────────────────────────────
private GameObject PlaceModel(string modelName, Transform parent,
    Vector3 localPos, float rotY);
```

---

## 5. BuildRoomGeometry 핵심 흐름

```
BuildRoomGeometry(RoomNode room, Transform parent)
│
├── 1. 수치 계산
│       half     = RoundToInt(room.size.x / 2 / TILE_SIZE)
│       wallDist = half * TILE_SIZE + 1.5f
│       roomCenter = new Vector3(room.center.x, 0, room.center.y)
│
├── 2. PlaceFloorAndCeiling
│       for x in [-half .. half]
│         for z in [-half .. half]
│           PlaceModel(floorPool[random], parent, roomCenter + (x*4, 0, z*4), 0)
│           PlaceModel("ceiling_tile.fbx", parent, roomCenter + (x*4, CEIL_Y, z*4), 0)
│
├── 3. 4면 외벽 2단 조립
│       for tier in [0, 1]
│         for wallSide in [0, 1, 2, 3]  (N, E, S, W)
│           bool isEntrance = room.corridorWallSides.Contains(wallSide)
│           bool forceWall  = (tier > 0)  // 상단은 항상 solid
│           if (isEntrance && !forceWall)
│             PlaceEntranceArch(...)
│           else
│             BuildMacroWallSolid(...)  // 랜덤 변형 + 장식
│
├── 4. 모서리 기둥
│       cd = wallDist - 1.25f
│       for tier in [0, 1]
│         PlaceModel("pillar.fbx", ...) × 4 모서리
│
├── 5. 벽 붙박이 가구 (doorway 없는 면만)
│       PlaceWallFurniture(parent, roomCenter, wallDist, half,
│                          room.corridorWallSides)
│
└── 6. 소품 배치
        PlaceInteriorProps(parent, room, roomCenter, wallDist)
```

### 벽면 좌표 매핑

```
wallSide  위치 오프셋               rotY
  0 (N)   roomCenter + (0, wy,  wallDist)   180°
  1 (E)   roomCenter + ( wallDist, wy, 0)   -90°
  2 (S)   roomCenter + (0, wy, -wallDist)     0°
  3 (W)   roomCenter + (-wallDist, wy, 0)   90°
```

---

## 6. Inspector 노출 파라미터

```csharp
public class RoomBuilder : MonoBehaviour
{
    [Header("Asset Path")]
    public string assetBasePath =
        "Assets/KayKit_DungeonRemastered_1.1_SOURCE/Assets/fbx(unity)/";

    [Header("Wall Model")]
    public string defaultWallModel  = "wall.fbx";
    public string[] wallVariations  = { "wall_arched.fbx", "wall_cracked.fbx" };

    [Header("Floor Pools")]
    public string[] dirtFloors      = { "floor_dirt_large.fbx", "floor_dirt_large_rocky.fbx" };
    public string[] stoneFloors     = { "floor_tile_large.fbx" };
    public string[] woodFloors      = { "floor_wood_large.fbx", "floor_wood_large_dark.fbx" };
    public string[] niceFloors      = { "floor_tile_large.fbx" };
    public string[] rockyFloors     = { "floor_tile_large.fbx", "floor_tile_large_rocks.fbx" };

    [Header("Prop Pools (Fallback)")]
    public string[] normalRoomProps   = { /* WFCPrefabBuilder 동일 목록 */ };
    public string[] specialRoomProps  = { /* ... */ };
    public string[] startRoomProps    = { /* ... */ };
    public string[] exitRoomProps     = { /* ... */ };
    public string[] objectiveRoomProps= { /* ... */ };

    [Header("Decoration")]
    public string[] wallDecoInset     = { "wall_inset_candles.fbx", "wall_inset_shelves.fbx",
                                          "wall_inset_shelves_decoratedA.fbx", "wall_inset_shelves_decoratedB.fbx" };
    public string[] wallFurniture     = { "bookcase_single_decoratedA.fbx", /* ... */ };
    public string[] tableOnlyItems    = { "book_brown.fbx", /* ... */ };
    public string[] bannerSmall       = { "banner_blue.fbx", /* ... */ };

    [Header("Torch Light")]
    public float torchRange     = 12f;
    public float torchIntensity = 4f;
    public Color torchColor     = new Color(1f, 0.6f, 0.2f);

    [Header("Debug")]
    public bool drawGizmos = true;
}
```

---

## 7. WFCPrefabBuilder 재사용 vs 독립 구현 분석

| 메서드/로직 | WFCPrefabBuilder | RoomBuilder 처리 |
|-------------|-----------------|-----------------|
| `PlaceModel` | Editor only (`AssetDatabase`) | **복제** — `#if UNITY_EDITOR` 분기 동일하게 유지 |
| `BuildMacroWall` | `static`, roomScale 정수 입력 | **복제+변환** — `half` 파라미터로 대체, 인스턴스 메서드 |
| `PlaceEntranceArch` | static, `roomScale` 기반 루프 | **복제** — `half` 파라미터로 대체 |
| `PlaceWallDecorated` | static, 동일 확률 테이블 | **복제** — 동일 로직 유지 |
| `PlaceWallFurniture` | static, nW/eW/sW/wW 불리언 | **변환** — `corridorWallSides` HashSet으로 입력 변경 |
| `FindPresetsForType` | static Editor-only | **복제** — 인스턴스 메서드, `#if UNITY_EDITOR` + Runtime 분기 추가 |
| 소품 랜덤 배치 | `placed` 리스트, MIN_DIST_SQ 검사 | **복제** — 동일 알고리즘 |
| `AttachMacroModels` (오케스트레이터) | static | **대체** → `BuildRoomGeometry()`가 동일 역할 수행 |

**복제하는 이유:** WFCPrefabBuilder는 `#if UNITY_EDITOR`로 전체가 감싸져 있고, static 메서드 설계상 MonoBehaviour 컨텍스트에서 직접 호출이 불가능하다. 로직 자체는 동일하되, 호출 방식과 입력 타입만 변환한다.

---

## 8. DungeonLayoutGenerator 수정 내용

`BuildDungeon()` 메서드에 `RoomBuilder.BuildRooms()` 호출을 추가한다.

```csharp
[Header("Room Builder")]
[Tooltip("RoomBuilder 참조 (같은 GameObject 또는 자식)")]
public RoomBuilder roomBuilder;

[Tooltip("레이아웃 생성 후 룸 자동 빌드")]
public bool autoBuildRooms = true;

[ContextMenu("Build Dungeon (Layout + Corridors + Rooms)")]
public DungeonLayout BuildDungeon()
{
    DungeonLayout layout = BakeLayout();

    if (layout != null && autoBuildCorridors && corridorBuilder != null)
    {
        var existing = transform.Find("Generated_Dungeon_Corridors");
        if (existing != null) DestroyImmediate(existing.gameObject);

        var corridorContainer = new GameObject("Generated_Dungeon_Corridors");
        corridorContainer.transform.SetParent(transform);
        corridorBuilder.BuildCorridors(layout, corridorContainer.transform);
    }

    // MAP-03: 룸 셸+소품 빌드 (corridorWallSides가 채워진 이후)
    if (layout != null && autoBuildRooms && roomBuilder != null)
    {
        var existingRooms = transform.Find("Generated_Dungeon_Rooms");
        if (existingRooms != null) DestroyImmediate(existingRooms.gameObject);

        var roomContainer = new GameObject("Generated_Dungeon_Rooms");
        roomContainer.transform.SetParent(transform);
        roomBuilder.BuildRooms(layout, roomContainer.transform);  // MAP-03
    }

    return layout;
}
```

**핵심 순서 보장:** `BuildCorridors`가 `RegisterDoorwaySides`를 통해 `corridorWallSides`를 채운 뒤 `BuildRooms`가 호출되므로, RoomBuilder는 항상 완전한 doorway 정보를 읽는다.

---

## 9. 구현 순서 (Step 1~6)

### Step 1 — RoomBuilder 스켈레톤 생성
- `Assets/Scripts/Map/Dungeon/RoomBuilder.cs` 신규 생성
- `MonoBehaviour` 상속, Inspector 헤더/파라미터 선언
- `BuildRooms(DungeonLayout layout, Transform container)` 빈 메서드 작성

### Step 2 — PlaceModel 헬퍼 구현
- WFCPrefabBuilder의 `PlaceModel` 로직 복제
- `#if UNITY_EDITOR`: `AssetDatabase.LoadAssetAtPath` + `PrefabUtility.InstantiatePrefab`
- `#else`: `Resources.Load<GameObject>` + `Instantiate`

### Step 3 — 바닥/천장/벽 조립 메서드 구현
- `PlaceFloorAndCeiling` — half × half 그리드
- `BuildRoomWall` — tier/wallSide 루프, `corridorWallSides` 분기
- `PlaceEntranceArch` — wall_doorway.fbx 중앙 + solid wall 양측
- `PlaceWallFurniture` — corridorWallSides 없는 면만

### Step 4 — BuildRoomGeometry 조립
- Step 2~3 메서드를 순서에 따라 호출하는 오케스트레이터 작성
- 수치 계산(half, wallDist) 로직 구현
- TileType별 floorPool 선택 로직 구현

### Step 5 — 소품 배치 구현
- `FindPresetsForType` — Editor/Runtime 듀얼 구현
- `PlaceInteriorProps` — 프리셋 우선, `propPool` 폴백
- `PlaceRandomProps` — MIN_DIST_SQ 검사, 탁상 소품 후처리
- `room.roomFlavor` 기록 및 `[Room]` 로그 출력

### Step 6 — DungeonLayoutGenerator 연결 및 검증
- `DungeonLayoutGenerator.cs`에 `roomBuilder` 필드, `autoBuildRooms` 플래그 추가
- `BuildDungeon()`에 `BuildRooms()` 호출 블록 추가 (corridors 이후)
- Unity Editor에서 `DungeonLayoutGenerator` Inspector에 `RoomBuilder` 컴포넌트 할당
- Bake 3회 실행 → 모든 룸 소품 배치 확인 → `[Room]` 로그 출력 확인

---

## 10. 검증 기준 (Verification)

| 기준 | 확인 방법 |
|------|-----------|
| 모든 룸 내부에 소품 배치됨 | Bake 3회 실행 후 Scene Hierarchy에서 `Generated_Dungeon_Rooms` 자식 확인 |
| 동일 TileType이라도 테마 다양성 | 3회 Bake 결과에서 NormalRoom 중 서로 다른 roomFlavor 확인 |
| `[Room]` 로그 출력 | Console에 `[Room] NormalRoom 2 → Barracks theme (preset: Preset_Barracks)` 형식 확인 |
| doorway 면 처리 정확도 | corridorWallSides 면에 wall_doorway.fbx, 나머지 면에 solid wall 배치 확인 |
| 컴파일 에러 없음 | Unity Editor 스크립트 컴파일 성공 |

---

## 11. 위험 요소 및 주의 사항

| 위험 | 완화 방법 |
|------|-----------|
| `corridorWallSides`가 비어 있을 때 호출 | `BuildDungeon()`에서 `BuildCorridors` 이후 호출 순서 강제 |
| 룸 셸과 복도 doorway 위치 불일치 | CorridorBuilder의 `PlaceDoorway`와 동일한 좌표 공식 사용 |
| `FindPresetsForType`이 Editor에서만 동작 | Runtime 폴백(`Resources.LoadAll`) 분기 필수 구현 |
| 소품이 벽을 뚫거나 doorway를 막음 | `range = wallDist - 4f` 여유 적용, MIN_DIST_SQ 검사 유지 |
| RoomNode.roomFlavor 기록이 `[NonSerialized]` 밖 | `DungeonLayoutData.cs`의 `roomFlavor`는 직렬화됨 — 런타임 수정 허용 |
| SO 런타임 쓰기 금지 규칙 | `RoomPreset` ScriptableObject는 읽기만 함 — room.roomFlavor(RoomNode 필드)에만 씀 |
