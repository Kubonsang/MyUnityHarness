
# MAP-02 복도 지오메트리 생성기 — 구현 설계도

> 작성일: 2026-04-07
> 선행 태스크: MAP-01 (DungeonLayout 데이터)
> 스코프: CorridorEdge 데이터로부터 3D 복도 지오메트리(바닥/벽/천장/doorway) 빌드
> 후행 태스크: MAP-03 (룸 내부 장식)

---

## 1. 신규/수정 파일 목록

| 파일 경로 | 클래스 | 역할 | 신규/수정 |
|-----------|--------|------|-----------|
| `Assets/Scripts/Map/Dungeon/CorridorBuilder.cs` | `CorridorBuilder : MonoBehaviour` | 메인 복도 생성기 — DungeonLayout 입력, 3D 복도 조립 전체 오케스트레이션 | **신규** |
| `Assets/Scripts/Map/Dungeon/CorridorSegment.cs` | `CorridorSegment` (순수 데이터) | 복도 세그먼트 계산 결과 (시작점, 끝점, 방향, 길이, 타입) | **신규** |
| `Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs` | `CorridorEdge` | `wallSideA`, `wallSideB` 필드 추가 (룸 벽면 방향 정보) | **수정** |
| `Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs` | `DungeonLayoutGenerator` | `BakeLayout()` 호출 후 `CorridorBuilder.BuildCorridors()` 연계 지점 추가 | **수정 (최소)** |

> **WFCGenerator.cs, WFCPrefabBuilder.cs는 수정하지 않는다.** 신규 시스템은 기존 WFC 시스템과 독립적으로 병존한다.

---

## 2. 아키텍처 개요

```
DungeonLayoutGenerator.BakeLayout()
        │
        ▼
   DungeonLayout { rooms[], corridors[] }
        │
        ▼
CorridorBuilder.BuildCorridors(layout, container)
        │
        ├── Phase 1: 복도 세그먼트 계산 (경로/방향 결정)
        ├── Phase 2: 룸 벽면 doorway 뚫기 (wall_doorway.fbx 배치)
        ├── Phase 3: 복도 지오메트리 조립 (바닥/벽/천장 타일 반복)
        └── Phase 4: 복도 소품 배치 (torch, barrel 등)
```

---

## 3. 핵심 데이터 구조

### 3.1 CorridorSegment (신규)

```csharp
public enum CorridorPathType
{
    Straight,   // 직선: 두 룸이 X축 또는 Z축에 정렬
    LShaped     // L자형: 꺾임점 1개
}

[System.Serializable]
public class CorridorSegment
{
    public Vector3 start;         // 세그먼트 시작점 (월드 XZ, Y=0)
    public Vector3 end;           // 세그먼트 끝점
    public Vector3 direction;     // 정규화된 진행 방향
    public float   length;        // 세그먼트 길이 (미터)
    public int     tileCount;     // 이 세그먼트에 필요한 타일 수 (length / 4)
}

[System.Serializable]
public class CorridorPath
{
    public int               roomA;        // 연결 룸 A
    public int               roomB;        // 연결 룸 B
    public CorridorPathType  pathType;
    public List<CorridorSegment> segments; // Straight=1개, LShaped=2개
    public Vector3           bendPoint;    // L자형일 때 꺾임점 (Straight이면 무시)
}
```

### 3.2 CorridorEdge 확장 (수정)

```csharp
// DungeonLayoutData.cs에 추가
[System.Serializable]
public class CorridorEdge
{
    // ... 기존 필드 유지 ...
    public int roomA;
    public int roomB;
    public float length;
    public bool isMST;

    // ── MAP-02 추가 ──
    public int wallSideA;   // roomA에서 복도가 뚫리는 벽면 (0=N, 1=E, 2=S, 3=W)
    public int wallSideB;   // roomB에서 복도가 뚫리는 벽면
}
```

---

## 4. 복도 경로 계산 알고리즘

### 4.1 직선 vs L자형 결정 로직

두 룸 center 간의 벡터를 분석하여 경로 형태를 결정한다.

