
# MAP-01 던전 레이아웃 생성기 — 구현 설계도

> 작성일: 2026-04-07
> 대체 대상: WFCGenerator.cs (5x5 그리드 기반 WFC)
> 스코프: 룸 랜덤 산포 + Delaunay Triangulation + MST 복도 그래프
> 복도 지오메트리: MAP-02 / 룸 내부 장식: MAP-03

---

## 1. 새 파일/클래스 목록

| 파일 경로 | 클래스/구조체 | 역할 |
|-----------|--------------|------|
| `Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs` | `DungeonLayoutGenerator : MonoBehaviour` | 메인 레이아웃 생성기 — 배치, Delaunay, MST, 검증 전체 오케스트레이션 |
| `Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs` | `RoomNode`, `CorridorEdge`, `DungeonLayout` | 순수 데이터 클래스 (MonoBehaviour 아님) |
| `Assets/Scripts/Map/Dungeon/DelaunayTriangulation.cs` | `DelaunayTriangulation` (static class) | Bowyer-Watson 알고리즘 순수 구현 |

> **WFCGenerator.cs는 수정하지 않는다.** 새 시스템은 `Assets/Scripts/Map/Dungeon/` 폴더에 독립 배치되며, 기존 WFC 시스템과 병존한다. 전환은 씬에 어느 Generator를 배치하느냐로 결정한다.

---

## 2. 핵심 데이터 구조

### 2.1 RoomNode

```csharp
[System.Serializable]
public class RoomNode
{
    public int       id;            // 0-based 고유 인덱스
    public TileType  tileType;      // StartRoom, ExitRoom, NormalRoom 등 (Tile.cs 재사용)
    public Vector2   center;        // 2D 연속 좌표 (xz 평면)
    public Vector2   size;          // 룸 바운딩 박스 (폭, 깊이)
    public bool      isDangerous;   // TileType 기반 자동 결정
    public RoomFlavor roomFlavor;   // None (MAP-03에서 배정)
}
```

- `center`는 월드 좌표 XZ 평면의 연속 좌표 (그리드 스냅 없음)
- `size`는 룸 프리팹의 실제 크기. 기존 tileSize(44m) 기반으로 대형 룸 = (40, 40), 소형 룸 = (24, 24) 기본값 사용

### 2.2 CorridorEdge

```csharp
[System.Serializable]
public class CorridorEdge
{
    public int     roomA;         // RoomNode.id
    public int     roomB;         // RoomNode.id
    public float   length;        // 두 룸 center 간 거리
    public bool    isMST;         // MST 엣지 여부 (디버그용)
}
```

### 2.3 DungeonLayout (최종 출력)

```csharp
[System.Serializable]
public class DungeonLayout
{
    public List<RoomNode>     rooms;       // 배치된 모든 룸
    public List<CorridorEdge> corridors;   // 선택된 복도 연결
    public int startRoomId;                // rooms[startRoomId].tileType == StartRoom
    public int exitRoomId;                 // rooms[exitRoomId].tileType == ExitRoom
}
```

### 2.4 Delaunay 내부 구조 (DelaunayTriangulation.cs)

```csharp
public struct Triangle
{
    public int v0, v1, v2;                    // RoomNode.id 인덱스
    public Vector2 circumcenter;
    public float circumradiusSq;
}

public struct Edge
{
    public int a, b;                          // 정점 인덱스 (a < b 정규화)
}
```

---

## 3. 알고리즘 의사코드

### 3.1 Phase 1 — 룸 랜덤 배치

