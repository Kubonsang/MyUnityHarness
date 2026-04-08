# WFC 던전 맵 기획 블루프린트

> 최종 갱신일: 2026-04-07
> 참고 에셋: KayKit Dungeon Remastered 1.1
> 그리드: 5×5 단층 / 목표 플레이타임: 30~50분 (4인)

---

## 1. 게임 루프

```
StartRoom (안전 구역)
  → 탐색 (NormalRoom / ObjectiveRoom / SpecialRoom / Corridor)
      → ExitRoom 발견 시 언제든 탈출 가능 (잠금 없음)
      → 하지만 성장을 위해 계속 탐색하는 구조
  → NormalRoom / ObjectiveRoom 재입장 시 몬스터 리스폰
```

- ExitRoom은 잠금 조건 없음 — 찾으면 즉시 탈출 가능
- 덜 성장한 채 탈출하면 다음 구간이 어려운 간접 압박
- BossRoom은 **별도 씬으로 분리** (기믹 복잡도 고려, 현재 미구현)

---

## 2. TileType 정의

| TileType | 역할 | 몬스터 | 재입장 리스폰 |
|---|---|---|---|
| `StartRoom` | 시작·귀환 거점, 안전 구역 | - | - |
| `NormalRoom` | 웨이브 전투 방 | O | O |
| `ObjectiveRoom` | 목표 미션 방 (4종 랜덤) | O | O |
| `SpecialRoom` | 보상·이벤트 방 (1회 소진) | - | - |
| `Corridor` | 이동 통로 — 함정 + 소규모 조우 | 부분 | 조우만 |
| `ExitRoom` | 탈출구 — 가장자리 고정, 항상 개방 | - | - |
| `Air` | 빈 공간 (WFC 배치 없음) | — | — |

---

## 3. 방 개수 비율 (5×5 = 25칸)

| TileType | 최대 개수 | 예상 소요 시간 |
|---|---|---|
| StartRoom | 1 | — |
| NormalRoom | 7 | ~4분/방 x 7 = **28분** |
| ObjectiveRoom | 2 | ~7분/방 x 2 = **14분** |
| SpecialRoom | 3 | ~2분/방 x 3 = **6분** |
| Corridor | 12 | 이동 (직선/코너/T자/십자 포함) |
| ExitRoom | 1 | — |
| Air | 나머지 | — |
| **합계** | **25** | **~48분** (일부 스킵 시 30분대) |

> Corridor 12는 직선, 코너, T자 교차로, 십자 교차로를 모두 포함한 예산이다.
> 골격 생성이 3~7개를 선점하고, WFC 채움이 나머지를 배치한다.

---

## 4. WFC 알고리즘 — 2단계 생성 (Skeleton-First)

기존 순수 WFC는 연결 실패율이 높았으므로, **골격 우선 생성** 방식으로 재설계했다.

### Phase 1: 골격 생성 (`GenerateSkeleton`)

```
1. StartRoom → 랜덤 가장자리 셀
2. ExitRoom  → 맨해튼 거리 최대 가장자리 셀
3. 경로 생성 → 랜덤 DFS (70% 출구 편향, 30% 우회)
4. SpecialRoom → 경로 중간 셀에서 1칸 분기
5. 타일 매칭 → 입구 방향과 소켓 패턴 정확 매칭
6. ForceCollapse → RecordAndEnforce → Propagate
```

이 단계에서 Start→Exit 경로와 SpecialRoom 분기가 **구조적으로 보장**된다.

### Phase 2: WFC 채움 (기존 로직)

```
GetLowest (최소 엔트로피) → Collapse → Propagate → 반복
→ Validate → PruneIsolatedCells → InstantiateDungeon
```

골격 셀은 이미 `collapsed=true`이므로 자연스럽게 스킵된다.
나머지 셀에 NormalRoom, ObjectiveRoom, 추가 Corridor, Air가 WFC로 배치된다.

### 재시도 로직

