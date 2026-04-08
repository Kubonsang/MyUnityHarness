# 05. PLAYER-02: PlayerInputHandler (이벤트 기반 Input System 연동)

## 세션 목표
PlayerController의 임시 Update() 폴링을 제거하고, InputSystem_Actions 이벤트 기반 입력으로 교체.
`feature_list.json` PLAYER-02 완료.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerInputHandler.cs` | 신규 생성 |
| `Assets/Scripts/Player/PlayerInputHandler.cs.meta` | 신규 생성 (GUID: `c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8`) |
| `Assets/Scripts/Player/PlayerController.cs` | 폴링 블록 + `_inputActions` 필드 제거, OnNetworkSpawn/Despawn 제거 |
| `Assets/NGO_Minimal_Setup/PlayerPrefab.prefab` | PlayerInputHandler 컴포넌트 추가 |
| `feature_list.json` | PLAYER-02 → `in_progress` |

---

## 핵심 설계

### PlayerInputHandler.cs
- `OnNetworkSpawn()`: 오너만 InputSystem_Actions 생성 + 이벤트 구독
- `OnNetworkDespawn()`: 이벤트 해제 + Disable/Dispose (메모리 누수 방지)
- `OnMove / OnSprintStarted / OnSprintCanceled / OnJump`: PlayerController 공개 API 호출

### PlayerController.cs 변경 (PLAYER-01 대비)
| 제거 항목 | 이유 |
|-----------|------|
| `private InputSystem_Actions _inputActions` 필드 | PlayerInputHandler로 이동 |
| `OnNetworkSpawn()` — InputSystem 초기화 | PlayerInputHandler로 이동 |
| `OnNetworkDespawn()` — InputSystem 해제 | PlayerInputHandler로 이동 |
| Update() 내 폴링 블록 (`if IsOwner && _inputActions != null`) | 이벤트로 교체 |

`Update()`는 `if (IsServer) ApplyMovement();`만 남음.

---

## 이 접근법을 선택한 이유
- PLAYER-01에서 사전 설계한 공개 API(`SetMoveInput`, `SetSprintPressed`, `SetJumpPressed`)를 그대로 사용 → PlayerController 내부 변경 최소화
- 이벤트 기반: `performed / canceled / started` 콜백 → Update() polling 0
- `OnNetworkSpawn` / `OnNetworkDespawn` 구독/해제 패턴 → 메모리 누수 없음

---

## 검증 절차
1. Unity 에디터에서 NGO_Setup.unity 열기
2. PlayerPrefab Inspector에서 PlayerInputHandler 컴포넌트 확인
3. Play → Start Host → WASD/Space/Shift 동작 확인
4. Console에 polling 관련 로그 없음 확인 (PlayerController.Update()는 서버에서만 실행)
5. ParrelSync/빌드 → Client → 위치 동기화 확인
6. 검증 완료 후 `feature_list.json` PLAYER-02 → `done`

---

## 다음 권장 태스크
**PLAYER-03**: PlayerAnimationController (Animator 상태 NetworkVariable로 동기화)
- Idle/Walk 전환
- 로컬 플레이어 이동 시 모든 클라이언트에서 Walk 애니메이션 재생