```
function PlaceRooms(roomCount, mapSize, minSpacing):
    rooms = []
    
    // 1. StartRoom 배치: 맵 가장자리 영역에서 랜덤 선택
    startRoom = CreateRoom(StartRoom)
    startRoom.center = RandomEdgePosition(mapSize)
    rooms.Add(startRoom)
    
    // 2. ExitRoom 배치: StartRoom에서 맨해튼 거리 최대화 (맵 반대편 가장자리)
    exitRoom = CreateRoom(ExitRoom)
    exitRoom.center = FarthestEdgePosition(startRoom.center, mapSize)
    rooms.Add(exitRoom)
    
    // 3. 필수 룸 배치: SpecialRoom 최소 1개
    PlaceRequired(rooms, SpecialRoom, 1)
    
    // 4. 나머지 룸 배치 (NormalRoom, ObjectiveRoom, 추가 SpecialRoom)
    //    비율 기반 — TileType 선택 후 위치 탐색
    remainingCount = roomCount - rooms.Count
    for i in 0..remainingCount:
        tileType = SelectTileTypeByQuota()
        
        // 포아송 디스크 샘플링 변형 — 최대 30회 시도
        for attempt in 0..maxPlacementAttempts:
            candidate = RandomPointInMap(mapSize, margin)
            
            // 최소 간격 검사: 모든 기존 룸과의 거리 >= minSpacing
            if AllRoomsAreFarEnough(rooms, candidate, minSpacing):
                room = CreateRoom(tileType)
                room.center = candidate
                rooms.Add(room)
                break
    
    return rooms
```

**최소 간격 계산:**
```
minSpacing = max(roomA.size.x, roomA.size.y) / 2
           + max(roomB.size.x, roomB.size.y) / 2
           + corridorMinLength
```
- `corridorMinLength`는 Inspector 노출 파라미터 (기본 12m). 문 열면 바로 문이 보이는 현상 방지의 핵심 변수.

### 3.2 Phase 2 — Bowyer-Watson Delaunay Triangulation

```
function BowyerWatson(points[]):     // points = rooms[].center
    // 1. 모든 점을 포함하는 초거대 삼각형(super-triangle) 생성
    superTri = CreateSuperTriangle(points)
    triangles = [superTri]
    
    // 2. 각 점을 순차 삽입
    for each point in points:
        badTriangles = []
        
        // 2a. 이 점이 외접원 내부에 있는 삼각형 찾기
        for each tri in triangles:
            if PointInCircumcircle(point, tri):
                badTriangles.Add(tri)
        
        // 2b. bad triangles의 경계 다각형(polygon hole) 찾기
        polygon = []
        for each tri in badTriangles:
            for each edge of tri:
                if edge is NOT shared by another badTriangle:
                    polygon.Add(edge)
        
        // 2c. bad triangles 제거
        triangles.RemoveAll(badTriangles)
        
        // 2d. 경계 다각형의 각 변과 새 점으로 삼각형 생성
        for each edge in polygon:
            newTri = Triangle(edge.a, edge.b, pointIndex)
            ComputeCircumcircle(newTri)
            triangles.Add(newTri)
    
    // 3. super-triangle 정점을 포함하는 삼각형 제거
    triangles.RemoveAll(tri => tri shares vertex with superTri)
    
    // 4. 삼각형에서 고유 엣지 추출
    edges = ExtractUniqueEdges(triangles)
    return edges
```

**주의사항:**
- 동일 좌표 점(degenerate case) 방지: 배치 단계에서 최소 간격을 보장하므로 정상 케이스에서 발생하지 않으나, 방어 코드로 epsilon 거리 체크 추가
- 공선점(collinear) 처리: 4개 이상의 점이 일직선인 경우 외접원이 무한대 — 이런 삼각형은 스킵

### 3.3 Phase 3 — MST + 추가 엣지 선택

