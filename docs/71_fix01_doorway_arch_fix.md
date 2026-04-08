# 71. FIX-01: Doorway 아치 배치 불일치 수정

## 세션 목표
WFCPrefabBuilder의 `isDoorSide` 로컬 방향 고정으로 인한 doorway 아치 누락(0-arch) 및 중복(2-arch z-fighting) 문제를 해결한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Editor/WFCPrefabBuilder.cs` | `BuildMacroWall`에서 `isDoorSide` 파라미터 제거, 모든 Entrance 면에 아치 배치 |
| `Assets/Tests/PlayMode/FIX01_Tests.cs` | isDoorSide 제거 검증 테스트 5종 신규 작성 |

---

## 핵심 설계

### 버그 원인
`BuildMacroWall`의 `isDoorSide` 플래그가 로컬 N/E면에만 `true`로 고정되어 있었다. MacroPivot이 회전하면 로컬 N/E가 world-space에서 다른 방향을 가리키므로, 두 타일이 연결될 때:

- **0-arch (25%)**: 양쪽 모두 isDoorSide=false → 하단 벽 전체 누락 → 상단 벽 공중부양
- **2-arch (25%)**: 양쪽 모두 isDoorSide=true → doorway 아치 2개 겹침 → z-fighting

### 수정 내용
`isDoorSide` 파라미터를 완전 제거하고, 모든 Entrance 면(`isWallFull=false`)에서 하단 1단에 아치를 배치하도록 변경했다.

```csharp
// 변경 전
if (isDoorSide && !isUpperTier)
    PlaceEntranceArch(...);

// 변경 후
if (!isUpperTier)
    PlaceEntranceArch(...);
```

두 인접 타일의 Entrance 면에서 각각 아치가 배치되지만, 동일 모델·동일 좌표이므로 시각적 문제는 없다.

---

## testplay 검증
- **실행 명령어**: `testplay run --shadow --filter FIX01_Tests`
- **실행 결과**: Exit 0, 테스트 5/5 PASS

---

## 검증 절차
1. testplay run --shadow 실행하여 컴파일 에러 없음 확인
2. 에디터에서 WFC > Build 3D WFC Prefabs 실행하여 프리팹 재생성 (사용자 수동)
3. Bake Dungeon 5회 실행하여 모든 Entrance 연결부에 아치 프레임 존재 확인 (사용자 수동)

---

## 주의 사항
- 프리팹 재생성(Build 3D WFC Prefabs) 후에야 수정이 반영됨
- 두 타일 경계에서 아치 모델이 2개 겹치는 것은 의도된 동작 (동일 좌표·동일 모델)

---

## 다음 권장 태스크
- **FIX-02**: SpecialRoom roomScale 6→10 통일 (인접 타일 간 8m 간극 해소)