```
function ComputeCorridorPath(roomA: RoomNode, roomB: RoomNode) -> CorridorPath:

    centerA = Vector3(roomA.center.x, 0, roomA.center.y)
    centerB = Vector3(roomB.center.x, 0, roomB.center.y)
    
    dx = |centerB.x - centerA.x|
    dz = |centerB.z - centerA.z|
    
    halfSizeA = roomA.size / 2
    halfSizeB = roomB.size / 2
    
    // 1. 축 정렬 판정 — 한쪽 축의 차이가 복도 폭(4m) 이내면 "직선"
    ALIGN_THRESHOLD = 4.0  // 복도 폭 1타일
    
    if dx <= ALIGN_THRESHOLD:
        // Z축 정렬 → Z방향 직선 복도
        path.pathType = Straight
        wallSideA = (centerB.z > centerA.z) ? N : S
        wallSideB = opposite(wallSideA)
        
        // 복도 X좌표 = 두 룸 중심의 평균 X (스냅: 4m 단위)
        corridorX = Snap4(average(centerA.x, centerB.x))
        
        // 복도 시작 = roomA 벽면 외측, 끝 = roomB 벽면 외측
        startZ = centerA.z + sign * (halfSizeA.y + 0.5)  // 벽 두께 보정
        endZ   = centerB.z - sign * (halfSizeB.y + 0.5)
        
        segment = CorridorSegment(
            start = (corridorX, 0, startZ),
            end   = (corridorX, 0, endZ),
            direction = (0, 0, sign),
            length = |endZ - startZ|,
            tileCount = ceil(length / 4)
        )
        path.segments = [segment]
    
    else if dz <= ALIGN_THRESHOLD:
        // X축 정렬 → X방향 직선 복도 (대칭 처리)
        ...동일 로직, X↔Z 교환...
    
    else:
        // 2. L자형 복도 — 꺾임점 결정
        path.pathType = LShaped
        
        // 꺾임점 후보 2개: (A.x, B.z) 또는 (B.x, A.z)
        // 기존 룸과 충돌하지 않는 후보 선택 (AABB 충돌 검사)
        bendCandidate1 = (centerA.x, 0, centerB.z)
        bendCandidate2 = (centerB.x, 0, centerA.z)
        
        // 우선순위: 기존 룸과 충돌 없는 것 → 두 세그먼트 합산 길이가 짧은 것
        bend = SelectBestBend(bendCandidate1, bendCandidate2, rooms)
        path.bendPoint = bend
        
        // Segment 1: roomA → bend (수직 또는 수평)
        // Segment 2: bend → roomB (수평 또는 수직)
        
        wallSideA = DirectionFrom(centerA, bend)   // A에서 bend 방향
        wallSideB = DirectionFrom(centerB, bend)    // B에서 bend 방향 (반대)
        
        seg1.start = RoomWallExit(roomA, wallSideA)
        seg1.end   = bend
        seg2.start = bend
        seg2.end   = RoomWallExit(roomB, wallSideB)
        
        path.segments = [seg1, seg2]
    
    return path
```

### 4.2 벽면 방향 계산 (`DirectionFrom`)

```
function DirectionFrom(fromCenter: Vector3, toPoint: Vector3) -> int:
    delta = toPoint - fromCenter
    
    if |delta.z| >= |delta.x|:
        return delta.z > 0 ? 0(N) : 2(S)
    else:
        return delta.x > 0 ? 1(E) : 3(W)
```

### 4.3 4m 그리드 스냅

복도 좌표는 4m 그리드에 스냅한다. KayKit 에셋이 4x4m 단위이므로 타일 배치가 정확히 정렬된다.

```
function Snap4(value: float) -> float:
    return Round(value / 4.0) * 4.0
```

### 4.4 꺾임점 충돌 검사

```
function SelectBestBend(bend1, bend2, rooms) -> Vector3:
    // L자 복도의 두 세그먼트가 기존 룸 AABB를 관통하는지 검사
    // 관통하지 않는 후보 우선
    // 둘 다 관통하지 않으면 합산 길이가 짧은 것 선택
    // 둘 다 관통하면 관통 면적이 작은 것 선택
```

---

## 5. 복도 세그먼트 지오메트리 구축

### 5.1 KayKit 에셋 재사용 계획

WFCPrefabBuilder.cs에서 사용하는 동일한 에셋을 재사용한다.