```
function SelectCorridors(rooms, delaunayEdges, extraEdgeRatio):
    // 1. 엣지를 가중치(길이) 기준 오름차순 정렬
    sortedEdges = Sort(delaunayEdges, by: length ascending)
    
    // 2. Kruskal MST — Union-Find
    parent[] = [0..rooms.Count-1]  // 각 노드의 부모
    rank[]   = [0..0]
    mstEdges = []
    
    for each edge in sortedEdges:
        rootA = Find(parent, edge.roomA)
        rootB = Find(parent, edge.roomB)
        if rootA != rootB:
            Union(parent, rank, rootA, rootB)
            edge.isMST = true
            mstEdges.Add(edge)
            if mstEdges.Count == rooms.Count - 1:
                break
    
    // 3. 추가 엣지 — MST에 포함되지 않은 Delaunay 엣지 중 일부 추가
    //    루프(순환 경로)를 만들어 탐사 다양성 확보
    nonMSTEdges = delaunayEdges.Except(mstEdges)
    extraCount = Floor(nonMSTEdges.Count * extraEdgeRatio)  // 기본 0.15 (15%)
    Shuffle(nonMSTEdges)
    
    finalCorridors = mstEdges + nonMSTEdges.Take(extraCount)
    
    return finalCorridors
```

**왜 MST+alpha인가:**
- 순수 MST는 트리 구조 → 경로가 유일해서 탐사 재미가 없음
- 추가 엣지가 루프를 만들어 우회 경로/숏컷 생성
- `extraEdgeRatio`로 복도 밀도 조절 (0.0 = 순수 트리, 1.0 = 모든 Delaunay 엣지)

### 3.4 Phase 4 — 경로 보장 검증 (BFS)

```
function ValidateConnectivity(layout):
    // 1. rooms를 정점, corridors를 간선으로 인접 리스트 구성
    adj = BuildAdjacencyList(layout.rooms, layout.corridors)
    
    // 2. StartRoom에서 BFS
    visited = BFS(adj, layout.startRoomId)
    
    // 3. 검증 조건
    //    a) ExitRoom 도달 가능
    if layout.exitRoomId NOT in visited:
        return FAIL("ExitRoom unreachable")
    
    //    b) 모든 룸 도달 가능 (고립 룸 없음)
    if visited.Count != rooms.Count:
        return FAIL("Isolated rooms detected")
    
    //    c) SpecialRoom 최소 1개 도달 가능
    if no SpecialRoom in visited:
        return FAIL("No SpecialRoom reachable")
    
    return PASS
```

> MST는 정의상 모든 정점을 연결하므로, MST 구성이 정상이면 BFS 검증은 항상 통과한다. 이 검증은 구현 버그에 대한 안전장치이다.

---

## 4. Public 필드 (Inspector 노출)

```csharp
public class DungeonLayoutGenerator : MonoBehaviour
{
    [Header("Map Settings")]
    [Tooltip("맵 전체 크기 (XZ 평면, 미터 단위)")]
    public Vector2 mapSize = new Vector2(300f, 300f);
    
    [Tooltip("룸 총 개수 (Start + Exit 포함)")]
    [Range(6, 30)]
    public int roomCount = 14;
    
    [Header("Room Count Limits")]
    public int maxNormalRoom    = 7;
    public int maxObjectiveRoom = 2;
    public int maxSpecialRoom   = 3;
    public int maxStartRoom     = 1;
    public int maxExitRoom      = 1;
    
    [Header("Spacing")]
    [Tooltip("룸 사이 최소 복도 길이 (미터). 문-문 직결 방지의 핵심 파라미터")]
    [Range(8f, 40f)]
    public float corridorMinLength = 12f;
    
    [Tooltip("대형 룸 크기 (NormalRoom, ObjectiveRoom, StartRoom, ExitRoom)")]
    public Vector2 largeRoomSize = new Vector2(40f, 40f);
    
    [Tooltip("소형 룸 크기 (SpecialRoom)")]
    public Vector2 smallRoomSize = new Vector2(24f, 24f);
    
    [Header("Graph Settings")]
    [Tooltip("MST 외 추가 Delaunay 엣지 비율 (0=트리, 1=모든 엣지)")]
    [Range(0f, 1f)]
    public float extraEdgeRatio = 0.15f;
    
    [Header("Generation")]
    [Tooltip("배치 시도 최대 횟수 (포아송 디스크 변형)")]
    public int maxPlacementAttempts = 30;
    
    [Tooltip("전체 생성 재시도 최대 횟수")]
    public int maxRetries = 50;
    
    [Tooltip("에디터에서 자동 생성")]
    public bool generateOnStart = false;

    [Header("Debug")]
    [Tooltip("씬 뷰에 Gizmo 표시 (룸 박스, Delaunay 삼각형, MST, 복도)")]
    public bool drawGizmos = true;
}
```

