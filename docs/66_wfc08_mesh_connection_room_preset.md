# 66. WFC-08: KayKit 메시 연결 & 방 연결 & RoomPreset 통합

## 세션 목표
1. WFC 던전이 시각적으로 보이지 않던 문제(KayKit 경로 누락) 후속 — 메시가 보이는 상태에서 방 간 연결 보장
2. 방들이 Entrance-Entrance로 연결되지 않는 고립 클러스터 문제 수정
3. RoomPreset ScriptableObject를 WFCPrefabBuilder에 통합해 사용자 정의 소품 배치 지원

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Editor/WFCPrefabBuilder.cs` | `AttachMacroModels`에 `TileType type` 파라미터 추가, `FindPresetsForType()` 추가, 소품 배치를 프리셋 우선으로 변경 |
| `Assets/Scripts/Map/WFC/WFCGenerator.cs` | `ValidateConnectivity()` 추가, `Validate()`에 BFS 연결성 검사 통합, maxRetries 20→200 |

---

## 핵심 설계

### RoomPreset 통합 흐름
```
Assets/WFC/RoomPresets/ 폴더에 RoomPreset 에셋 배치
  → BuildPrefabs() 실행 시 FindPresetsForType(TileType) 호출
  → 해당 TileType 프리셋 발견 시 preset.props 적용 (위치·회전·스케일 그대로)
  → 프리셋 없으면 기존 랜덤 propPool 유지
  → 동일 TileType 프리셋 여러 개면 빌드 시 랜덤 선택
```

### 사용자 RoomPreset 생성 방법
1. Project 창 우클릭 → `Create → WFC → Room Preset`
2. `roomType` 지정 (NormalRoom / SpecialRoom / StartRoom / ExitRoom / ObjectiveRoom)
3. `props` 리스트에 소품 추가: `fbxName` (예: `chest_large_gold.fbx`), `localPosition`, `rotationY`, `scale`
4. 에셋을 `Assets/WFC/RoomPresets/` 폴더에 저장
5. `WFC/Build 3D WFC Prefabs & Rotations & Atmosphere` 메뉴 재실행 → 프리셋 자동 적용

### BFS 연결성 검사 (ValidateConnectivity)
```csharp
// StartRoom에서 BFS 시작
// Entrance-Entrance 쌍으로만 이동 가능
// ExitRoom AND SpecialRoom 중 하나 이상에 도달해야 통과
// 통과 실패 시 → Validate() false → 재시도
```

- 검사 수준: StartRoom → ExitRoom, StartRoom → SpecialRoom(1개 이상) 경로 존재 여부
- 전체 셀 연결 검사(모든 비-Air 셀)는 WFC 성공률을 너무 낮춤 → 이 수준으로 완화
- maxRetries 200으로 증가해 더 엄격한 검사에도 충분한 재시도 보장

---

## 검증 절차

1. 컴파일: error CS 없음 (**완료**)
2. BakeDungeonEditor() 2회 실행 결과:
   - 1회: `연산 시도: 15회` PASS — Air×31, Corridor×5, StartRoom×1, NormalRoom×7, ExitRoom×1, SpecialRoom×3, ObjectiveRoom×2
   - 2회: `연산 시도: 41회` PASS — 동일 배치 구성
3. 사용자 에디터 육안 확인 — 방 연결 상태 미검증 (에디터에서 직접 확인 필요)

---

## 주의 사항
- `Assets/WFC/RoomPresets/` 폴더가 없으면 프리셋 기능 무시, 기존 랜덤 배치 유지 (에러 없음)
- BuildPrefabs() 실행 시점에 프리셋이 읽히므로, 프리셋 수정 후엔 반드시 재빌드 필요
- BFS는 StartRoom→ExitRoom, StartRoom→SpecialRoom 경로 존재만 검사. 고립된 NormalRoom/Corridor는 여전히 존재 가능 (플레이 불가 영역)
- maxRetries=200 → 성공률이 낮은 레이아웃에서 에디터가 잠시 멈출 수 있음

---

## 다음 권장 태스크
- **플레이어 입장 트리거 콜라이더**: RoomStateManager 방 입장 감지 세팅 (WFC-05에서 미완)
- **NET-연동**: ObjectiveType 할당을 NetworkVariable로 동기화
- **고립 방 제거 후처리**: BFS 미도달 비-Air 셀을 Air로 교체하는 post-processing 추가 (완전 연결 보장)