- 에디터: `maxRetries=200` 루프 (골격 실패 or WFC 모순 시 처음부터 재시도)
- 런타임: 코루틴 재귀 재시작 (WFC-10에서 상한 도입 예정)

---

## 5. 타일 소켓 시스템

### 소켓 타입
```
Air       — 허공
Wall      — 막힌 벽면
Entrance  — 통행 가능한 출입구
Solid     — 천장/바닥
```

### 소켓 방향 인덱스
```
0=N(+z)  1=E(+x)  2=S(-z)  3=W(-x)  4=Up  5=Down
```

### 타일별 소켓 패턴 (기본 변형 기준)

| 타일 | N | E | S | W | Up | Down | 회전 수 |
|------|---|---|---|---|----|----|---------|
| Room (Start/Exit/Normal/Special/Objective) | E | W | W | W | S | S | 4 |
| Corridor (직선) | E | W | E | W | S | S | 2 |
| Corner | E | E | W | W | S | S | 4 |
| T-Intersection | E | E | E | W | S | S | 4 |
| Cross | E | E | E | E | S | S | 1 |

> E=Entrance, W=Wall, S=Solid. 회전 공식: `sockets[k] = base[(k+4-i)%4]`

### 호환 규칙 (`CanConnect`)
- 동일 소켓: 호환
- Wall-Air, Air-Wall: 호환 (외벽이 빈 공간에 노출)
- Solid-Air, Air-Solid: 호환 (천장/바닥이 빈 공간에 노출)
- 그 외: 비호환

---

## 6. 물리적 공간 스케일

| 항목 | 값 | 비고 |
|------|-----|------|
| tileSize | 44m | WFC 그리드 셀 간격 |
| roomScale (대형) | 10 | Start/Exit/Normal/Objective — 40x40m 내부 |
| roomScale (특수) | 6 | Special — 24x24m 내부 |
| 벽 높이 | 8m | 2단 적층 (4m x 2) |
| 바닥 Y | 0.11m | KayKit 에셋 기준 |
| 서브타일 단위 | 4m | 바닥/천장 타일 배치 간격 |

---

## 7. 셸 변형 (A/B Variants)

같은 TileType이라도 벽·바닥 텍스처가 다른 **A/B 셸 변형**이 존재한다.
WFC weight로 등장 빈도를 제어하며 코드 변경 없이 비주얼 다양성을 확보한다.

| 변형 | 바닥 | 벽 | 대상 타일 |
|------|------|-----|-----------|
| A (기본) | 흙/석재/나무/타일 | wall.fbx | 모든 타일 |
| B (대체) | 바위/흙 | wall_cracked / wall_arched / wall_gated | NormalRoom, ObjectiveRoom, SpecialRoom, Corridor, Corner |

---

## 8. RoomPreset 시스템 (테마별 소품 배치)

### RoomPreset ScriptableObject
```csharp
public class RoomPreset : ScriptableObject
{
    public RoomFlavor roomFlavor;
    public TileType[] compatibleRoomTypes;
    public string[] preferredFloors;
    public List<PropEntry> props;     // (fbxName, position, rotationY, scale)
    public string[] wallFurnitureOverride;

    public bool IsCompatibleWith(TileType type);
}
```

### 7종 테마 프리셋

| 프리셋 | RoomFlavor | 호환 TileType | 주요 소품 |
|--------|------------|---------------|-----------|
| Preset_Treasure | Treasure | SpecialRoom | 금화, 보물상자, 방패 |
| Preset_Library | Library | SpecialRoom, ObjectiveRoom | 책장, 촛대, 테이블 |
| Preset_Prison | Prison | ObjectiveRoom, NormalRoom | 격자창, 침대, 쇠사슬 |
| Preset_Alchemy | MagicStudy | SpecialRoom, NormalRoom | 포션, 책장, 마법 테이블 |
| Preset_Storage | Storage | NormalRoom, Corridor | 배럴, 크레이트, 잡동사니 |
| Preset_Ritual | RitualRoom | ObjectiveRoom | 마법진, 제단, 촛대 |
| Preset_Barracks | Barracks | NormalRoom | 무기 rack, 갑옷 stand |

