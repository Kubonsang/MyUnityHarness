# 68. ROOM-02: 룸 셸(Shell) 베이스 프리팹 제작 — KayKit 벽·바닥·기둥 조합으로 TileType별 기본 구조물 프리팹 조립

## 세션 목표
기존 A 변형 셸(5종 방 + 4종 통로)만 존재하던 WFCPrefabBuilder에 B 변형 셸 5종을 추가하여 총 10종의 셸 변형을 확보한다. 바닥 풀에 `rockyFloors`를 신설하고, TileType별 대체 벽·바닥 조합으로 비주얼 다양성을 높인다. 직선 통로 break 조건도 B 변형 호환으로 수정한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Editor/WFCPrefabBuilder.cs` | `rockyFloors` 바닥 풀 추가 (`floor_tile_large.fbx`, `floor_tile_large_rocks.fbx`), B 변형 셸 `CreateVariants` 5종 추가 (T_NormalRoom_B, T_ObjectiveRoom_B, T_SpecialRoom_B, T_Corridor_B, T_Corner_B), 직선 통로 break 조건 `name == "T_Corridor"` → `name.StartsWith("T_Corridor")` 변경 |

---

## 핵심 설계

### 바닥 풀 추가: rockyFloors
기존 4종(dirt/stone/wood/nice)에 `rockyFloors`를 추가하여 바위가 섞인 석재 바닥 표현을 가능하게 했다.
```csharp
static string[] rockyFloors = { "floor_tile_large.fbx", "floor_tile_large_rocks.fbx" };
```

### B 변형 셸 5종 (컨셉별 벽·바닥 조합)

| # | 셸 이름 | TileType | 바닥 | 벽 | 컨셉 | weight |
|---|---------|----------|------|-----|------|--------|
| 1 | T_NormalRoom_B | NormalRoom | rockyFloors | wall_cracked.fbx | 폐허 | 20 |
| 2 | T_ObjectiveRoom_B | ObjectiveRoom | stoneFloors | wall_arched.fbx | 의식방 | 12 |
| 3 | T_SpecialRoom_B | SpecialRoom | rockyFloors | wall_gated.fbx | 감옥/금고 | 10 |
| 4 | T_Corridor_B | Corridor | dirtFloors | wall_cracked.fbx | 황폐한 직선 통로 | 25 |
| 5 | T_Corner_B | Corridor | dirtFloors | wall_cracked.fbx | 황폐한 코너 통로 | 20 |

B 변형의 weight는 A 변형보다 낮게 설정하여 기본 셸이 더 자주 출현하되, 가끔 분위기가 다른 방이 등장하도록 튜닝했다.

### 셸 변형 전체 현황 (A+B = 10종)

| # | 셸 이름 | TileType | 바닥 | 벽 | 컨셉 |
|---|---------|----------|------|-----|------|
| 1 | T_NormalRoom | NormalRoom | dirt | wall.fbx | 야영지/병영 |
| 2 | T_NormalRoom_B | NormalRoom | rocky stone | wall_cracked | 폐허 |
| 3 | T_ObjectiveRoom | ObjectiveRoom | dirt | wall.fbx | 표준 목표방 |
| 4 | T_ObjectiveRoom_B | ObjectiveRoom | stone | wall_arched | 의식방 |
| 5 | T_SpecialRoom | SpecialRoom | wood | wall.fbx | 보물방 |
| 6 | T_SpecialRoom_B | SpecialRoom | rocky stone | wall_gated | 감옥/금고 |
| 7 | T_StartRoom | StartRoom | tile | wall.fbx | 거점 |
| 8 | T_ExitRoom | ExitRoom | tile | wall.fbx | 탈출구 |
| 9 | T_Corridor/Corner/T/Cross A | Corridor | stone | wall.fbx | 표준 통로 |
| 10 | T_Corridor_B/Corner_B | Corridor | dirt | wall_cracked | 황폐한 통로 |

### 직선 통로 break 조건 수정
기존에 `name == "T_Corridor"`로 정확 비교하던 직선 통로 break 조건을 `name.StartsWith("T_Corridor")`로 변경하여 B 변형(`T_Corridor_B`)도 0도/90도 2회전까지만 생성되도록 호환 처리했다.

```csharp
// Before
if (name == "T_Corridor" && i == 1) break;

// After
if (name.StartsWith("T_Corridor") && i == 1) break;
```

---

## 검증 절차

1. `testplay run --shadow`: exit_code 0, 컴파일 에러 0
2. 테스트 6/6 PASS — 기존 A 변형 및 신규 B 변형 모두 프리팹 빌드 정상
3. 완료 → feature_list.json ROOM-02 → `done`

---

## 주의 사항
- StartRoom, ExitRoom은 B 변형 미추가 — 게임 디자인상 시작/출구 방은 안정적 비주얼을 유지하기 위해 단일 셸만 사용
- T_T_Intersection, T_Cross도 B 변형 미추가 — T자/십자 통로는 출현 빈도가 낮아 우선순위 후순위
- `wall_cracked.fbx`를 기본 벽으로 사용하는 B 변형에서는 `PlaceWallDecorated`의 랜덤 벽 변형 분기에서 `wallModel.Contains("cracked")` 가드가 작동하여 cracked 벽이 다시 cracked로 변형되는 중복이 방지됨
- B 변형 소품 풀은 A 변형과 동일한 `normalRoomProps`, `specialRoomProps`, `corridorProps` 등을 공유 — 향후 RoomPreset/RoomFlavor 연동 시 테마별 소품 분리 가능

---

## 다음 권장 태스크
- **ROOM-03 (예정)**: RoomPreset .asset 파일 실제 생성 — 각 RoomFlavor(Treasure, Prison, Barracks 등)별 소품 배치 프리셋 제작
- **B 변형 확장**: T_T_Intersection_B, T_Cross_B 추가 시 황폐한 분기/교차로 표현 가능
- **weight 밸런싱**: 플레이테스트 후 A/B 변형 출현 비율 미세 조정