### 파라미터 설계 근거

| 파라미터 | 기본값 | 근거 |
|----------|--------|------|
| `mapSize` | 300x300m | 14개 룸 * (40m 룸 + 12m 복도) 배치에 충분한 여유 |
| `roomCount` | 14 | WFC.md 기준 Start(1) + Exit(1) + Normal(7) + Objective(2) + Special(3) = 14 |
| `corridorMinLength` | 12m | 플레이어 캐릭터 ~2m 기준, 6배 거리에서 시야 차단 확보 |
| `extraEdgeRatio` | 0.15 | 14개 룸 MST = 13 엣지, Delaunay ~35 엣지, 추가 ~3 엣지 → 총 16 복도 |
| `maxPlacementAttempts` | 30 | 포아송 디스크 표준값. 30회 실패 시 해당 룸 스킵 |

---

## 5. DungeonLayoutGenerator 클래스 구조

```csharp
public class DungeonLayoutGenerator : MonoBehaviour
{
    // ── Inspector Fields (섹션 4 참조) ──

    // ── 내부 상태 ──
    private DungeonLayout _layout;
    private List<DelaunayTriangulation.Edge> _allDelaunayEdges;  // Gizmo용 보존
    
    // ══════════════════════════════════════
    //  Public API
    // ══════════════════════════════════════
    
    [ContextMenu("Bake Dungeon Layout (Editor Mode)")]
    public DungeonLayout BakeLayout()
    {
        // 재시도 루프 (maxRetries)
        //   Phase 1: PlaceRooms
        //   Phase 2: Delaunay Triangulation
        //   Phase 3: MST + extra edges
        //   Phase 4: BFS validation
        // 성공 시 _layout 저장 + 로그 출력
        // 실패 시 null 반환
    }
    
    public DungeonLayout GetLayout() => _layout;
    
    // ══════════════════════════════════════
    //  Phase 1: Room Placement
    // ══════════════════════════════════════
    
    private List<RoomNode> PlaceRooms()   { /* 섹션 3.1 */ }
    private Vector2 RandomEdgePosition()  { /* 맵 경계 ±margin 영역 */ }
    private Vector2 FarthestEdgeFrom(Vector2 origin) { /* 4변 중 가장 먼 변의 랜덤 점 */ }
    private TileType SelectTileTypeByQuota() { /* 남은 쿼터에서 가중 랜덤 */ }
    private bool IsSpacingValid(List<RoomNode> existing, Vector2 candidate, Vector2 candidateSize)
    {
        // 모든 기존 룸과의 AABB 간격 >= corridorMinLength 확인
    }
    private Vector2 GetRoomSize(TileType type)
    {
        // SpecialRoom → smallRoomSize, 나머지 → largeRoomSize
    }
    
    // ══════════════════════════════════════
    //  Phase 2: Delaunay
    // ══════════════════════════════════════
    
    // DelaunayTriangulation.Triangulate(points) 호출 위임
    
    // ══════════════════════════════════════
    //  Phase 3: MST + Edge Selection
    // ══════════════════════════════════════
    
    private List<CorridorEdge> BuildMST(List<RoomNode> rooms, List<Edge> edges) { /* Kruskal */ }
    private List<CorridorEdge> SelectExtraEdges(List<Edge> allEdges, List<CorridorEdge> mst) { /* ratio 기반 */ }
    
    // Union-Find 헬퍼
    private int Find(int[] parent, int x) { /* 경로 압축 */ }
    private void Union(int[] parent, int[] rank, int a, int b) { /* 랭크 기반 합치기 */ }
    
    // ══════════════════════════════════════
    //  Phase 4: Validation
    // ══════════════════════════════════════
    
    private bool ValidateLayout(DungeonLayout layout) { /* BFS 연결성 + 필수 룸 존재 */ }
    
    // ══════════════════════════════════════
    //  Gizmo (Editor Debug)
    // ══════════════════════════════════════
    
    private void OnDrawGizmos()
    {
        // drawGizmos == true 일 때:
        // 1. 룸 AABB → 색상별 와이어 큐브 (TileType 컬러맵)
        // 2. Delaunay 전체 엣지 → 회색 가는 선
        // 3. MST 엣지 → 노란색 굵은 선
        // 4. 최종 복도 → 초록색 굵은 선
        // 5. StartRoom → 파랑 구체 / ExitRoom → 빨강 구체
    }
}
```

