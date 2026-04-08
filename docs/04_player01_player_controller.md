# 04. PLAYER-01: PlayerController (CharacterController + 서버 권위 이동)

## 세션 목표
로컬 플레이어만 입력을 받고, 서버에서 이동을 처리한 뒤 NetworkTransform으로 모든 클라이언트에 동기화.
`feature_list.json` PLAYER-01 완료.

---

## 파악된 현황 (Inspect 결과)

| 항목 | 상태 |
|------|------|
| NetworkPlayer.cs | 기반 존재, 이동 로직 없음 |
| PlayerPrefab | CharacterController 없음, NetworkTransform(서버 권위) 있음 |
| InputSystem_Actions | Move(Vector2), Sprint(Button), Jump(Button) 준비됨 |
| NGO_Setup.unity | 바닥 Plane 없음 (사용자 직접 추가 필요) |

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerController.cs` | 신규 생성 |
| `Assets/Scripts/Player/PlayerController.cs.meta` | 신규 생성 (GUID: `a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7`) |
| `Assets/NGO_Minimal_Setup/PlayerPrefab.prefab` | CharacterController, PlayerController 컴포넌트 추가 |
| `feature_list.json` | PLAYER-01 → `in_progress` |

---

## 핵심 설계

### 서버 권위 이동 흐름
```
[Client Owner] Update() 폴링 → SetMoveInput/SetSprintPressed/SetJumpPressed
     ↓ IsServer이면 직접 / 아니면 ServerRpc
[Server] _serverMoveInput, _serverSprint, _serverJump 갱신
     ↓ ApplyMovement() (매 프레임)
[CharacterController.Move()] → transform 변경
     ↓
[NetworkTransform] 모든 클라이언트에 position 동기화
```

### Host(IsServer && IsOwner) 처리
Host는 RPC 없이 서버 변수에 직접 입력. 클라이언트만 ServerRpc를 통해 전달.

### PLAYER-01 vs PLAYER-02 역할 분리
| | PLAYER-01 (현재) | PLAYER-02 (예정) |
|---|---|---|
| 입력 수집 | Update() 내 임시 폴링 | 이벤트 기반 콜백 |
| 이동 처리 | PlayerController.ApplyMovement() | 변경 없음 |
| 공개 API | SetMoveInput / SetSprintPressed / SetJumpPressed | PlayerInputHandler가 이를 호출 |

### PlayerController.cs 핵심 구조
- `OnNetworkSpawn()`: 오너만 InputSystem_Actions 활성화
- `Update()`: 오너이면 입력 읽어 SetMoveInput 등 호출 (임시 폴링)
- `SetMoveInput/SetSprintPressed/SetJumpPressed`: 서버면 직접, 클라이언트면 ServerRpc
- `[ServerRpc] SendMoveServerRpc / SendSprintServerRpc / SendJumpServerRpc`
- `ApplyMovement()`: 서버 전용, CharacterController.Move() 실행

### CharacterController 설정 (PlayerPrefab에 추가)
- Height: 2, Radius: 0.5, Center: {0, 1, 0}
- SkinWidth: 0.08, StepOffset: 0.3

---

## 이 접근법을 선택한 이유
- 서버 권위 NetworkTransform → 서버만 위치를 결정해야 함 → CharacterController는 서버에서만 Move() 실행
- PLAYER-01/PLAYER-02 SRP 분리: 이동 로직과 입력 연동을 별도 컴포넌트로 관리
- 공개 API(`SetMoveInput` 등) 사전 설계 → PLAYER-02에서 폴링 블록만 제거하면 완성
- Host 처리: RPC 불필요한 경우 직접 변수 설정으로 불필요한 네트워크 비용 제거

---

## 검증 절차
1. **Unity 에디터에서 NGO_Setup.unity 열기**
2. **Hierarchy에서 우클릭 → 3D Object → Plane 추가** (바닥 생성, Scale 10,1,10 권장)
3. Play 모드 → **Start Host** 클릭
4. WASD로 Cube 이동 확인
5. Console에 ServerRpc 에러 없음 확인
6. Shift 누르면 빠르게 이동 (sprint), Space로 점프 확인
7. ParrelSync/빌드로 두 번째 인스턴스 → **Start Client** 클릭
8. Host 화면에서 Client 플레이어 Cube가 움직이는 것 확인 (위치 동기화)
9. Client에서 자신의 Cube만 WASD로 제어 가능, 상대방 Cube는 제어 불가 확인
10. 검증 완료 후 `feature_list.json` PLAYER-01 → `done`

---

## 주의 사항

**PlayerController.cs.meta GUID 충돌 가능성:**
- GUID `a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7` 수동 지정
- 에디터 reimport 시 PlayerController Missing Script → Inspector에서 수동 재할당

**BoxCollider + CharacterController 충돌:**
- Unity에서 BoxCollider와 CharacterController를 동시에 사용하면 경고가 발생할 수 있음
- 이동 기능 정상 작동 시 BoxCollider는 제거 권장 (에디터에서 직접 제거)

---

## 다음 권장 태스크
**PLAYER-02**: PlayerInputHandler (이벤트 기반 InputSystem 연동)
- PlayerController의 Update() 내 폴링 블록 제거
- PlayerInputHandler가 InputSystem_Actions 이벤트를 구독하여 PlayerController 공개 API 호출
- 검증: Update() 내 InputSystem 호출 없음