| 용도 | FBX 파일 | 크기 | 비고 |
|------|----------|------|------|
| **바닥** | `floor_tile_large.fbx` | 4x4m | 석재바닥 (기본) |
| **바닥 (변형)** | `floor_dirt_large.fbx`, `floor_dirt_large_rocky.fbx` | 4x4m | 랜덤 변형 (10% 확률) |
| **벽** | `wall.fbx` | 4x4m (W x H) | 기본 벽 패널 |
| **벽 (변형)** | `wall_cracked.fbx`, `wall_arched.fbx` | 4x4m | 랜덤 변형 |
| **벽 장식** | `wall_inset_candles.fbx`, `wall_inset_shelves.fbx` 등 | 4x4m | 10% 확률 교체 |
| **천장** | `ceiling_tile.fbx` | 4x4m | Y = 8m |
| **기둥** | `pillar.fbx` | - | 모서리/꺾임점 배치 |
| **doorway 아치** | `wall_doorway.fbx` | 4x4m | 룸-복도 연결부 |
| **횃불** | `torch_mounted.fbx` | - | 벽면 간헐 배치 + PointLight |

경로: `Assets/KayKit_DungeonRemastered_1.1_SOURCE/Assets/fbx(unity)/`

### 5.2 복도 단면 규격

```
       ← 4m (1타일) →
   ┌──────────────────────┐  ← ceiling_tile (Y=8m)
   │                      │
   │  wall.fbx (상단)     │  ← Y=4m ~ Y=8m (tier 1)
   │                      │
   │  wall.fbx (하단)     │  ← Y=0m ~ Y=4m  (tier 0)
   │                      │
   └──────────────────────┘  ← floor_tile_large (Y=0)
```

- 벽 높이: 2단 적층 = 8m (기존 WFC 규격과 동일)
- 복도 폭: 1타일 = 4m
- 바닥 Y: 0m (floor 에셋 윗면 = +0.11m)
- 천장 Y: 8m

### 5.3 세그먼트 지오메트리 조립 의사코드

```
function BuildSegmentGeometry(segment: CorridorSegment, parent: Transform):
    dir     = segment.direction          // (0,0,1) 또는 (1,0,0) 등
    right   = Cross(Vector3.up, dir)     // 수직 방향 (좌우 벽 오프셋)
    
    WALL_H      = 4.0
    WALL_TIERS  = 2
    CEIL_Y      = 8.0
    WALL_OFFSET = 2.5  // 중심에서 벽까지 거리 (복도 폭 4m → 반폭 2m + 벽 두께 보정 0.5m)
    
    for i in 0 .. segment.tileCount - 1:
        // 이 타일의 중심 위치
        tileCenter = segment.start + dir * (i * 4.0 + 2.0)
        
        // ── 바닥 ──
        floorModel = SelectFloorModel()  // 90% stone, 10% dirt 변형
        PlaceModel(floorModel, parent, tileCenter, RotationForDir(dir))
        
        // ── 천장 ──
        PlaceModel("ceiling_tile.fbx", parent, tileCenter + (0, CEIL_Y, 0), RotationForDir(dir))
        
        // ── 양쪽 벽 (2단) ──
        for tier in 0..1:
            wallY = tier * WALL_H
            
            // 좌측 벽
            leftPos = tileCenter + right * WALL_OFFSET + (0, wallY, 0)
            leftRot = WallRotation(dir, left=true)
            wallModel = SelectWallModel(tier)
            PlaceWallWithDecoration(wallModel, parent, leftPos, leftRot, tier)
            
            // 우측 벽
            rightPos = tileCenter - right * WALL_OFFSET + (0, wallY, 0)
            rightRot = WallRotation(dir, left=false)
            PlaceWallWithDecoration(wallModel, parent, rightPos, rightRot, tier)
    
    // ── 양 끝 기둥 (세그먼트 시작/끝) ──
    for tier in 0..1:
        PlaceModel("pillar.fbx", parent, segment.start + right*WALL_OFFSET + (0, tier*WALL_H, 0))
        PlaceModel("pillar.fbx", parent, segment.start - right*WALL_OFFSET + (0, tier*WALL_H, 0))
        PlaceModel("pillar.fbx", parent, segment.end + right*WALL_OFFSET + (0, tier*WALL_H, 0))
        PlaceModel("pillar.fbx", parent, segment.end - right*WALL_OFFSET + (0, tier*WALL_H, 0))
```

### 5.4 L자형 꺾임점 처리