---

## 6. DelaunayTriangulation.cs 상세

```csharp
/// <summary>
/// Bowyer-Watson 알고리즘을 사용한 2D Delaunay 삼각분할.
/// 순수 계산 유틸리티 — MonoBehaviour/Unity API 의존 없음 (Vector2만 사용).
/// </summary>
public static class DelaunayTriangulation
{
    public struct Triangle { /* v0, v1, v2, circumcenter, circumradiusSq */ }
    public struct Edge     { /* a, b — a < b 정규화 */ }
    
    /// <summary>
    /// 점 배열을 입력받아 Delaunay 엣지 리스트를 반환한다.
    /// </summary>
    public static List<Edge> Triangulate(Vector2[] points)
    {
        // 1. Super-triangle 생성
        // 2. 점 순차 삽입
        // 3. Super-triangle 정점 제거
        // 4. 고유 엣지 추출
    }
    
    // ── 내부 헬퍼 ──
    private static Triangle CreateSuperTriangle(Vector2[] points) { /* 바운딩 박스 * 10 */ }
    private static bool PointInCircumcircle(Vector2 p, Triangle t) { /* 외접원 판정 */ }
    private static void ComputeCircumcircle(ref Triangle t, Vector2[] points) { /* 외접 중심 + 반지름^2 */ }
}
```

### 시간 복잡도
- Bowyer-Watson: 평균 O(n log n), 최악 O(n^2)
- n = roomCount (최대 30) → 성능 이슈 없음

---

## 7. 기존 시스템과의 관계

```
┌─────────────────────────────────────────────────────┐
│                    씬 계층 구조                       │
│                                                      │
│  [Option A: 기존 WFC]                                │
│    WFCGenerator (MonoBehaviour)                      │
│    └─ Generated_3D_Dungeon                           │
│       ├─ Tile(0,0,0) ─ 44m 간격 그리드              │
│       ├─ Tile(1,0,0)                                │
│       └─ ...                                         │
│                                                      │
│  [Option B: 새 레이아웃 시스템]                       │
│    DungeonLayoutGenerator (MonoBehaviour)             │
│    └─ Generated_Dungeon                              │
│       ├─ Room_0_StartRoom   ─ 연속 좌표 배치         │
│       ├─ Room_1_NormalRoom                           │
│       ├─ Corridor_0_1       ─ (MAP-02에서 생성)      │
│       └─ ...                                         │
│                                                      │
│  ※ 두 시스템은 같은 씬에 공존 가능하나,              │
│    동시에 활성화하면 안 됨.                            │
│    씬에 하나의 Generator만 배치하여 사용한다.          │
└─────────────────────────────────────────────────────┘
```

### 재사용 요소 (Tile.cs에서)

