# 70. WFC-08: 연결 보장형 던전 골격 생성

## 세션 목표
WFC 알고리즘에 2단계 생성 방식을 도입한다. Phase 1에서 StartRoom→Corridor→ExitRoom 경로(골격)를 먼저 확정하고, Phase 2에서 나머지 셀을 기존 WFC로 채워 구조적으로 연결을 보장한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/WFC/Cell.cs` | `ForceCollapse(Tile)` 메서드 추가 — 외부에서 특정 타일로 강제 확정 |
| `Assets/Scripts/Map/WFC/WFCGenerator.cs` | 골격 생성 시스템 추가 (SkeletonNode 구조체 + 7개 메서드), `maxCorridor` 5→12, `GenerateDungeonSync`/`GenerateDungeonRoutine`에 골격 호출 삽입 |
| `Assets/Tests/PlayMode/WFC08_Tests.cs` | 골격 생성 검증 테스트 7종 신규 작성 |

---

## 핵심 설계

### 2단계 생성 방식 (Skeleton-First WFC)

#### Phase 1: 골격 생성 (`GenerateSkeleton`)
1. **StartRoom 배치**: 랜덤 가장자리(edge) 셀 선택
2. **ExitRoom 배치**: StartRoom에서 맨해튼 거리 최대인 가장자리 셀 선택
3. **경로 생성**: `BuildPath`로 랜덤 DFS 경로 탐색 (70% 출구 방향 편향, 30% 우회)
4. **SpecialRoom 분기**: 경로 중간 셀에서 1칸 분기하여 배치
5. **타일 매칭**: `FindMatchingTile`로 입구 방향과 소켓 패턴이 정확히 일치하는 타일 변형(A/B 랜덤) 검색
6. **강제 붕괴**: `Cell.ForceCollapse` → `RecordAndEnforce` → `Propagate` 순서로 골격 셀 확정 및 제약 전파

#### Phase 2: WFC 채움 (기존 로직 그대로)
- 골격 셀은 이미 `collapsed=true` → `GetLowest()`가 자연스럽게 스킵
- 나머지 셀은 기존 WFC 루프(Collapse → RecordAndEnforce → Propagate)로 채움
- `Validate` → `PruneIsolatedCells` → `InstantiateDungeon` 순서 유지

### 타일 소켓 매핑

| 입구 수 | 패턴 | 타일 종류 |
|---------|------|-----------|
| 1 | 단방향 | Room (Start/Exit/Normal/Special/Objective) |
| 2 | 대향 (N+S, E+W) | Corridor (직선) |
| 2 | 직교 (N+E, E+S 등) | Corner |
| 3 | 3방향 | T-Intersection |
| 4 | 전방향 | Cross |

### maxCorridor 상향 (5→12)
골격 경로(3~7개 복도) + WFC 채움분 여유를 위해 기본값 상향. 5×5 그리드(25셀) 기준 적정 수준.

### 새로 추가된 메서드

| 메서드 | 역할 |
|--------|------|
| `GenerateSkeleton()` | 골격 오케스트레이터 — 경로 생성~강제 붕괴~모순 검사 |
| `BuildPath(from, to)` | 랜덤 DFS + 백트래킹 경로 탐색 |
| `FindMatchingTile(type, dirs)` | TileType + 입구 소켓 패턴 매칭 (A/B 랜덤 선택) |
| `GetEdgeCells()` | 그리드 가장자리 셀 수집 |
| `ComputeEntranceDirs(path, index, branches)` | 경로 인덱스별 입구 방향 계산 |
| `GetDirection(from, to)` | 두 좌표 간 방향(0~3) 계산 |
| `Shuffle<T>(list)` | Fisher-Yates 셔플 |

---

## testplay 검증
- **실행 명령어**: `testplay run --shadow --filter WFC08_Tests`
- **실행 결과**: Exit 0, 테스트 7/7 PASS

### 테스트 항목

| 테스트 | 검증 내용 |
|--------|-----------|
| `Cell_ForceCollapse_SetsCollapsedTrueAndSingleAvailableTile` | ForceCollapse 후 collapsed=true, availableTiles=1 |
| `Cell_ForceCollapse_EntropyShouldBeOne` | ForceCollapse 후 GetEntropy==1 |
| `GenerateSkeleton_PlacesStartExitAndSpecialRoom_WithinRetries` | 5×5 그리드에서 Start/Exit/Special/Corridor 전부 배치 |
| `GenerateSkeleton_ExitRoom_AlwaysOnEdgeCell` | ExitRoom이 반드시 가장자리 셀에 위치 |
| `GenerateSkeleton_StartToExit_EntranceChainConnected` | StartRoom→ExitRoom BFS Entrance 체인 연결 보장 |
| `GenerateSkeleton_MinGrid3x3_SucceedsWithinRetries` | 최소 3×3 그리드 성공 |
| `GenerateSkeleton_LargeGrid7x7_SucceedsWithinRetries` | 7×7 그리드 성공 |

---

## 검증 절차
1. testplay run --shadow 실행하여 컴파일 에러 없음 확인
2. testplay run --shadow --filter WFC08_Tests 로 골격 생성 테스트 7/7 PASS 확인
3. 에디터에서 WFC > Bake Dungeon 20회 연속 실행 시 20/20 성공 확인 필요 (사용자 수동)
4. 각 결과에서 Console 로그 `[WFC-Skeleton]` 골격 생성 완료 메시지 확인

---

## 주의 사항
- maxCorridor 12는 5×5 기준 설정값 — 그리드 크기 변경 시 비례 조정 필요
- 골격 경로 길이는 `gridWidth + gridDepth + 3`으로 제한되어 과도한 우회 방지
- BuildPath의 70/30 편향은 경로 다양성과 효율성의 균형점이며 튜닝 가능
- SpecialRoom 분기 실패 시 전체 재시도 → 5×5 기준 거의 발생하지 않음
- A/B 변형 랜덤 선택으로 골격 자체에도 비주얼 다양성 부여

---

## 다음 권장 태스크
- **WFC-09**: 제약 전파 안정화 (arc consistency 강화, 소켓 호환 테이블 사전 계산, 부분 백트래킹)
- **WFC-10**: 런타임 생성 안정화 (무한 재귀 방지, 코루틴 재시도 상한, 폴백 맵)