### 소품 배치 로직 (WFCPrefabBuilder)
1. **프리셋 매칭**: `FindPresetsForType(TileType, RoomFlavor)` → 호환 프리셋 후보군
2. **프리셋 있으면**: 정확한 위치/회전/스케일로 배치
3. **프리셋 없으면**: 룸 크기 기반 랜덤 배치 (개수 스케일링)
   - roomScale <= 3: 바닥 2~4개, 벽가구 1~2개
   - roomScale <= 6: 바닥 4~8개, 벽가구 2~4개
   - roomScale > 6: 바닥 8~14개, 벽가구 4~7개

### 벽 장식 (자동 배치)
- 횃불 15% (평면 벽, 포인트 라이트 포함)
- 배너 7% (평면 벽)
- 방패 배너 5% (평면 벽)
- 벽걸이 무기 8% (아치 벽)

---

## 9. RoomFlavor 열거형

| TileType 용도 | RoomFlavor | 설명 |
|--------------|------------|------|
| SpecialRoom | `Treasure` | 금화·상자 props |
| SpecialRoom | `Merchant` | 바 카운터·술통 |
| SpecialRoom/NormalRoom | `MagicStudy` | 책장·포션·마법진 |
| ObjectiveRoom/NormalRoom | `Prison` | 격자창·침대·구출 NPC |
| ObjectiveRoom | `RitualRoom` | 동시 조작 장치 4개 |
| SpecialRoom/ObjectiveRoom | `Library` | 랜덤 이벤트 선택지 |
| NormalRoom | `Barracks` | 무기·갑옷 rack |
| NormalRoom | `Ruins` | 비계·잔해·구조물 |
| NormalRoom/Corridor | `Storage` | 배럴·크레이트 |
| Corridor | `Waterway` | 물 타일, 이동 속도 감소 |
| 모든 타입 | `None` | 기본 회색 던전 |

---

## 10. ObjectiveRoom 4종 (런타임 랜덤 배정)

TileType은 단일(`ObjectiveRoom`), `ObjectiveType` enum으로 구분.

| ObjectiveType | 내용 | 4인 협력 포인트 |
|---|---|---|
| `Retrieval` | 유물 회수 → StartRoom/ExitRoom 전달 | 호위 분업 |
| `Rescue` | NPC 구출 → 살아있는 상태로 이동 | 탱커 앞·힐러 뒤 |
| `Ritual` | 4개 장치 **동시** 상호작용 | 동시 조작 필수 |
| `RandomEvent` | 선택지 이벤트 (버프/디버프/스토리) | 협의 필요 |

---

## 11. 재입장 리스폰 시스템 (RoomStateManager)

```
조건 A: 마지막 퇴장 후 일정 시간(respawnDelay) 경과
조건 B: 현재 접속 중인 플레이어 전원 재입장
→ A AND B 모두 충족 시 리스폰
```

- `isDangerous == true`인 방만 등록 (NormalRoom, ObjectiveRoom, Corridor)
- StartRoom / SpecialRoom / ExitRoom: 리스폰 없음

---

## 12. ExitRoom 배치 제약

```
가장자리 조건: x == 0 || x == gridWidth-1 || z == 0 || z == gridDepth-1
```

- `InitGrid()`에서 비가장자리 셀의 ExitRoom 후보 제거
- `GenerateSkeleton()`에서 가장자리 셀에 명시적 배치
- `Validate()`에서 이중 검증

---

## 13. 맵 컬러 구분 (미니맵/오버레이)

`Tile.isDangerous` 필드 기준 (OnValidate 자동 세팅).

| 색상 | isDangerous | TileType |
|---|---|---|
| 초록 (안전) | `false` | StartRoom, SpecialRoom, ExitRoom, Air |
| 빨강 (위험) | `true` | NormalRoom, ObjectiveRoom, Corridor |

---

## 14. Tile.cs 데이터 구조