| 요소 | 재사용 방식 |
|------|------------|
| `TileType` enum | `RoomNode.tileType`으로 직접 사용 |
| `RoomFlavor` enum | `RoomNode.roomFlavor`로 직접 사용 (MAP-03에서 배정) |
| `ObjectiveType` enum | 룸 인스턴스화 후 기존 로직과 동일하게 배정 |
| `isDangerous` 로직 | `RoomNode.isDangerous` — TileType 기반 동일 규칙 적용 |
| `RoomStateManager` | MAP-01 생성 완료 후 동일하게 `RegisterRoom()` 호출 |
| `RoomPreset` SO | MAP-03에서 룸 내부 장식 시 동일 프리셋 시스템 사용 |

### 건드리지 않는 파일

- `WFCGenerator.cs` — 수정 없음
- `Cell.cs` — 수정 없음 (WFC 전용)
- `Tile.cs` — 수정 없음 (enum은 이미 충분)
- `RoomPreset.cs` — 수정 없음
- `RoomStateManager.cs` — 수정 없음 (MAP-01에서 동일 인터페이스로 호출)
- `WFCPrefabBuilder.cs` — 수정 없음

---

## 8. 생성 파이프라인 (전체 흐름)

```
[DungeonLayoutGenerator.BakeLayout()]
│
├─ Phase 1: PlaceRooms()
│   ├─ StartRoom → 맵 가장자리 랜덤
│   ├─ ExitRoom  → 맨해튼 거리 최대 반대편 가장자리
│   ├─ SpecialRoom x1~3 → 랜덤 배치 (최소 간격 보장)
│   ├─ NormalRoom x1~7 → 랜덤 배치 (최소 간격 보장)
│   ├─ ObjectiveRoom x1~2 → 랜덤 배치 (최소 간격 보장)
│   └─ 배치 실패 시 해당 룸 스킵 (최소 룸 수 미달 시 전체 재시도)
│
├─ Phase 2: DelaunayTriangulation.Triangulate(rooms[].center)
│   └─ Bowyer-Watson → 삼각형 리스트 → 고유 엣지 리스트
│
├─ Phase 3: MST + Extra Edges
│   ├─ Kruskal MST (Union-Find, 길이 오름차순)
│   └─ 비MST 엣지 중 extraEdgeRatio 비율 랜덤 추가
│
├─ Phase 4: ValidateLayout()
│   ├─ BFS: StartRoom → ExitRoom 경로 존재 확인
│   ├─ BFS: 모든 룸 도달 가능 확인 (고립 룸 없음)
│   └─ SpecialRoom 최소 1개 도달 가능 확인
│
├─ 성공:
│   ├─ _layout에 결과 저장
│   ├─ Console 로그: "[MAP] Delaunay edges: N, MST edges: M, final corridors: K"
│   └─ DungeonLayout 반환
│
└─ 실패 (maxRetries 초과):
    ├─ Console 에러: "[MAP] Layout generation failed after N retries"
    └─ null 반환
```

---

## 9. 최소 간격 (Spacing) 상세 설계

기존 WFC의 핵심 문제는 "문 열면 바로 문이 보이는" 현상이었다. 이를 구조적으로 방지한다.

### 간격 공식

```
requiredGap(roomA, roomB) =
    halfExtentA + halfExtentB + corridorMinLength

여기서:
    halfExtentA = max(roomA.size.x, roomA.size.y) / 2
    halfExtentB = max(roomB.size.x, roomB.size.y) / 2
```

### AABB 기반 간격 검사

