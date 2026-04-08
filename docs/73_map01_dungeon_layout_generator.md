# 73. MAP-01: 던전 레이아웃 생성기 (Delaunay Triangulation)

## 세션 목표
연속 2D 공간에 룸을 최소 간격으로 랜덤 배치한 뒤, Delaunay 삼각분할로 연결 후보를 구하고 MST+α 엣지를 선택하여 StartRoom→ExitRoom 경로가 보장되는 복도 그래프를 생성한다. 기존 WFC 그리드 레이아웃을 대체하는 매크로 레이아웃 시스템의 첫 단계이다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs` | **신규** — `RoomNode`, `CorridorEdge`, `DungeonLayout` 데이터 클래스. 룸 ID/타입/중심좌표/크기, 복도 양끝 룸/길이/MST 여부를 직렬화 가능하게 정의 |
| `Assets/Scripts/Map/Dungeon/DelaunayTriangulation.cs` | **신규** — Bowyer-Watson 알고리즘 기반 2D Delaunay 삼각분할 static 유틸리티. Unity API 의존 없음(Vector2만 사용). super-triangle 삽입 → 점 순차 삽입 → 경계 다각형 재구성 → super-triangle 정점 포함 삼각형 제거 → 고유 엣지 추출 |
| `Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs` | **신규** — MonoBehaviour 오케스트레이터. 4 Phase 파이프라인으로 레이아웃 생성 (배치 → 삼각분할 → MST+α → 검증). `[ContextMenu]` Bake 및 Gizmo 디버그 지원 |
| `Assets/Tests/PlayMode/MAP01_Tests.cs` | **신규** — 9개 PlayMode 테스트 (Delaunay 3점/4점/14점, BakeLayout 비null, Start/Exit 존재, 최소 간격, BFS 연결성, SpecialRoom 존재, 로그 포맷) |

---

## 핵심 설계

### 4 Phase 파이프라인

| Phase | 이름 | 역할 |
|-------|------|------|
| 1 | Room Placement | 포아송 디스크 변형으로 룸 배치. StartRoom→맵 가장자리, ExitRoom→StartRoom 반대편 가장자리, SpecialRoom 최소 1개 보장. 쿼터 기반 TileType 할당 (NormalRoom 가중치 2배) |
| 2 | Delaunay Triangulation | 룸 중심점 배열을 `DelaunayTriangulation.Triangulate()`에 전달하여 연결 후보 엣지 생성 |
| 3 | MST + Extra Edges | Kruskal 알고리즘(Union-Find, 경로 압축)으로 MST 추출 후, 비MST 엣지를 Fisher-Yates 셔플하여 `extraEdgeRatio` 비율만큼 추가 |
| 4 | Validation | BFS로 StartRoom→ExitRoom 경로 존재, 모든 룸 도달 가능, SpecialRoom 최소 1개 도달 가능 확인. 실패 시 Phase 1부터 재시도 (최대 `maxRetries`회) |

### 간격 검증 (IsSpacingValid)
두 룸의 AABB 절반 크기 합 + `corridorMinLength`를 X/Z 축 각각 비교. 양쪽 축 모두 기준 미만이면 겹침으로 판정하여 배치 거부. 이 방식으로 문-문 직결 없이 최소 복도 공간을 구조적으로 보장한다.

### Bowyer-Watson 알고리즘 상세
1. 모든 점을 포함하는 super-triangle 생성 (바운딩 박스 × 20배 마진)
2. 각 점을 순차 삽입하며 외접원 내부 삼각형(bad triangle) 탐지
3. bad triangle의 비공유 변(경계 다각형)으로 새 삼각형 재구성
4. 공선점(degenerate) 방어: 행렬식 `|d| < 1e-10` 시 외접반경을 `float.MaxValue`로 설정
5. 최종적으로 super-triangle 정점을 포함하는 삼각형 제거 후 고유 엣지 반환

### 데이터 구조
- `RoomNode`: id, tileType, center(Vector2), size(Vector2), isDangerous, roomFlavor
- `CorridorEdge`: roomA, roomB, length, isMST
- `DungeonLayout`: rooms, corridors, startRoomId, exitRoomId
- `DelaunayTriangulation.Edge`: 정규화된 (a < b) 정수 쌍, 커스텀 해시

---

## testplay 검증
- **실행 명령어**: `testplay run --shadow --filter MAP01_Tests`
- **실행 결과**: 통과 (Exit 0), 9/9 PASS
- **검증 내용**:
  - Delaunay 삼각분할 정확성: 3점(엣지 3개), 4점(엣지 5~6개), 14점(엣지 13~36개 범위)
  - BakeLayout이 maxRetries 내에 유효한 레이아웃을 생성함을 확인
  - StartRoom/ExitRoom ID가 유효하고 올바른 TileType을 가짐을 확인
  - 모든 룸 쌍 간 corridorMinLength(12m) 이상 간격 보장 확인
  - BFS 탐색 시 StartRoom에서 ExitRoom까지 경로 존재 확인
  - SpecialRoom 최소 1개 존재 확인
  - `[MAP] Delaunay edges:`, `[MAP] BFS validation:`, `[MAP] Room placement:`, `[MAP] Layout generation SUCCESS` 로그 출력 확인

---

## 검증 절차

1. Scene에 빈 GameObject 생성 후 `DungeonLayoutGenerator` 컴포넌트 추가
2. Inspector에서 파라미터 확인 (mapSize=300x300, roomCount=14, corridorMinLength=12)
3. Component 우클릭 → `Bake Dungeon Layout` 10회 실행
4. 매 실행마다 Console에서 `[MAP] Delaunay edges: N, MST edges: M, final corridors: K` 로그 출력 확인
5. Scene View에서 Gizmo 확인: 룸 와이어 큐브(색상별 타입 구분), Delaunay 전체 엣지(회색), MST(노랑), 추가 복도(초록)
6. 10/10 성공 확인 → feature_list.json MAP-01 → `done`

---

## 주의 사항
- `DungeonLayoutGenerator`는 현재 2D 좌표(Vector2)로 레이아웃을 생성하며, 실제 3D 프리팹 배치(MAP-02)와의 좌표 매핑은 XZ 평면 기준 (center.x → X, center.y → Z)
- `extraEdgeRatio = 0.15f`는 15%의 비MST 엣지를 추가하여 순환 경로를 생성한다. 이 값이 0이면 순수 트리(단일 경로), 1이면 Delaunay 전체 엣지를 사용
- `maxRetries = 50` 내에 배치가 불가능할 경우(맵 크기 대비 룸 수/크기가 과다한 경우) null을 반환하므로, 호출부에서 null 처리 필요
- `DelaunayTriangulation.Edge`의 해시 함수는 소수 기반 XOR로, 극단적 케이스에서 충돌 가능성이 있으나 실용 범위(~30개 룸)에서는 문제없음
- `Random.Range` 사용으로 재현 가능한 시드 제어가 불가능. 추후 시드 기반 생성이 필요할 경우 별도 `System.Random` 인스턴스 도입 필요

---

## 다음 권장 태스크
- **MAP-02**: 복도 메시 생성 — DungeonLayout의 CorridorEdge 데이터를 기반으로 실제 3D 복도 프리팹을 배치하고 룸 프리팹을 인스턴스화하는 단계
- **MAP-03**: 룸 내부 장식 통합 — 배치된 각 룸 프리팹 내부를 기존 WFC 소품 배치 또는 RoomPreset 프리셋으로 장식하여 매크로 레이아웃과 룸 인테리어를 분리 연결
