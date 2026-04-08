# 64. WFC-06: KayKit 프리팹 Tile.cs 세팅

## 세션 목표
WFCPrefabBuilder를 통해 TileType별 프리팹(최소 1종씩)에 Tile.cs를 설정하고, WFCGenerator.tilePrefabs에 연결한 뒤 Bake 성공을 검증한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Editor/WFCPrefabBuilder.cs` | ObjectiveRoom 변형 추가 (weight=20, 4방향), `isDangerous` 명시 설정 추가 |
| `feature_list.json` | WFC-06 status → `done` |

---

## 핵심 설계

### 생성된 프리팹 목록 (총 32개)

| 타입 | 변형 수 | weight | isDangerous | 소켓 패턴 (N/E/S/W/Up/Down) |
|---|---|---|---|---|
| Air | 1 | 80 | false | Air×6 |
| NormalRoom | 4 | 30 | true | Entrance/Wall/Wall/Wall/Solid/Solid + 회전 |
| NormalRoom_Cracked | 4 | 30 | true | 동일 (Ruins flavor) |
| ObjectiveRoom | 4 | 20 | true | Entrance/Wall/Wall/Wall/Solid/Solid + 회전 |
| SpecialRoom | 4 | 15 | false | Entrance/Wall/Wall/Wall/Solid/Solid + 회전 |
| StartRoom | 4 | 8 | false | Entrance/Wall/Wall/Wall/Solid/Solid + 회전 |
| ExitRoom | 4 | 8 | false | Entrance/Wall/Wall/Wall/Solid/Solid + 회전 |
| Corridor (직선) | 2 | 45 | true | Entrance/Wall/Entrance/Wall/Solid/Solid |
| Corner | 4 | 35 | true | Entrance/Entrance/Wall/Wall/Solid/Solid + 회전 |
| T_Intersection | 4 | 15 | true | Entrance/Entrance/Entrance/Wall/Solid/Solid + 회전 |
| Cross | 1 | 8 | true | Entrance×4/Solid/Solid |

### WFCSceneSetup 연동
`WFC/Setup Scene` 메뉴 실행 → DungeonManager 생성 → `Assets/Prefabs/WFC/` 내 Tile 컴포넌트가 있는 프리팹 전체를 tilePrefabs에 자동 로드.

### 실제 Bake 결과 (1회 성공)
```
[WFC-Count] Corridor×5  NormalRoom×7  SpecialRoom×3  ObjectiveRoom×2  Air×6  StartRoom×1  ExitRoom×1
```
목표 방 개수와 정확히 일치. 1회 시도로 성공.

---

## 에디터 설정

`WFC/Build 3D WFC Prefabs & Rotations & Atmosphere` 메뉴로 프리팹 재빌드 가능.  
`WFC/Setup Scene` 메뉴로 WFCGenerator + tilePrefabs 자동 구성.

---

## 검증 절차

1. 컴파일: error CS 없음 (**완료**)
2. `WFCPrefabBuilder.BuildPrefabs()` → 32개 프리팹 생성 (**완료**)
3. `WFCSceneSetup.SetupScene()` → tilePrefabs 32개 로드 (**완료**)
4. `BakeDungeonEditor()` → 1회 시도 성공, 배치 수 목표치 일치 (**완료**)

---

## 주의 사항
- 현재 프리팹은 Tile 컴포넌트만 있고 실제 KayKit 메시가 없음. `WFCPrefabBuilder`의 `basePath`와 `floorPool`/`wallPool` 배열을 채우면 시각적 모델이 붙는다.
- `BuildPrefabs()`는 `Assets/Prefabs/WFC/` 폴더를 전부 삭제 후 재생성한다. 수동으로 추가한 프리팹이 있으면 주의.

---

## 다음 권장 태스크
- **WFC-07**: 던전 Bake 통합 검증 (StartRoom 1개, ExitRoom 1개(가장자리), SpecialRoom 1개 이상 조건 최종 확인)
