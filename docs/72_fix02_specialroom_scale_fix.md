# 72. FIX-02: SpecialRoom 크기 불일치 수정

## 세션 목표
SpecialRoom A/B의 roomScale을 6에서 10으로 통일하여, 인접 타일과의 8m 바닥·벽 간극을 해소한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Editor/WFCPrefabBuilder.cs` | T_SpecialRoom roomScale 6→10, T_SpecialRoom_B roomScale 6→10 |
| `Assets/Tests/PlayMode/FIX02_Tests.cs` | roomScale 통일 검증 테스트 6종 신규 작성 |

---

## 핵심 설계

### 버그 원인
그리드 tileSize=44m인데 SpecialRoom만 roomScale=6(28m)을 사용하여, 인접 타일과의 벽 좌표가 어긋났다.

| 항목 | roomScale=10 (정상) | roomScale=6 (버그) | 차이 |
|------|---------------------|---------------------|------|
| 바닥 범위 | -20m ~ +20m | -12m ~ +12m | 16m |
| wallDist | 22m | 14m | 8m |
| 총 폭 | 44m | 28m | 16m |

인접 셀 간 벽 사이에 8m 간극이 생겨 바닥·벽이 없는 구간에서 플레이어가 추락할 수 있었다.

### 수정 내용
```csharp
// T_SpecialRoom A: roomScale 6 → 10
CreateVariants("T_SpecialRoom", ..., specialRoomProps, 10);
// T_SpecialRoom B: roomScale 6 → 10
CreateVariants("T_SpecialRoom_B", ..., specialRoomProps, 10);
```

---

## testplay 검증
- **실행 명령어**: `testplay run --shadow --filter FIX02_Tests`
- **실행 결과**: Exit 0, 테스트 6/6 PASS

---

## 검증 절차
1. testplay run --shadow 실행하여 컴파일 에러 없음 확인
2. 에디터에서 WFC > Build 3D WFC Prefabs 실행하여 프리팹 재생성 (사용자 수동)
3. Bake Dungeon 3회 실행하여 SpecialRoom과 인접 타일 사이 간극 0건 확인 (사용자 수동)

---

## 주의 사항
- SpecialRoom 내부 공간이 28m에서 44m로 확대됨 — 소품 배치가 상대적으로 희소해 보일 수 있음
- 프리셋 소품 개수 스케일링은 roomScale>6 구간(8~14개)으로 자동 적용됨
- 프리팹 재생성(Build 3D WFC Prefabs) 후에야 수정 반영

---

## 다음 권장 태스크
- **WFC-09**: 제약 전파 안정화 (arc consistency, 소켓 호환 테이블, 부분 백트래킹)
- **ROOM-04**: 프리셋 랜덤 선택 연동 (Bake 시 테마 자동 배정)
