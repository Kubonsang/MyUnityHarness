# 60. WFC-02: ExitRoom 가장자리 배치 제약

## 세션 목표
WFCGenerator에서 ExitRoom 타일을 그리드 가장자리 셀에만 배치되도록 제약을 추가한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/WFC/WFCGenerator.cs` | `InitGrid()` 비가장자리 셀 ExitRoom 제거, `Validate()` 위치 검증 추가 |
| `feature_list.json` | WFC-02 status → `done` |

---

## 핵심 설계

### InitGrid() — 초기화 시 제약 적용
```csharp
bool isEdge = x == 0 || x == gridWidth - 1 || z == 0 || z == gridDepth - 1;
if (!isEdge)
    grid[x,y,z].availableTiles.RemoveAll(t => t.tileType == TileType.ExitRoom);
```
WFC 초기화 단계에서 내부 셀(9개)의 후보 목록에서 ExitRoom을 제거한다.  
Propagate가 시작되기 전에 제약이 걸리므로 WFC 흐름과 자연스럽게 통합된다.

### Validate() — 생성 후 위치 재검증
```csharp
if (t.tileType == TileType.ExitRoom)
{
    bool isEdge = x == 0 || x == gridWidth - 1 || z == 0 || z == gridDepth - 1;
    if (!isEdge) return false;
}
```
InitGrid 필터가 정상 동작했다면 이 검증은 항상 통과한다. 방어적 안전망으로 유지.

### 5×5 그리드 가장자리 분포
| 구분 | 셀 수 | ExitRoom 허용 |
|---|---|---|
| 가장자리 (엣지 + 코너) | 16개 | ✅ |
| 내부 | 9개 | ❌ |

---

## 검증 절차

1. `unity-cli editor refresh --compile` → error CS 없음 확인 (**완료**)
2. exec 로직 검증: 5×5 기준 가장자리 16개 / 내부 9개 판정 정확, 오판 없음 (**완료**)
3. Bake 실행 후 Console 로그에서 ExitRoom 좌표가 `x==0`, `x==4`, `z==0`, `z==4` 중 하나에 해당하는지 확인 (에디터 직접 확인 필요)

---

## 주의 사항
- tilePrefabs 리스트에 ExitRoom 타일이 없으면 Validate의 `checkExit` 분기가 false가 되어 ExitRoom 없이도 생성 성공 처리된다. WFC-06(프리팹 세팅) 완료 전까지 이 검증은 사실상 스킵된다.

---

## 다음 권장 태스크
- **WFC-03**: 방 개수 weight 비율 조정 (19방 기준)
