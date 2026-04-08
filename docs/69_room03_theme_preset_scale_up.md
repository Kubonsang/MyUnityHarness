# 69. ROOM-03: 테마별 소품 데코레이션 프리셋 7종 + 룸 크기 2배 스케일업

## 세션 목표
WFC 던전 생성의 비주얼 밀도와 공간감을 개선한다. (A) 모든 룸의 물리적 크기를 2배로 스케일업하여 전투/탐색 공간을 확보하고, 소품·벽 가구 개수를 룸 크기에 비례하도록 스케일링한다. (B) 7개 테마별 RoomPreset ScriptableObject 에셋을 자동 생성하는 에디터 메뉴를 추가하여, RoomFlavor별 소품 배치 프리셋을 한 번에 생산할 수 있도록 한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/WFC/WFCGenerator.cs` | `tileSize` 20 → 44로 변경 (2배 스케일업 + 여유분) |
| `Assets/Editor/WFCPrefabBuilder.cs` | roomScale 전면 2배 조정 (5→10, 3→6), 소품/벽가구 개수 스케일링 로직 추가, `[MenuItem("WFC/Generate Theme Room Presets (7 Themes)")]` 메뉴 및 7종 프리셋 생성 로직 추가, 관련 주석 업데이트 |

---

## 핵심 설계

### A. 룸 크기 2배 스케일업

#### tileSize 변경
`WFCGenerator.cs`의 `tileSize`를 20에서 44로 변경하여 WFC 그리드 셀 하나의 월드 크기를 2배 이상으로 확대했다.

#### roomScale 2배 조정

| 방 유형 | 변경 전 | 변경 후 |
|---------|---------|---------|
| 대형 방 (Normal, Objective, Start, Exit) | 5 | 10 |
| 특수 방 (Special) | 3 | 6 |

#### 소품·벽 가구 개수 스케일링

**바닥 소품 개수:**

| roomScale 범위 | 개수 |
|----------------|------|
| ≤ 3 | 2~4 |
| ≤ 6 | 4~8 |
| > 6 | 8~14 |

**벽 가구 개수:**

| roomScale 범위 | 개수 |
|----------------|------|
| ≤ 3 | 1~2 |
| ≤ 6 | 2~4 |
| > 6 | 4~7 |

### B. 7개 테마 RoomPreset SO 에셋 생성

| # | 프리셋명 | RoomFlavor | 호환 TileType | 소품 수 |
|---|----------|------------|---------------|---------|
| 1 | Preset_Treasure | Treasure | SpecialRoom | 7 |
| 2 | Preset_Library | Library | SpecialRoom, ObjectiveRoom | 8 |
| 3 | Preset_Prison | Prison | ObjectiveRoom, NormalRoom | 6 |
| 4 | Preset_Alchemy | MagicStudy | SpecialRoom, NormalRoom | 8 |
| 5 | Preset_Storage | Storage | NormalRoom, Corridor | 7 |
| 6 | Preset_Ritual | RitualRoom | ObjectiveRoom | 6 |
| 7 | Preset_Barracks | Barracks | NormalRoom | 8 |

---

## testplay 검증
- **실행 명령어**: `testplay run --shadow`
- **실행 결과**: Exit 0, 컴파일 에러 0, 테스트 6/6 PASS

---

## 검증 절차
1. testplay run --shadow 실행하여 컴파일 에러 없음 확인
2. 에디터에서 WFC > Generate Theme Room Presets 실행하여 7종 SO 에셋 생성 확인 필요 (사용자 수동)
3. WFC > Build 3D WFC Prefabs 실행하여 2배 크기 프리팹 정상 빌드 확인 필요 (사용자 수동)

---

## 주의 사항
- tileSize 44는 기존 20 대비 2.2배로, 정확히 2배(40)가 아닌 점에 유의 — 서브타일 4m 단위 정수 제한
- roomScale 스케일업으로 기존 NavMesh 베이크 결과가 무효화됨 — 던전 생성 후 NavMesh 재베이크 필요
- 7종 프리셋의 소품 목록은 WFCPrefabBuilder 내부에 하드코딩 — 향후 외부 데이터 드리븐 전환 고려 가능

---

## 다음 권장 태스크
- **ROOM-04**: WFCPrefabBuilder가 프리셋 SO를 읽어 테마별 소품을 자동 배치하도록 연동 (이미 구현됨, 에디터 Bake 실행 검증 필요)
- **ROOM-05**: NavMesh 재베이크 및 호환성 검증
