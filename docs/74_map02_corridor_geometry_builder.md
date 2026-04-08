# 74. MAP-02: 복도 지오메트리 생성 (CorridorBuilder)

## 세션 목표
Delaunay 그래프의 각 복도 엣지를 따라 3D 통로(벽·바닥·천장·doorway)를 빌드한다. 룸 간 직선 또는 L자형 복도를 KayKit 에셋으로 조립하고, 룸 벽면에 doorway 아치를 뚫어 연결한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/Dungeon/CorridorSegment.cs` | **신규** — `CorridorPathType` enum(Straight/LShaped), `CorridorSegment` 데이터 클래스(start, end, direction, length, tileCount), `CorridorPath` 데이터 클래스(roomA, roomB, pathType, segments, bendPoint) |
| `Assets/Scripts/Map/Dungeon/CorridorBuilder.cs` | **신규** — MonoBehaviour. 4-phase 복도 빌더. 경로 계산(직선/L자 자동 판정) → doorway 벽면 등록 → KayKit 에셋 지오메트리 조립(바닥·2단 벽·천장·기둥) → 소품·토치 배치. `WFCPrefabBuilder.PlaceModel` 패턴 복제(Editor/Runtime 양립) |
| `Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs` | **수정** — `CorridorEdge`에 `wallSideA`/`wallSideB` 필드 추가(복도가 뚫리는 벽면 0=N,1=E,2=S,3=W). `RoomNode`에 `corridorWallSides` HashSet 추가(연결된 복도의 벽면 목록, MAP-03 활용) |
| `Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs` | **수정** — `corridorBuilder` 참조 필드 추가, `autoBuildCorridors` 플래그 추가, `[ContextMenu("Build Dungeon")]` 메서드 추가(BakeLayout + BuildCorridors 통합 실행) |
| `Assets/Tests/PlayMode/MAP02_Tests.cs` | **신규** — 12개 PlayMode 테스트 (경로 계산, Straight/LShaped 판정, wallSide 정확성, doorway 등록, 최소 길이 보장, Snap4, 통합 흐름, 방향 축정렬 검증) |

---

## 핵심 설계

### 4-Phase 파이프라인

| Phase | 이름 | 역할 |
|-------|------|------|
| 1 | 경로 계산 | 각 `CorridorEdge`의 양끝 `RoomNode` 중심 좌표를 XZ 평면으로 변환 후, dx/dz 차이와 `ALIGN_THRESHOLD(4m)` 비교로 Straight vs LShaped 자동 판정. L자형은 두 꺾임점 후보를 AABB 충돌 검사하여 최적 선택 |
| 2 | Doorway 등록 | `GetExitWallSide()`로 각 룸에서 복도가 빠져나가는 벽면(N/E/S/W)을 판정, `CorridorEdge.wallSideA/B`에 기록, `RoomNode.corridorWallSides` HashSet에 집계. MAP-03에서 벽 배치 시 doorway 위치를 인식하는 데 사용 |
| 3 | 지오메트리 조립 | `TILE_SIZE(4m)` 그리드 기준으로 세그먼트를 타일 단위로 분할. 각 타일에 바닥(floor_tile_large + 변형), 천장(ceiling_tile, Y=8m), 양쪽 2단 벽(wall + 변형/장식 인셋), 양 끝 기둥(pillar) 배치. L자형 꺾임점에는 외측 벽 2장 + 내측 기둥 배치 |
| 4 | 소품 배치 | 세그먼트 내 랜덤 위치에 barrel, box, crate 등 소품 배치(`maxPropsPerSegment`). 벽면에 `torchInterval` 간격으로 torch_mounted + Point Light(range=12, intensity=4, 주황색) 부착 |

### 경로 판정 로직
- **Straight (직선)**: `dx <= ALIGN_THRESHOLD(4m)` → Z축 정렬 직선, `dz <= ALIGN_THRESHOLD(4m)` → X축 정렬 직선. 세그먼트 1개 생성
- **LShaped (L자형)**: 두 축 모두 임계치 초과 시 활성. 꺾임점 2개 후보(`bend1 = (Ax, Bz)`, `bend2 = (Bx, Az)`)를 Snap4 후 `IsBendColliding()`으로 AABB 충돌 검사 → 비충돌 또는 합산 길이가 짧은 쪽 선택. 세그먼트 2개 생성

### 좌표 시스템
- `DungeonLayoutData`의 2D 좌표(`Vector2 center`)를 XZ 평면으로 변환: `center.x → X`, `center.y → Z`, `Y=0`
- 모든 좌표는 `Snap4()`로 4m 그리드에 스냅하여 KayKit 타일과 정렬 보장
- 벽면 방향: 0=North(+Z), 1=East(+X), 2=South(-Z), 3=West(-X)

### 에셋 조립 규칙
- `WFCPrefabBuilder.PlaceModel` 패턴 복제: Editor에서는 `AssetDatabase.LoadAssetAtPath` + `PrefabUtility.InstantiatePrefab`, Runtime에서는 `Resources.Load` + `Instantiate`
- 벽 2단 구조: Tier 0(Y=0~4m, 장식/변형 허용) + Tier 1(Y=4~8m, 기본 벽만)
- Doorway: 하단에 `wall_doorway.fbx`, 상단에 `wall.fbx` 배치. 룸 벽면에서 외측 1.5m 오프셋

### 데이터 흐름
```
DungeonLayoutGenerator.BuildDungeon()
  └→ BakeLayout() → DungeonLayout (rooms + corridors)
  └→ CorridorBuilder.BuildCorridors(layout, container)
       ├→ Phase 1: ComputeCorridorPath() → List<CorridorPath>
       ├→ Phase 2: RegisterDoorwaySides() → corridorWallSides 집계
       ├→ Phase 3: BuildSegmentGeometry() / BuildBendGeometry()
       ├→ Phase 4: PlaceCorridorProps()
       └→ PlaceDoorway() → 각 룸 벽면 doorway 아치 배치