```
function BuildBendGeometry(bendPoint: Vector3, seg1Dir: Vector3, seg2Dir: Vector3, parent: Transform):
    // 꺾임점은 코너 타일: 바닥 1개 + 천장 1개 + 외측 코너 벽 2장 + 내측 기둥 1개
    
    PlaceModel(floorModel, parent, bendPoint, 0)
    PlaceModel("ceiling_tile.fbx", parent, bendPoint + (0, CEIL_Y, 0), 0)
    
    // 외측 모서리에 벽 2장 (L의 바깥쪽)
    outerCornerWall1_pos = bendPoint + OuterOffset(seg1Dir, seg2Dir)
    outerCornerWall2_pos = bendPoint + OuterOffset(seg2Dir, seg1Dir)
    PlaceModel("wall.fbx", parent, outerCornerWall1_pos, rotFor(seg1Dir))
    PlaceModel("wall.fbx", parent, outerCornerWall2_pos, rotFor(seg2Dir))
    
    // 내측 모서리에 기둥 (L의 안쪽)
    innerPillarPos = bendPoint + InnerOffset(seg1Dir, seg2Dir)
    PlaceModel("pillar.fbx", parent, innerPillarPos, 0)
```

---

## 6. Doorway 연결부 처리

### 6.1 룸 벽면에 doorway 아치 배치

복도가 룸에 연결되는 지점에서, 해당 벽면의 중앙 벽 패널을 `wall_doorway.fbx`로 교체한다.

```
function PlaceDoorwayAtRoom(room: RoomNode, wallSide: int, parent: Transform):
    // WFCPrefabBuilder의 PlaceEntranceArch 로직 재활용
    
    roomCenter3D = Vector3(room.center.x, 0, room.center.y)
    halfSize     = room.size / 2
    
    // 벽면 중심점 계산
    switch wallSide:
        N: wallCenter = roomCenter3D + (0, 0,  halfSize.y + wallThickness)
        E: wallCenter = roomCenter3D + (halfSize.x + wallThickness, 0, 0)
        S: wallCenter = roomCenter3D + (0, 0, -halfSize.y - wallThickness)
        W: wallCenter = roomCenter3D + (-halfSize.x - wallThickness, 0, 0)
    
    wallRotY = WallRotation(wallSide)
    
    // 해당 벽면의 타일 배열에서 중앙 타일만 wall_doorway.fbx로 교체
    // 나머지 타일은 기존 wall.fbx 유지
    rightDir  = Quaternion.Euler(0, wallRotY, 0) * Vector3.right
    roomScale = (int)(room.size.x / 4)  // 40m → 10, 24m → 6
    half      = roomScale / 2
    
    for k in -half .. half:
        if k == 0:
            // 중앙: doorway 아치 (하단 1단만)
            PlaceModel("wall_doorway.fbx", parent, wallCenter + rightDir * 0, wallRotY)
            // 상단: solid wall (천장부 막음)
            PlaceModel("wall.fbx", parent, wallCenter + rightDir * 0 + (0, 4, 0), wallRotY)
        else:
            // 나머지: 일반 벽 (2단)
            PlaceModel("wall.fbx", parent, wallCenter + rightDir * (k * 4), wallRotY)
            PlaceModel("wall.fbx", parent, wallCenter + rightDir * (k * 4) + (0, 4, 0), wallRotY)
```

### 6.2 기존 룸 벽 제거/교체 전략

Delaunay 레이아웃에서는 룸이 사전 제작(pre-built)이 아니라 동적으로 조립된다. 따라서:

1. **MAP-03의 룸 빌더가 벽을 조립할 때**, `CorridorBuilder`가 사전에 계산해 둔 `wallSideA`/`wallSideB` 정보를 참조하여 해당 면에는 doorway 벽을 배치한다.
2. **복도 빌더(CorridorBuilder)가 직접 doorway 벽을 배치하는 경우**, 룸 빌더에 "이 면은 복도가 연결되니 벽을 안 만들어도 됨" 플래그를 전달한다.

구체적 인터페이스:

```csharp
// CorridorBuilder가 계산 결과를 RoomNode에 기록
// MAP-02 완료 시점에 아래 데이터가 채워져 있음
public class RoomNode
{
    // ... 기존 필드 ...
    
    // MAP-02에서 추가: 복도가 연결된 벽면 목록
    [System.NonSerialized]
    public HashSet<int> corridorWallSides = new HashSet<int>(); // 0=N, 1=E, 2=S, 3=W
}
```

MAP-03 룸 빌더가 벽을 조립할 때 `corridorWallSides.Contains(side)` 이면 해당 면 중앙 타일을 `wall_doorway.fbx`로 교체한다.

### 6.3 doorway 양쪽 끝 연결

복도의 시작/끝 1타일은 룸 벽면과 바로 접하므로, 해당 구간에는 바닥/천장만 배치하고 **양쪽 벽은 룸 벽면과 자연스럽게 이어지도록** 한다.

