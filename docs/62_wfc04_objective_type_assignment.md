# 62. WFC-04: ObjectiveRoom 런타임 랜덤 타입 배정

## 세션 목표
ObjectiveType enum 4종(Retrieval/Rescue/Ritual/RandomEvent)을 정의하고, 던전 생성 시 ObjectiveRoom마다 랜덤으로 배정해 로그로 출력한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/WFC/Tile.cs` | `ObjectiveType` enum 추가 (4종) |
| `Assets/Scripts/Map/WFC/WFCGenerator.cs` | `_objectiveAssignments` 딕셔너리 추가, `InitGrid` 초기화, `ProcessRoomLogics` 배정·로그 추가 |
| `feature_list.json` | WFC-04 status → `done` |

---

## 핵심 설계

### ObjectiveType enum (Tile.cs)
```csharp
public enum ObjectiveType
{
    Retrieval,   // 유물 회수 → StartRoom/ExitRoom으로 전달
    Rescue,      // NPC 구출 → 살아있는 상태로 이동
    Ritual,      // 4개 장치 동시 상호작용
    RandomEvent, // 선택지 이벤트 (버프/디버프/스토리)
}
```

### 랜덤 배정 방식
```csharp
var objType = (ObjectiveType)Random.Range(0, System.Enum.GetValues(typeof(ObjectiveType)).Length);
_objectiveAssignments[new Vector3Int(x, y, z)] = objType;
```
`Enum.GetValues().Length`를 사용해 enum 종류가 늘어도 코드 수정 없이 자동 대응.

### _objectiveAssignments 저장 목적
`Dictionary<Vector3Int, ObjectiveType>` — 이후 RoomStateManager, 몬스터 배치, NPC 배치 등에서 좌표 기반으로 ObjectiveType을 조회하기 위해 유지.

---

## 검증 절차

1. 컴파일: error CS 없음 확인 (**완료**)
2. exec 검증: 100회 랜덤 배정 시 4종 모두 등장 **PASS** (**완료**)
3. 에디터 Bake 후 Console에서 `[Objective] 좌표(x, y, z) 목표 타입: Xxx` 로그 2개 출력 확인 (WFC-06 프리팹 세팅 완료 후 가능)

---

## 주의 사항
- 현재 배정은 매 Bake마다 새로 랜덤 결정된다. 멀티플레이어에서 서버-클라이언트 동기화가 필요하다면 별도 NetworkVariable 연동 태스크가 필요하다.
- ObjectiveRoom이 2개이므로 같은 타입이 두 번 배정될 수 있다. 현재 기획상 제약 없음.

---

## 다음 권장 태스크
- **WFC-05**: RoomStateManager 재입장 리스폰 조건 시스템
