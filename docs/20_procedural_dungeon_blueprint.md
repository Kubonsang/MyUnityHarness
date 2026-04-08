# 20. 절차적 던전 생성 시스템 — 수제 방 프리팹 + 절차적 연결

> 설계 문서. feature_list.json 태스크 분해의 기반이 된다.

---

## 1. 목표

플레이어가 매 세션마다 다른 던전을 경험하되, 각 방의 품질은 사람이 보증한다.

```
[사람이 만든 방 프리팹 Pool]
        ↓  절차적 선택 & 배치
[DungeonBuilder 런타임 생성]
        ↓  Connection Point 정합
[복도 프리팹/자동 생성으로 연결]
        ↓
[플레이 가능한 던전]
```

---

## 2. 핵심 개념

### 2.1 Room Prefab
- 사람이 Unity 에디터에서 직접 제작한 방 프리팹
- KayKit 타일(4×4m 기반) + 소품 + 조명 + 벽/천장 포함
- 방 크기: **소형 12×12m (3×3)**, **중형 20×20m (5×5)**, **대형 28×28m (7×7)** 등 자유
- 각 방에 `DungeonRoom` 컴포넌트 부착 — 메타데이터 + Connection Point 목록

### 2.2 Connection Point
- 방의 출입구 위치를 나타내는 마커
- **빈 GameObject** + `ConnectionPoint` 컴포넌트
- 방향(N/E/S/W), 폭(1칸=4m 기본), 월드 위치를 제공
- 방 프리팹의 자식으로 배치 — 에디터에서 Gizmo로 시각화

### 2.3 Corridor
- 두 Connection Point를 잇는 통로
- **방안 A: 복도 프리팹** — 직선/L자/T자 복도를 미리 만들어 조합
- **방안 B: 절차적 복도 생성** — 기존 WFCPrefabBuilder의 벽/바닥 배치 로직 재활용
- 초기에는 **방안 B** 채택 (WFC 코드 재활용, 별도 프리팹 불필요)

---

## 3. 컴포넌트 설계

### 3.1 DungeonRoom (MonoBehaviour — 방 프리팹 루트에 부착)

```csharp
public class DungeonRoom : MonoBehaviour
{
    [Header("Room Identity")]
    public TileType roomType = TileType.NormalRoom;
    public RoomFlavor roomFlavor = RoomFlavor.None;
    public bool isDangerous = true;

    [Header("Bounds")]
    public Vector2Int roomSize = new Vector2Int(5, 5); // 타일 단위 (5=20m)

    [Header("Connection Points")]
    public List<ConnectionPoint> connectionPoints;
}
```

### 3.2 ConnectionPoint (MonoBehaviour — DungeonRoom 자식 GameObject에 부착)

```csharp
public enum CardinalDirection { North, East, South, West }

public class ConnectionPoint : MonoBehaviour
{
    public CardinalDirection direction;
    public int widthInTiles = 1;            // doorway 폭 (1=4m)
    [HideInInspector] public bool connected = false;

    // 런타임: 연결된 상대 ConnectionPoint (복도 반대편)
    [System.NonSerialized] public ConnectionPoint linkedPoint;

    private void OnDrawGizmos()
    {
        Gizmos.color = connected ? Color.green : Color.yellow;
        Gizmos.DrawWireSphere(transform.position, 0.5f);
        Gizmos.DrawRay(transform.position, DirectionVector() * 2f);
    }

    public Vector3 DirectionVector()
    {
        return direction switch {
            CardinalDirection.North => Vector3.forward,
            CardinalDirection.East  => Vector3.right,
            CardinalDirection.South => Vector3.back,
            CardinalDirection.West  => Vector3.left,
            _ => Vector3.forward
        };
    }
}
```

### 3.3 DungeonRoomPool (ScriptableObject — 방 프리팹 Pool)

```csharp
[CreateAssetMenu(menuName = "Dungeon/Room Pool")]
public class DungeonRoomPool : ScriptableObject
{
    [System.Serializable]
    public class RoomEntry
    {
        public GameObject prefab;           // DungeonRoom 컴포넌트 필수
        public int weight = 10;             // 선택 가중치
    }

    public List<RoomEntry> rooms;
}
```

### 3.4 DungeonConfig (ScriptableObject — 던전 생성 규칙)

```csharp
[CreateAssetMenu(menuName = "Dungeon/Config")]
public class DungeonConfig : ScriptableObject
{
    [Header("Room Counts")]
    public int totalRoomCount = 15;         // 목표 방 수 (복도 제외)
    public int minNormalRoom  = 5;
    public int maxNormalRoom  = 8;
    public int minSpecialRoom = 2;
    public int maxSpecialRoom = 3;
    public int objectiveRoomCount = 2;
    public int startRoomCount = 1;
    public int exitRoomCount  = 1;

    [Header("Layout")]
    public float tileSize = 4f;             // 기본 타일 크기
    public int corridorMaxLength = 3;       // 복도 최대 타일 길이
    public float gridCellSize = 20f;        // 배치 그리드 셀 크기 (방 최소 간격)
}
```