```
복도 시작 타일 → 바닥 + 천장 + 벽 (doorway 아치와 같은 높이)
                 양쪽 벽은 룸 벽면 연장선과 정렬
```

---

## 7. 최소 복도 길이 보장

### 7.1 8m 최소 거리 보장 메커니즘

MAP-01의 `DungeonLayoutGenerator.corridorMinLength` (기본 12m)가 룸 배치 시 최소 간격을 보장하지만, 복도 지오메트리 빌드 시에도 이중 검증한다.

```
function ValidateCorridorLength(path: CorridorPath) -> bool:
    totalLength = sum(seg.length for seg in path.segments)
    return totalLength >= MIN_CORRIDOR_LENGTH  // 8m
```

만약 계산된 복도 길이가 8m 미만이면:
1. 우선 복도를 8m로 강제 연장 (빈 공간으로 밀어냄)
2. 이것이 다른 룸과 충돌하면 경고 로그 출력 (MAP-01 배치 단계의 문제)

### 7.2 "문 열면 바로 문이 보이는 현상" 방지

- `corridorMinLength = 12m`로 기본 설정 (MAP-01에서 이미 구현)
- 이는 두 룸 벽면 외측 사이 거리가 최소 12m 보장
- 복도 내부 길이 = `corridorMinLength - 벽 두께 보정` >= 10m >> 8m 기준 충족

---

## 8. Inspector 노출 파라미터

### 8.1 CorridorBuilder Inspector

```csharp
public class CorridorBuilder : MonoBehaviour
{
    [Header("Asset Path")]
    [Tooltip("KayKit FBX 에셋 기본 경로")]
    public string assetBasePath = "Assets/KayKit_DungeonRemastered_1.1_SOURCE/Assets/fbx(unity)/";

    [Header("Corridor Dimensions")]
    [Tooltip("복도 폭 (타일 수). 1 = 4m")]
    [Range(1, 3)]
    public int corridorWidth = 1;

    [Tooltip("벽 높이 단수 (1단 = 4m)")]
    [Range(1, 3)]
    public int wallTiers = 2;

    [Tooltip("최소 복도 길이 (미터). 이 값 미만이면 강제 연장")]
    [Range(4f, 20f)]
    public float minCorridorLength = 8f;

    [Header("Floor Variation")]
    [Tooltip("기본 바닥 에셋")]
    public string[] corridorFloors = { "floor_tile_large.fbx" };

    [Tooltip("변형 바닥 에셋 (랜덤 혼합)")]
    public string[] corridorFloorVariants = { "floor_dirt_large.fbx", "floor_dirt_large_rocky.fbx" };

    [Tooltip("변형 바닥 출현 확률")]
    [Range(0f, 0.5f)]
    public float floorVariantChance = 0.1f;

    [Header("Wall Variation")]
    [Tooltip("기본 벽 모델")]
    public string wallModel = "wall.fbx";

    [Tooltip("벽 변형 모델 풀 (하단 1단에서 랜덤 교체)")]
    public string[] wallVariants = { "wall_cracked.fbx", "wall_arched.fbx" };

    [Tooltip("벽 변형 출현 확률")]
    [Range(0f, 0.3f)]
    public float wallVariantChance = 0.1f;

    [Header("Decoration")]
    [Tooltip("벽 장식 (inset 선반/촛대 등) 출현 확률")]
    [Range(0f, 0.3f)]
    public float wallDecoChance = 0.1f;

    [Tooltip("횃불 배치 간격 (타일 수). 0 = 비활성")]
    [Range(0, 6)]
    public int torchInterval = 3;

    [Tooltip("복도 바닥 소품 풀")]
    public string[] corridorProps = { "barrel_large.fbx", "box_small.fbx", "crate_small.fbx" };

    [Tooltip("복도 바닥 소품 최대 개수 (세그먼트당)")]
    [Range(0, 4)]
    public int maxPropsPerSegment = 2;

    [Header("Torch Light")]
    public float torchRange = 12f;
    public float torchIntensity = 4f;
    public Color torchColor = new Color(1f, 0.6f, 0.2f);

    [Header("Debug")]
    public bool drawGizmos = true;
}
```

---

## 9. 주요 메서드 시그니처

### 9.1 CorridorBuilder.cs