```csharp
private bool IsSpacingValid(List<RoomNode> existing, Vector2 candidate, Vector2 candidateSize)
{
    Vector2 halfCandidate = candidateSize / 2f;
    
    for (int i = 0; i < existing.Count; i++)
    {
        Vector2 halfExisting = existing[i].size / 2f;
        
        // 축 분리 거리 계산
        float dx = Mathf.Abs(candidate.x - existing[i].center.x);
        float dz = Mathf.Abs(candidate.y - existing[i].center.y);
        
        float requiredX = halfCandidate.x + halfExisting.x + corridorMinLength;
        float requiredZ = halfCandidate.y + halfExisting.y + corridorMinLength;
        
        // 두 축 모두 충분히 떨어져 있어야 겹치지 않음
        // → 한 축이라도 겹치면 다른 축에서 충분한 간격 필요
        if (dx < requiredX && dz < requiredZ)
            return false;
    }
    return true;
}
```

---

## 10. 가장자리 배치 로직 (Start/Exit)

```csharp
private Vector2 RandomEdgePosition()
{
    float margin = corridorMinLength;  // 맵 경계에서 룸 중심까지 최소 여백
    int side = Random.Range(0, 4);     // 0=N, 1=E, 2=S, 3=W
    
    switch (side)
    {
        case 0: return new Vector2(Random.Range(margin, mapSize.x - margin), mapSize.y - margin);
        case 1: return new Vector2(mapSize.x - margin, Random.Range(margin, mapSize.y - margin));
        case 2: return new Vector2(Random.Range(margin, mapSize.x - margin), margin);
        case 3: return new Vector2(margin, Random.Range(margin, mapSize.y - margin));
    }
}

private Vector2 FarthestEdgeFrom(Vector2 origin)
{
    // origin이 속한 변의 반대편 변에서 랜덤 점 선택
    // 예: origin이 남쪽(y≈0) → 북쪽 변(y≈mapSize.y)에서 선택
}
```

---

## 11. 로그 출력 규격

검증 기준에 명시된 로그 형식을 준수한다.

```
[MAP] Room placement: 14 rooms in 300x300 map (attempts: 3)
[MAP] Delaunay edges: 35, MST edges: 13, final corridors: 16
[MAP] BFS validation: StartRoom(0) → ExitRoom(5) path OK, all 14 rooms reachable
[MAP] Layout generation SUCCESS (retry: 1/50)
```

실패 시:
```
[MAP] Layout generation FAILED after 50 retries
```

---

## 12. Gizmo 시각화 (에디터 디버그)

`OnDrawGizmos()`에서 씬 뷰에 레이아웃을 그려 육안 검증한다.

| 요소 | 색상 | 형태 |
|------|------|------|
| StartRoom | 파랑 (`Color.blue`) | 와이어 큐브 + 구체 |
| ExitRoom | 빨강 (`Color.red`) | 와이어 큐브 + 구체 |
| NormalRoom | 주황 (`new Color(1, 0.5f, 0)`) | 와이어 큐브 |
| ObjectiveRoom | 보라 (`Color.magenta`) | 와이어 큐브 |
| SpecialRoom | 노랑 (`Color.yellow`) | 와이어 큐브 |
| Delaunay 전체 엣지 | 회색 반투명 | 가는 선 |
| MST 엣지 | 노랑 | 굵은 선 |
| 최종 복도 (MST+extra) | 초록 (`Color.green`) | 굵은 선 |

---

## 13. 검증 방법

### 13.1 에디터 검증 (MAP-01 verification 기준)

```
에디터에서 Bake 10회 실행 시 10/10 성공. 각 결과에서:
(1) 모든 룸이 최소 간격 이상 떨어져 있고
(2) StartRoom → ExitRoom BFS 경로 존재
(3) Console에 '[MAP] Delaunay edges: N, MST edges: M, final corridors: K' 로그 출력
```

**수행 절차:**
1. 씬에 빈 GameObject 생성, `DungeonLayoutGenerator` 컴포넌트 부착
2. Inspector에서 기본값 확인 (roomCount=14, mapSize=300x300)
3. ContextMenu → "Bake Dungeon Layout (Editor Mode)" 10회 실행
4. 매 실행마다 Console 로그 확인
5. `drawGizmos=true`로 씬 뷰에서 레이아웃 시각 확인