### 3.5 DungeonBuilder (MonoBehaviour — 씬에 1개)

```
역할: 런타임(또는 에디터 Bake)에서 절차적 던전 생성
WFCGenerator를 대체. 기존 RoomStateManager/ObjectiveType은 그대로 재사용.
```

---

## 4. 생성 알고리즘 — 성장형 (Growth-based)

StartRoom에서 시작해 BFS로 방을 하나씩 확장한다. WFC보다 제어가 쉽고, 연결성이 자동 보장된다.

### 4.1 전체 흐름

```
1. 그리드 초기화 (2D 정수 좌표, 충분히 큰 범위)
2. StartRoom 배치 → (0,0)
3. openList = StartRoom의 미연결 ConnectionPoint들
4. while (배치된 방 수 < 목표) and (openList 비어있지 않음):
     a. openList에서 Connection Point 하나 꺼냄
     b. 해당 방향으로 인접 그리드 좌표 계산
     c. 좌표가 비어있고, 충돌 없으면:
         - 필요 TileType 결정 (남은 quota 기반)
         - 해당 타입의 방 프리팹 Pool에서 가중치 랜덤 선택
         - 선택된 방에서 반대 방향 ConnectionPoint 보유 여부 확인
         - 방 배치 → 두 ConnectionPoint 연결
         - 새 방의 나머지 미연결 CP를 openList에 추가
     d. 좌표가 점유됨 → 이미 놓인 방의 같은 면에 CP가 있으면 연결
5. 미연결 ConnectionPoint에 벽 마감 처리
6. 연결된 CP 쌍 사이에 복도 생성
7. RoomStateManager 초기화
8. ObjectiveType 랜덤 배정
9. SpectatorCamera 스폰
```

### 4.2 그리드 좌표 체계

```
- 각 방이 정수 좌표(x, z)를 점유
- 대형 방(7×7)은 여러 셀 점유 → OccupiedCells 목록
- 소형(3×3) 방도 1셀 = 최소 20m 간격으로 배치
- 복도는 셀 사이 연결선 (방 셀 아님)
```

### 4.3 방 배치 충돌 검사

```csharp
// 의사코드
bool CanPlace(Vector2Int gridPos, DungeonRoom room)
{
    foreach (셀 in room이 점유할 그리드 셀들)
        if (해당 셀이 이미 점유됨) return false;
    return true;
}
```

### 4.4 방향 정합 규칙

- North CP ↔ South CP 연결 (N+S, E+W)
- 연결되지 않은 CP → 벽으로 마감 (wall.fbx 배치 or 프리팹 내 벽 활성화)
- ExitRoom은 던전 외곽에만 배치 (마지막에 배치)

---

## 5. 복도 생성 (WFC 코드 재활용)

### 5.1 직선 복도

```
두 CP 사이 거리 측정 (항상 그리드 인접이므로 1셀 = 20m 간격)
→ 복도 길이 = 두 CP 사이 실제 거리 (방 크기에 따라 가변)
→ WFCPrefabBuilder의 바닥/벽/천장 배치 로직으로 복도 구간 채움
→ 양 끝에 wall_doorway.fbx
```

### 5.2 초기 구현

- 복도는 항상 **직선** (L자/T자는 향후 확장)
- 복도 폭 = 1타일(4m) 고정
- 벽 2단(8m 높이) + 천장 + 바닥
- 횃불 간헐적 배치 (기존 PlaceWallDecorated 재활용)

---

## 6. 방 프리팹 제작 가이드라인

### 6.1 필수 규격

| 항목 | 규격 |
|------|------|
| 바닥 원점 | (0, 0, 0) — 방 중심이 로컬 원점 |
| 바닥 타일 | 4×4m KayKit floor 타일 |
| 벽 | 4×4m wall.fbx 기반, 2단(8m) 높이 |
| 천장 | ceiling_tile.fbx, Y=8m |
| 바닥 표면 Y | +0.11m (floor_dirt_large.fbx 기준) |
| 기둥 | pillar.fbx, 2단 적층, 모서리 배치 |

### 6.2 Connection Point 배치

```
방 면의 중앙에 빈 GameObject 생성
→ ConnectionPoint 컴포넌트 추가
→ 방향(direction) 설정
→ 위치: 벽면 중앙, 바닥 Y=0
→ 해당 위치에 wall_doorway.fbx 또는 아치 배치

예: 20×20m 방의 North CP
  위치 = (0, 0, 10)  // 북쪽 벽면 중앙
  direction = North
```

### 6.3 WFC 활용 워크플로우

```
1. WFC/Build 3D WFC Prefabs 실행 → 프리팹 자동 생성
2. 생성된 프리팹을 씬에 놓고 수동 편집 (소품 배치, 조명 등)
3. DungeonRoom + ConnectionPoint 컴포넌트 부착
4. 완성된 프리팹을 Assets/Prefabs/DungeonRooms/ 에 저장
5. DungeonRoomPool SO에 등록
```