```csharp
public class CorridorBuilder : MonoBehaviour
{
    // ── Public API ──
    
    /// <summary>
    /// DungeonLayout의 모든 CorridorEdge에 대해 3D 복도를 빌드한다.
    /// DungeonLayoutGenerator.BakeLayout() 완료 후 호출.
    /// </summary>
    public void BuildCorridors(DungeonLayout layout, Transform container);

    // ── Phase 1: 경로 계산 ──
    
    /// <summary>
    /// 단일 CorridorEdge에 대해 직선/L자형 경로를 계산한다.
    /// </summary>
    private CorridorPath ComputeCorridorPath(
        RoomNode roomA, RoomNode roomB, List<RoomNode> allRooms);

    /// <summary>
    /// 두 점 간 축 정렬 여부를 판정하여 직선/L자형을 결정.
    /// </summary>
    private CorridorPathType DeterminePathType(
        Vector3 centerA, Vector3 centerB, float alignThreshold);

    /// <summary>
    /// L자형 꺾임점 후보 2개 중 최적 선택 (충돌 없는, 짧은).
    /// </summary>
    private Vector3 SelectBestBend(
        Vector3 bend1, Vector3 bend2, Vector3 centerA, Vector3 centerB,
        List<RoomNode> allRooms);

    /// <summary>
    /// 꺾임점이 기존 룸 AABB와 충돌하는지 검사.
    /// 복도 폭(4m)을 고려한 AABB 팽창.
    /// </summary>
    private bool IsBendColliding(
        Vector3 bendPoint, Vector3 segStart, Vector3 segEnd,
        List<RoomNode> rooms, float corridorHalfWidth);

    /// <summary>
    /// 룸 벽면 외측의 복도 시작점 계산.
    /// </summary>
    private Vector3 GetRoomWallExitPoint(
        RoomNode room, int wallSide);

    /// <summary>
    /// centerA에서 centerB 방향으로 가장 가까운 벽면 결정 (0=N,1=E,2=S,3=W).
    /// </summary>
    private int GetExitWallSide(Vector3 fromCenter, Vector3 toCenter);

    // ── Phase 2: Doorway 배치 ──
    
    /// <summary>
    /// 복도 연결 벽면 정보를 RoomNode.corridorWallSides에 기록.
    /// </summary>
    private void RegisterDoorwaySides(DungeonLayout layout, List<CorridorPath> paths);

    /// <summary>
    /// 룸 벽면에 wall_doorway.fbx 배치 (중앙 1타일만).
    /// 상단 tier는 solid wall로 막음.
    /// </summary>
    private void PlaceDoorway(
        RoomNode room, int wallSide, Transform parent);

    // ── Phase 3: 지오메트리 조립 ──
    
    /// <summary>
    /// 단일 CorridorSegment의 바닥/벽/천장 타일 반복 배치.
    /// </summary>
    private void BuildSegmentGeometry(
        CorridorSegment segment, Transform parent);

    /// <summary>
    /// L자형 꺾임점의 코너 지오메트리 (바닥+천장+외측 벽+내측 기둥).
    /// </summary>
    private void BuildBendGeometry(
        Vector3 bendPoint, Vector3 seg1Dir, Vector3 seg2Dir, Transform parent);

    /// <summary>
    /// 세그먼트 양 끝 기둥 배치.
    /// </summary>
    private void PlaceEndPillars(
        Vector3 position, Vector3 right, Transform parent);

    // ── Phase 4: 소품 ──
    
    /// <summary>
    /// 벽 장식 배치 (torch, banner, inset 등).
    /// WFCPrefabBuilder.PlaceWallDecorated() 로직 재활용.
    /// </summary>
    private void PlaceWallDecoration(
        string wallName, Transform parent, Vector3 pos, float rotY, int tier);

    /// <summary>
    /// 세그먼트에 바닥 소품 (barrel, crate 등) 랜덤 배치.
    /// </summary>
    private void PlaceCorridorProps(
        CorridorSegment segment, Transform parent);

    // ── 유틸리티 ──
    
    /// <summary>
    /// 4m 그리드 스냅.
    /// </summary>
    private float Snap4(float value);

    /// <summary>
    /// KayKit FBX 모델 인스턴스화 (WFCPrefabBuilder.PlaceModel과 동일 패턴).
    /// Editor/Runtime 양립.
    /// </summary>
    private GameObject PlaceModel(
        string modelName, Transform parent, Vector3 localPos, float rotY);
}
```

### 9.2 DungeonLayoutGenerator.cs 수정