### 13.2 자동 검증 (BakeLayout 내부)

```csharp
// 간격 검증 — 모든 룸 쌍에 대해 최소 간격 확인
private bool ValidateSpacing(List<RoomNode> rooms)
{
    for (int i = 0; i < rooms.Count; i++)
    for (int j = i + 1; j < rooms.Count; j++)
    {
        float dx = Mathf.Abs(rooms[i].center.x - rooms[j].center.x);
        float dz = Mathf.Abs(rooms[i].center.y - rooms[j].center.y);
        float reqX = rooms[i].size.x/2 + rooms[j].size.x/2 + corridorMinLength;
        float reqZ = rooms[i].size.y/2 + rooms[j].size.y/2 + corridorMinLength;
        if (dx < reqX && dz < reqZ)
            return false;
    }
    return true;
}
```

### 13.3 씬 뷰 Gizmo 육안 확인 항목

- [ ] 룸 박스가 서로 겹치지 않는가
- [ ] 복도 선이 룸을 관통하지 않고 연결하는가
- [ ] StartRoom(파랑)과 ExitRoom(빨강)이 맵 반대편에 위치하는가
- [ ] 고립된 룸(복도 연결 없음)이 없는가
- [ ] 복도 그래프에 루프(순환)가 적절히 존재하는가

---

## 14. 위험 요소 및 완화 방안

| 위험 | 영향 | 완화 |
|------|------|------|
| 룸 배치 실패 (밀도 과다) | 전체 재시도 | mapSize 대비 roomCount 비율 검증. maxPlacementAttempts=30으로 개별 룸 스킵 허용 |
| Delaunay 동일점/공선점 | 알고리즘 실패 | 최소 간격이 동일점 방지. 공선점은 epsilon 비교로 방어 |
| MST 연결성 보장 실패 | StartRoom→ExitRoom 불통 | MST는 정의상 전체 연결. Phase 4 BFS는 구현 버그 안전장치 |
| 복도가 다른 룸 관통 | 비현실적 레이아웃 | MAP-02에서 복도 경로 계산 시 룸 AABB 회피 로직 적용 (MAP-01 스코프 외) |
| 기존 WFC 시스템과 충돌 | 씬 혼란 | 동일 씬에 하나의 Generator만 배치. 컨테이너 이름 분리 |

---

## 15. 후속 태스크 연결점

| 후속 | DungeonLayout에서 사용하는 데이터 |
|------|----------------------------------|
| **MAP-02** (복도 지오메트리) | `CorridorEdge.roomA/roomB` + `RoomNode.center/size` → L자형 복도 메시 생성 |
| **MAP-03** (룸 내부 장식) | `RoomNode.tileType/roomFlavor` → RoomPreset 매칭 + WFCPrefabBuilder 호출 |
| **RoomStateManager 연동** | `RoomNode.id` → `Vector3Int(id, 0, 0)` 또는 별도 키로 `RegisterRoom()` 호출 |

---

## 16. 예상 출력 예시 (14개 룸)

```
룸 배치 (300x300 맵):
  Room 0: StartRoom     center=(30, 270)  size=(40,40)
  Room 1: ExitRoom      center=(260, 40)  size=(40,40)
  Room 2: SpecialRoom   center=(150, 200) size=(24,24)
  Room 3: NormalRoom    center=(80, 180)  size=(40,40)
  Room 4: NormalRoom    center=(200, 250) size=(40,40)
  Room 5: ObjectiveRoom center=(120, 80)  size=(40,40)
  ...

Delaunay 삼각분할: 35 엣지
MST: 13 엣지
추가 엣지: 3 (15% of 22 non-MST)
최종 복도: 16

BFS 검증:
  StartRoom(0) → [0, 3, 2, 4, 7, 6, 5, 1, ...] → ExitRoom(1) OK
  전체 14/14 룸 도달 가능
```
