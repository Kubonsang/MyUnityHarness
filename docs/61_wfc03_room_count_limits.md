# 61. WFC-03: 방 개수 카운트 제한 시스템

## 세션 목표
WFCGenerator에 TileType별 하드 카운트 제한을 추가해 5×5 그리드에서 목표 방 개수(NormalRoom×7, ObjectiveRoom×2, SpecialRoom×3, Corridor×5, StartRoom×1, ExitRoom×1)가 초과되지 않도록 제어한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/WFC/WFCGenerator.cs` | `maxXxx` 제한 필드 추가, `_typeCount` 추적, `RecordAndEnforce` / `EnforceCountLimits` / `IsAtLimit` / `GetMaxCount` 메서드 추가, `ProcessRoomLogics` 집계 로그 추가 |
| `feature_list.json` | WFC-03 status → `done` |

---

## 핵심 설계

### 접근 방식 — 하드 카운트 제한 (Hard Count Limit)
단순 weight 조정만으로는 출력 개수가 확률적으로 흔들린다. 대신 특정 TileType이 목표 수에 도달하는 순간 나머지 미확정 셀에서 해당 타입을 즉시 제거하는 방식을 사용한다.

### 흐름
```
Collapse() → RecordAndEnforce()
               ├─ _typeCount[type]++
               └─ EnforceCountLimits()
                    └─ 미확정 셀 순회 → IsAtLimit인 타입 RemoveAll
```

### 필드 (Inspector 노출)
```csharp
[Header("Room Count Limits (0 = 무제한)")]
public int maxNormalRoom    = 7;
public int maxObjectiveRoom = 2;
public int maxSpecialRoom   = 3;
public int maxCorridor      = 5;
public int maxStartRoom     = 1;
public int maxExitRoom      = 1;
// Air는 나머지 6칸을 채움 (제한 없음)
```

### ProcessRoomLogics 집계 로그
Bake 완료 후 Console에 다음 형식으로 출력:
```
[WFC-Count] 배치 결과: NormalRoom×7  Corridor×5  SpecialRoom×3  ...
```

### 재시도 호환성
한도 제한으로 모순(contradiction)이 발생하면 기존 retry 로직(최대 20회)이 자동으로 재시도한다.

---

## 검증 절차

1. `unity-cli editor refresh --compile` → error CS 없음 확인 (**완료**)
2. exec 로직 검증: `NormalRoom 7개 후 IsAtLimit = True`, `StartRoom 1개 후 IsAtLimit = True`, `ExitRoom 1개 후 IsAtLimit = True` (**완료**)
3. 에디터에서 Bake 실행 후 Console의 `[WFC-Count]` 로그에서 각 TileType 수가 설정값 이하인지 확인 (WFC-06 프리팹 세팅 완료 후 가능)

---

## 주의 사항
- 제한값이 너무 타이트하면 WFC가 자주 모순에 빠져 retry 횟수가 증가한다. `maxNormalRoom` 등은 Inspector에서 조정 가능하므로 실제 Bake 결과를 보며 튜닝 필요.
- tilePrefabs에 해당 TileType 프리팹이 없으면 카운트가 0에 머물러 제한이 사실상 동작하지 않는다 — WFC-06 완료 후 함께 검증해야 한다.

---

## 다음 권장 태스크
- **WFC-04**: ObjectiveRoom 런타임 랜덤 타입 배정 (ObjectiveType enum 4종)