```csharp
// DungeonLayoutGenerator.cs에 추가할 연계 코드
[Header("Corridor Builder")]
[Tooltip("CorridorBuilder 참조 (같은 GameObject 또는 자식)")]
public CorridorBuilder corridorBuilder;

// BakeLayout() 완료 후 자동 호출 옵션
[Tooltip("레이아웃 생성 후 복도 자동 빌드")]
public bool autoBuiltCorridors = true;

// BakeLayout() 끝에 추가:
if (autoBuiltCorridors && corridorBuilder != null)
{
    var container = new GameObject("Generated_Dungeon_Corridors");
    corridorBuilder.BuildCorridors(_layout, container.transform);
}
```

---

## 10. 구현 순서 (단계별)

### Step 1: 데이터 구조 (30분)
1. `CorridorSegment.cs` 생성 (CorridorPathType, CorridorSegment, CorridorPath)
2. `DungeonLayoutData.cs`에 `CorridorEdge.wallSideA/B` 추가
3. `RoomNode`에 `corridorWallSides` HashSet 추가

### Step 2: CorridorBuilder 뼈대 + 경로 계산 (1시간)
1. `CorridorBuilder.cs` 생성 (MonoBehaviour + Inspector 파라미터)
2. `ComputeCorridorPath()` — 직선/L자형 판정 + 세그먼트 계산
3. `SelectBestBend()` — 꺾임점 충돌 검사
4. `RegisterDoorwaySides()` — 벽면 정보 기록

### Step 3: 지오메트리 조립 (1시간)
1. `PlaceModel()` 유틸리티 (Editor/Runtime 양립)
2. `BuildSegmentGeometry()` — 바닥/벽/천장 타일 반복 배치
3. `BuildBendGeometry()` — L자형 코너 타일
4. `PlaceEndPillars()` — 세그먼트 양 끝 기둥

### Step 4: Doorway 배치 (30분)
1. `PlaceDoorway()` — 룸 벽면 중앙에 wall_doorway.fbx
2. 상단 tier solid wall 배치

### Step 5: 소품 + 장식 (30분)
1. `PlaceWallDecoration()` — torch, banner 등
2. `PlaceCorridorProps()` — 바닥 소품

### Step 6: 통합 + Gizmo (30분)
1. `DungeonLayoutGenerator` ↔ `CorridorBuilder` 연계
2. 디버그 Gizmo (복도 경로 와이어, 꺾임점 구체)
3. SpectatorCamera 스폰 연동

---

## 11. WFCPrefabBuilder 에셋 재사용 상세

### 11.1 직접 재사용하는 로직

| WFCPrefabBuilder 메서드 | CorridorBuilder 재구현 | 비고 |
|------------------------|----------------------|------|
| `PlaceModel(name, parent, pos, roty)` | `PlaceModel()` 동일 패턴 복사 | Editor: `PrefabUtility.InstantiatePrefab`, Runtime: `Instantiate` |
| `PlaceEntranceArch()` | `PlaceDoorway()` 단순화 | 중앙 1타일만 doorway, 나머지 solid |
| `PlaceWallDecorated()` | `PlaceWallDecoration()` 축소 | torch + banner만, wallHangItems 제외 |
| `BuildMacroWall()` 벽 배치 패턴 | `BuildSegmentGeometry()` 내부 | 2단 적층, 코너 기둥 동일 패턴 |

### 11.2 재사용하지 않는 부분

| 항목 | 이유 |
|------|------|
| CreateVariants() 회전 변형 | 복도는 동적 방향이므로 사전 회전 불필요 |
| SocketType 매칭 | WFC 전용, Delaunay 시스템 불필요 |
| RoomPreset 소품 배치 | 복도에는 최소 소품만 필요 |
| wallFurniture 벽 붙박이 | 복도에 가구 불필요 |
| tableOnlyItems | 복도에 테이블 없음 |

### 11.3 핵심 수치 (WFCPrefabBuilder에서 추출)

```
basePath       = "Assets/KayKit_DungeonRemastered_1.1_SOURCE/Assets/fbx(unity)/"
FLOOR_Y        = 0.11    // 바닥 에셋 윗면 높이
WALL_H         = 4.0     // wall.fbx 1단 높이
WALL_TIERS     = 2       // 벽 단 수
CEIL_Y         = 8.0     // 천장 높이 (WALL_H * WALL_TIERS)
WALL_THICKNESS = 1.0     // wall.fbx 두께 (pivot 중심 → outer face +0.5)
TILE_SIZE      = 4.0     // 바닥/벽 타일 1장 크기
PILLAR_OFFSET  = 1.25    // wallDist에서 기둥까지 간격 보정

// torch_mounted 배치 기준 (WFCPrefabBuilder line 515)
TORCH_Y        = 2.0     // 횃불 높이
TORCH_FORWARD  = 0.15    // 벽에서 돌출 거리
TORCH_RANGE    = 12.0    // PointLight 범위
TORCH_INTENSITY= 4.0
TORCH_COLOR    = Color(1.0, 0.6, 0.2)
```