```

---

## testplay 검증
- **실행 명령어**: `testplay run --shadow --filter MAP02_Tests`
- **실행 결과**: 통과 (Exit 0), 12/12 PASS
- **검증 내용**:
  - `ComputeCorridorPath`가 null이 아닌 CorridorPath를 반환하고 최소 1개 세그먼트 포함 확인
  - Z축 정렬(dx <= 4m) 시 Straight 판정, 세그먼트 1개 확인
  - X축 정렬(dz <= 4m) 시 Straight 판정, 세그먼트 1개 확인
  - 대각선(dx > 4m, dz > 4m) 시 LShaped 판정, 세그먼트 2개 확인
  - `GetExitWallSide` Z방향 우세 시 N(0)/S(2), X방향 우세 시 E(1)/W(3) 정확성 확인
  - `BuildCorridors` 후 `corridorWallSides`에 doorway 벽면 정상 등록 확인
  - 복도 총 길이가 최소 8m 이상 보장 확인
  - `CorridorEdge.wallSideA/wallSideB`가 유효 범위(0~3)로 기록됨 확인
  - `Snap4()`가 4m 그리드로 정확히 스냅됨 확인 (7개 케이스)
  - `BakeLayout → BuildCorridors` 통합 흐름에서 CorridorPath 수 == corridor 엣지 수 일치 확인
  - 모든 세그먼트 direction이 X 또는 Z축 정렬(단위 벡터) 확인

---

## 검증 절차

1. Scene에 `DungeonLayoutGenerator` 오브젝트에 `CorridorBuilder` 컴포넌트 추가, Inspector에서 `corridorBuilder` 참조 연결
2. `autoBuildCorridors = true` 설정
3. Component 우클릭 → `Build Dungeon (Layout + Corridors)` 실행
4. Scene View에서 Gizmo 확인: 직선 복도(시안), L자형 복도(주황), 꺾임점(노란 구체)
5. SpectatorCamera로 전체 복도 순회 시 확인:
   - (1) 모든 복도에 바닥·벽·천장 존재
   - (2) 룸-복도 연결부에 doorway 아치 정상 (하단 wall_doorway + 상단 wall)
   - (3) 복도 길이가 최소 8m 이상으로 문-문 직결 0건
6. Console에서 `[MAP-02] Built N corridors (M paths)` 로그 확인
7. 확인 완료 → feature_list.json MAP-02 → `done`

---

## 주의 사항
- `CorridorBuilder.PlaceModel()`은 Editor에서는 `AssetDatabase` / `PrefabUtility`를 사용하고, Runtime에서는 `Resources.Load`를 사용한다. KayKit 에셋이 `assetBasePath`에 존재해야 Editor 빌드가 정상 동작한다
- `ALIGN_THRESHOLD = 4f` (4m)은 KayKit 타일 크기와 동일. 이 값을 변경하면 직선/L자 판정 기준이 달라져 복도 형태가 크게 변할 수 있다
- `RoomNode.corridorWallSides`는 `[System.NonSerialized]`이므로 직렬화되지 않는다. 런타임에서 `BuildCorridors()` 호출 시마다 재계산된다
- L자형 복도의 꺾임점 선택은 AABB 기반이므로, 극단적으로 밀집된 룸 배치에서 두 꺾임점 모두 충돌 시 합산 길이가 짧은 쪽을 fallback으로 선택한다 (관통 가능성 존재)
- `Random.Range` 사용으로 소품/변형 벽 배치가 매 실행마다 달라진다. 시드 제어가 필요하면 `System.Random` 인스턴스 도입 필요
- Doorway 오프셋(1.5m)은 하드코딩 상수. 룸 크기가 변경되면 doorway 위치 오차 가능

---

## 다음 권장 태스크
- **MAP-03**: 룸 내부 장식 통합 — 배치된 각 룸 프리팹 내부를 기존 WFC 소품 배치 또는 RoomPreset 프리셋으로 장식하고, `corridorWallSides` 정보를 활용하여 doorway 벽면에는 벽 타일을 배치하지 않도록 처리