```csharp
public enum TileType    { Air, Corridor, NormalRoom, SpecialRoom, StartRoom, ObjectiveRoom, ExitRoom }
public enum RoomFlavor  { None, Treasure, Merchant, MagicStudy, Prison, RitualRoom, Library,
                          Barracks, Ruins, Storage, Waterway }
public enum ObjectiveType { Retrieval, Rescue, Ritual, RandomEvent }
public enum SocketType  { Air, Wall, Entrance, FloorOpen, Solid,
                          Stair_0, Stair_90, Stair_180, Stair_270 }

public class Tile : MonoBehaviour
{
    public TileType     tileType    = TileType.Corridor;
    public int          weight      = 10;
    public bool         isDangerous = false;   // OnValidate 자동 세팅
    public RoomFlavor   roomFlavor  = RoomFlavor.None;
    public SocketType[] sockets     = new SocketType[6];  // N/E/S/W/Up/Down
}
```

---

## 15. 핵심 파일 맵

| 파일 | 역할 |
|------|------|
| `Assets/Scripts/Map/WFC/WFCGenerator.cs` | WFC 알고리즘 + 골격 생성 + 검증 + 프루닝 |
| `Assets/Scripts/Map/WFC/Tile.cs` | TileType, RoomFlavor, SocketType, ObjectiveType enum + Tile 컴포넌트 |
| `Assets/Scripts/Map/WFC/Cell.cs` | WFC 셀 (후보 타일 관리, Collapse, ForceCollapse) |
| `Assets/Scripts/Map/WFC/RoomPreset.cs` | 테마 프리셋 ScriptableObject |
| `Assets/Scripts/Map/WFC/RoomStateManager.cs` | 방 점유/리스폰 서버 로직 |
| `Assets/Scripts/Map/WFC/SpectatorCamera.cs` | 에디터 던전 탐방 카메라 |
| `Assets/Editor/WFCPrefabBuilder.cs` | 타일 프리팹 빌드 (셸 변형, 소품, 프리셋 연동) |

---

## 16. 구현 태스크 현황

### 완료

| ID | 작업 |
|---|---|
| WFC-01 | `isDangerous` 플래그 추가 |
| WFC-02 | ExitRoom 가장자리 배치 제약 |
| WFC-03 | 방 개수 weight 비율 조정 |
| WFC-04 | ObjectiveRoom 런타임 랜덤 타입 배정 |
| WFC-05 | RoomStateManager 재입장 리스폰 조건 |
| WFC-06 | ObjectiveRoom 프리팹 + isDangerous 세팅 |
| WFC-07 | 던전 Bake 통합 검증 |
| WFC-08 | 골격 우선 생성 (Skeleton-First WFC) |
| ROOM-01 | RoomPreset RoomFlavor/TileType 호환 확장 |
| ROOM-02 | B-variant 셸 프리팹 5종 |
| ROOM-03 | 2배 스케일업 + 7종 테마 프리셋 생성 |

### 남은 태스크

| ID | 작업 | 상태 |
|---|---|---|
| WFC-09 | 제약 전파 안정화 (arc consistency, 소켓 호환 테이블, 부분 백트래킹) | `todo` |
| WFC-10 | 런타임 생성 안정화 (무한 재귀 방지, 코루틴 상한, 폴백 맵) | `todo` |
| ROOM-04 | 프리셋 랜덤 선택 연동 (Bake 시 테마 자동 배정) | `todo` |
| ROOM-05 | NavMesh 호환성 검증 (소품 Collider 조정) | `todo` |

---

## 17. 미결 사항

- **Corridor 함정 데미지 수치**: 별도 태스크에서 결정
- **리스폰 대기 시간 (respawnDelay)**: 구체적 수치 미정
- **BossRoom 씬 전환 방식**: 추후 별도 설계
- **Waterway 이동 속도 감소율**: 구현 시 결정
- **다층 던전 (gridHeight > 1)**: 현재 단층만 지원, 계단 소켓 예약됨
