# 65. WFC-07: 던전 Bake 통합 검증

## 세션 목표
BakeDungeonEditor()를 10회 실행하여 StartRoom×1, ExitRoom×1(가장자리), SpecialRoom≥1 조건이 일관성 있게 통과하는지 최종 검증한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `feature_list.json` | WFC-07 status → `done` |

---

## 핵심 설계

### 검증 방법
`unity-cli exec`으로 10회 반복 Bake + 즉시 조건 검사 C# 스크립트 실행.
ExitRoom 가장자리 판단: `position.x / tileSize` → gridX ∈ {0, 4} or `position.z / tileSize` → gridZ ∈ {0, 4}

### 검증 결과 (10/10 PASS)

| 회차 | Start | Exit | ExitEdge | Special | 결과 |
|------|-------|------|----------|---------|------|
| 1 | 1 | 1 | true | 3 | PASS |
| 2 | 1 | 1 | true | 3 | PASS |
| 3 | 1 | 1 | true | 2 | PASS |
| 4 | 1 | 1 | true | 3 | PASS |
| 5 | 1 | 1 | true | 3 | PASS |
| 6 | 1 | 1 | true | 3 | PASS |
| 7 | 1 | 1 | true | 1 | PASS |
| 8 | 1 | 1 | true | 3 | PASS |
| 9 | 1 | 1 | true | 3 | PASS |
| 10 | 1 | 1 | true | 2 | PASS |

- SpecialRoom: 1~3개 범위, 항상 1개 이상 보장
- `[WFC-Bake] 3D 던전 굽기 성공!` 로그: 10회 전부 확인
- 컴파일 에러: 없음

---

## 검증 절차

1. `unity-cli editor refresh --compile` → error CS 없음 (**완료**)
2. 10회 반복 Bake exec 실행 → 10/10 PASS (**완료**)
3. 씬에서 방 배치 육안 확인 → **사용자 에디터 확인 필요** (자동화 불가)
4. `feature_list.json` WFC-07 → `done` (**완료**)

---

## 주의 사항
- 씬 육안 확인(방 배치 시각적 확인)은 자동 검증이 불가하므로 미검증으로 남겨둠.
- 현재 프리팹은 Tile 컴포넌트만 있고 실제 KayKit 메시 미연결 상태. 시각적 확인 시 빈 오브젝트만 보일 수 있음.
- RoomStateManager._totalConnectedPlayers 기본값 1 — 멀티플레이 연동 시 별도 태스크 필요.

---

## 다음 권장 태스크
- **WFC-08** (미등록): KayKit 메시를 실제 프리팹에 연결하여 시각적 던전 완성
- **NET-연동** (미등록): ObjectiveType 할당을 NetworkVariable로 동기화
- **RoomStateManager 플레이어 트리거** (미등록): 방 입장 감지용 콜라이더 세팅