---

## 7. 기존 시스템 재활용 매핑

| 기존 | 신규 | 비고 |
|------|------|------|
| TileType enum | 그대로 사용 | DungeonRoom.roomType |
| RoomFlavor enum | 그대로 사용 | DungeonRoom.roomFlavor |
| ObjectiveType enum | 그대로 사용 | DungeonBuilder에서 배정 |
| RoomStateManager | 그대로 사용 | RegisterRoom 인터페이스 동일 |
| isDangerous | 그대로 사용 | DungeonRoom.isDangerous |
| SpectatorCamera | 그대로 사용 | DungeonBuilder에서 스폰 |
| WFCPrefabBuilder | 프리팹 제작 참고용으로 유지 | 런타임에는 사용 안 함 |
| WFCGenerator | 프리팹 제작 참고용으로 유지 | DungeonBuilder로 대체 |
| Cell.cs / Tile.cs | 프리팹 제작 참고용으로 유지 | 신규 시스템에서 미사용 |

---

## 8. 디렉토리 구조 (예상)

```
Assets/Scripts/Map/
├── WFC/                              ← 유지 (프리팹 제작용)
│   ├── Cell.cs
│   ├── Tile.cs
│   ├── WFCGenerator.cs
│   ├── RoomPreset.cs
│   ├── RoomStateManager.cs          ← 공용, 이동 가능
│   └── SpectatorCamera.cs           ← 공용, 이동 가능
├── Dungeon/                          ← 신규
│   ├── DungeonRoom.cs
│   ├── ConnectionPoint.cs
│   ├── DungeonRoomPool.cs
│   ├── DungeonConfig.cs
│   ├── DungeonBuilder.cs
│   └── CorridorBuilder.cs           ← 복도 생성 전담
Assets/Prefabs/
├── DungeonRooms/                     ← 수제 방 프리팹
│   ├── NormalRoom_Barracks_A.prefab
│   ├── NormalRoom_Storage_B.prefab
│   ├── SpecialRoom_Treasure_A.prefab
│   ├── StartRoom_Camp_A.prefab
│   ├── ExitRoom_Gate_A.prefab
│   └── ...
├── WFC/                              ← 유지 (WFC 자동생성 프리팹)
Assets/Data/
├── DungeonConfig_Default.asset
├── RoomPool_Normal.asset
├── RoomPool_Special.asset
└── RoomPool_Start.asset
```

---

## 9. 주의사항 & 제약

1. **그리드 스냅 필수** — 방 배치는 정수 그리드 좌표 기반. 자유 배치하면 복도 연결이 복잡해짐.
2. **방 크기 혼합** — 소형/중형/대형 방 혼합 시 그리드 셀 점유 계산 필요. 초기에는 **중형(5×5=20m) 단일 크기** 권장.
3. **복도 교차** — 초기에는 복도 간 교차 미지원. 성장형 알고리즘이 인접 셀만 연결하므로 자연스럽게 회피됨.
4. **Netcode 호환** — DungeonBuilder는 서버에서만 실행. 생성된 프리팹은 PrefabUtility가 아닌 `NetworkObject.Spawn()` 또는 씬 내 정적 배치로 처리.
5. **WFC 유지** — WFCPrefabBuilder, WFCGenerator는 삭제하지 않음. 방 프리팹 제작 시 참고/초안용으로 계속 사용.

---

## 10. 구현 단계 (feature_list 태스크 후보)

| 순서 | ID 후보 | 태스크 | 의존 |
|------|---------|--------|------|
| 1 | DUNG-01 | `DungeonRoom`, `ConnectionPoint` 컴포넌트 생성 + Gizmo | 없음 |
| 2 | DUNG-02 | `DungeonRoomPool`, `DungeonConfig` SO 생성 | 없음 |
| 3 | DUNG-03 | `DungeonBuilder` 성장형 알고리즘 (방 배치 + 그리드 관리) | DUNG-01, 02 |
| 4 | DUNG-04 | `CorridorBuilder` 직선 복도 생성 (WFC 바닥/벽 로직 재활용) | DUNG-03 |
| 5 | DUNG-05 | 미연결 CP 벽 마감 + RoomStateManager/ObjectiveType 통합 | DUNG-04 |
| 6 | DUNG-06 | 수제 방 프리팹 최소 세트 제작 (TileType별 1개씩) | DUNG-01 |
| 7 | DUNG-07 | 에디터 Bake + SpectatorCamera 통합 검증 | DUNG-05, 06 |
| 8 | DUNG-08 | ExitRoom 외곽 배치 제약 + 전체 연결성 보장 검증 | DUNG-07 |

---

## 11. 향후 확장 (현재 구현 범위 외)

- L자/T자 복도
- 대형 방(7×7) 혼합 배치
- 방 내부 이벤트 트리거 (MonsterSpawner 연동)
- 복도 함정/장애물
- 미니맵 연동
- 멀티 층 던전 (계단 Connection Point)
