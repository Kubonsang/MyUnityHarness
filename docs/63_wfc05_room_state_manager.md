# 63. WFC-05: RoomStateManager 재입장 리스폰 조건 시스템

## 세션 목표
던전 방의 플레이어 입장/퇴장을 추적하고, 전원 퇴장 후 일정 시간 경과 AND 전원 재입장 시 리스폰 조건을 판정하는 RoomStateManager를 구현한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/WFC/RoomStateManager.cs` | **신규** — 리스폰 조건 판정 시스템 |
| `Assets/Scripts/Map/WFC/WFCGenerator.cs` | `_roomStateManager` 필드, `InitRoomStateManager()` 추가, Sync/Routine 생성 경로에 연동 |
| `feature_list.json` | WFC-05 status → `done` |

---

## 핵심 설계

### 리스폰 조건 (AND)
```
조건 A: Time.time - lastEmptyTime >= respawnDelay  (기본 180초)
조건 B: playersInside.Count >= _totalConnectedPlayers
→ TryTriggerRespawn()에서 PlayerEnterRoom 호출 시 판정
```

### RoomState 내부 구조
```csharp
private class RoomState
{
    public float lastEmptyTime = -1f;          // -1: 초기 입장은 리스폰 없음
    public HashSet<ulong> playersInside;       // NGO ClientId 기반
}
```

### WFCGenerator 연동 흐름
```
InstantiateDungeon()
  → InitRoomStateManager()   ← container에 컴포넌트 추가 + isDangerous 방 등록
  → ProcessRoomLogics()
```

### 안전 방 제외
`RegisterRoom(coord, isDangerous=false)` → 즉시 return. StartRoom/SpecialRoom/ExitRoom은 등록되지 않아 리스폰 판정 대상에서 제외.

---

## 검증 절차

1. 컴파일: error CS 없음 (**완료**)
2. exec 4단계 시나리오 (**완료**)
   - STEP1: 초기 입장 → 리스폰 없음 PASS
   - STEP2: 전원 퇴장 → lastEmptyTime 기록 PASS
   - STEP3: 재입장(respawnDelay=0) → `[RoomRespawn] 좌표 (1, 0, 1) 리스폰 조건 충족` 로그 출력 PASS
   - STEP4: 안전 방 → 리스폰 로그 미출력 PASS
3. 에디터 Bake 후 실제 플레이어 이동으로 트리거 확인 (WFC-06 + 플레이어 연동 태스크 후 가능)

---

## 주의 사항
- 현재 `_totalConnectedPlayers` 기본값은 1. 멀티플레이 실제 적용 시 `NetworkManager.Singleton.ConnectedClients.Count`로 갱신하는 호출 경로가 필요하다.
- 실제 몬스터 스폰 연동은 별도 태스크 (MonsterSpawner → RoomStateManager 연결).
- 플레이어 입장 감지 트리거 콜라이더 세팅은 WFC-06 프리팹 세팅 시 함께 구성 필요.

---

## 다음 권장 태스크
- **WFC-06**: KayKit 프리팹 Tile.cs 세팅 (TileType/SocketType/weight/isDangerous/RoomFlavor 인스펙터 배정)