---

## 12. Editor/Runtime 양립 설계

CorridorBuilder는 WFCGenerator와 동일한 패턴으로 Editor Bake와 Runtime 생성 양쪽을 지원한다.

```csharp
private GameObject PlaceModel(string name, Transform parent, Vector3 pos, float rotY)
{
    if (string.IsNullOrEmpty(name)) return null;
    
    string fullPath = assetBasePath + name;
    
#if UNITY_EDITOR
    if (!Application.isPlaying)
    {
        // Editor 모드: PrefabUtility로 프리팹 링크 유지
        var src = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(fullPath);
        if (src == null) { Debug.LogWarning($"[Corridor] Asset not found: {fullPath}"); return null; }
        var go = (GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(src);
        go.transform.SetParent(parent);
        go.transform.localPosition = pos;
        go.transform.localRotation = Quaternion.Euler(0, rotY, 0);
        return go;
    }
#endif
    
    // Runtime: Resources 또는 Addressables (구현 시 결정)
    // 현재 단계에서는 Editor Bake 전용
    return null;
}
```

---

## 13. Gizmo 디버그 시각화

```csharp
private void OnDrawGizmos()
{
    if (!drawGizmos || _corridorPaths == null) return;
    
    foreach (var path in _corridorPaths)
    {
        // 직선: 파란 선, L자: 초록 선
        Gizmos.color = path.pathType == CorridorPathType.Straight
            ? Color.cyan : Color.green;
        
        foreach (var seg in path.segments)
        {
            Gizmos.DrawLine(seg.start + Vector3.up * 3, seg.end + Vector3.up * 3);
            // 세그먼트 시작/끝에 구체
            Gizmos.DrawSphere(seg.start + Vector3.up * 3, 1f);
            Gizmos.DrawSphere(seg.end + Vector3.up * 3, 1f);
        }
        
        // 꺾임점: 노란 구체
        if (path.pathType == CorridorPathType.LShaped)
        {
            Gizmos.color = Color.yellow;
            Gizmos.DrawSphere(path.bendPoint + Vector3.up * 3, 2f);
        }
    }
}
```

---

## 14. 검증 기준 매핑

| 검증 항목 | 구현 대응 | 확인 방법 |
|-----------|-----------|-----------|
| 모든 복도에 바닥/벽/천장 존재 | `BuildSegmentGeometry()` + `BuildBendGeometry()` | SpectatorCamera 순회 + Debug.Log 카운트 |
| 룸-복도 연결부 doorway 아치 정상 | `PlaceDoorway()` | wall_doorway.fbx 배치 수 == corridors.Count * 2 |
| 복도 길이 최소 8m, 문-문 직결 0건 | `ValidateCorridorLength()` + MAP-01 corridorMinLength | Debug.Log 경고 0건 |

---

## 15. 리스크 및 주의사항

| 리스크 | 완화 방안 |
|--------|-----------|
| L자형 꺾임점이 다른 룸을 관통 | `IsBendColliding()` AABB 검사로 사전 차단. 두 후보 모두 관통 시 경고 후 직선 강제 |
| 복도끼리 교차/겹침 | `DungeonLayoutGenerator`의 extraEdgeRatio가 낮아(0.15) 일반적으로 드문 상황. 교차 감지 로직 추가 가능 (Phase 2 확장) |
| 벽 타일 정렬 오차 | 모든 좌표를 `Snap4()` 처리하여 4m 그리드 정렬 보장 |
| KayKit 에셋 미발견 | `PlaceModel()` 내부에서 null 체크 + 경고 로그 |
| 룸 벽면 doorway 위치가 복도 진입 방향과 불일치 | `GetExitWallSide()` → `GetRoomWallExitPoint()`로 정확한 벽면-복도 정렬 보장 |
| Runtime 생성 시 에셋 로딩 | 현재는 Editor Bake 전용. Runtime은 MAP-03 이후 Addressables 연동 시 대응 |
