# 06. PLAYER-03: PlayerAnimationController (Animator 상태 NetworkVariable 동기화)

## 세션 목표
로컬 플레이어가 이동 시 모든 클라이언트에서 Walk 애니메이션 재생. Idle/Walk 전환 NetworkVariable 기반 동기화.

---

## Character.prefab 현황 (Inspect 결과)

| 컴포넌트 | 상태 |
|---------|------|
| NetworkObject | ✅ 있음 |
| NetworkTransform (서버 권위) | ✅ 있음 |
| CharacterController | ✅ 있음 |
| PlayerController | ✅ 있음 |
| PlayerInputHandler | ✅ 있음 |
| **Animator** | ❌ **없음 → 에디터에서 추가 필요** |

---

## 에셋 현황

| 항목 | 상태 |
|------|------|
| NoWeaponStance.controller | ✅ `Assets/RPGTinyHeroWavePBR/Animator/NoWeaponStance.controller` |
| 상태명 | `Idle_Normal_NoWeapon`, `MoveFWD_Normal_InPlace_NoWeapon` |
| controller 파라미터 | ❌ 없음 (`m_AnimatorParameters: []`) → CrossFade로 직접 제어 |
| Idle/Walk FBX 클립 | ✅ `Animation/NoWeapon/` 안에 존재 (FBX 임베드) |

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerAnimationController.cs` | 신규 생성 |
| `Assets/Scripts/Player/PlayerAnimationController.cs.meta` | 신규 생성 (GUID: `d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9`) |
| `Assets/Scripts/Player/PlayerController.cs` | `_animController` 캐시 + `SetMoving()` 호출 추가 |
| `feature_list.json` | PLAYER-03 → `in_progress` |

---

## 핵심 설계

### 동기화 흐름
```
[Server] ApplyMovement() 후 → PlayerAnimationController.SetMoving(bool)
    → NetworkVariable<bool> _isMoving.Value 변경
         ↓ OnValueChanged
[모든 클라이언트] ApplyAnimationState() → Animator.CrossFadeInFixedTime(stateName, 0.15f)
```

### PlayerAnimationController.cs 핵심 설계
- `NetworkVariable<bool> _isMoving` (WritePermission.Server, ReadPermission.Everyone)
- `SetMoving(bool)` — 서버 전용 진입점 (PlayerController에서 호출)
- `OnIsMovingChanged` → `CrossFadeInFixedTime`으로 상태 전환
- `OnNetworkSpawn`에서 현재 값 즉시 반영 (늦게 접속한 클라이언트 처리)
- `_animator == null` guard → Animator 없어도 컴파일 에러 없음

### PlayerController.cs 변경 (최소)
```csharp
// Awake() 추가
_animController = GetComponent<PlayerAnimationController>();

// ApplyMovement() 끝에 추가
_animController?.SetMoving(_serverMoveInput.magnitude > 0.01f);
```

---

## ⚠️ 에디터에서 반드시 해야 할 작업

### 1. Character.prefab에 Animator 컴포넌트 추가
1. `Assets/Resources/Character.prefab` 열기
2. Inspector → **Add Component → Animator**
3. Animator의 **Controller** 필드에 `Assets/RPGTinyHeroWavePBR/Animator/NoWeaponStance.controller` 드래그
4. Avatar는 Character 모델의 Avatar 에셋 연결 필요 (RPGTinyHeroWavePBR 내 character rig)

### 2. Character.prefab에 PlayerAnimationController 컴포넌트 추가
1. Inspector → **Add Component → PlayerAnimationController**
2. 저장 (Ctrl+S)

### 3. Character.prefab이 NetworkManager의 PlayerPrefab으로 등록됐는지 확인
- NGO_Setup.unity의 NetworkManager → **Network Prefabs List**에 Character.prefab이 있는지 확인
- 없으면 추가

---

## 검증 절차
1. NGO_Setup.unity 열기
2. Play → Start Host → 플레이어 스폰 시 Idle_Normal_NoWeapon 재생 확인
3. WASD 입력 → Walk 애니메이션(`MoveFWD_Normal_InPlace_NoWeapon`) 전환 확인
4. 입력 해제 → Idle 복귀 확인
5. ParrelSync/빌드 → Client 접속 → Host의 이동 시 Client 화면에서도 Walk 재생 확인
6. 검증 완료 → `feature_list.json` PLAYER-03 → `done`

---

## PLAYER-03 범위 밖 (후속 태스크로 분리)

| 사항 | 분리 이유 |
|------|----------|
| Sprint/Jump 애니메이션 전환 | PLAYER-04 FSM에서 처리 |
| 방향별 이동 애니메이션 (MoveBWD, MoveLFT 등) | PLAYER-04 FSM에서 처리 |
| Animator Controller 파라미터 추가 | NoWeaponStance.controller 수정은 별도 작업 |
| Avatar 설정 문제 | 모델별 Avatar 연결은 에디터 확인 필요 |

---

## 주의 사항

1. **NoWeaponStance.controller ExitTime 전환**: 컨트롤러에 파라미터가 없고 ExitTime 기반 전환이 있어, CrossFade로 진입한 상태가 ExitTime에 의해 다른 상태로 전환될 수 있음. 검증 시 확인 필요.
2. **Avatar 미연결**: 스켈레탈 애니메이션은 Avatar가 필요. Character.prefab 모델의 Avatar 에셋을 Animator에 연결해야 함.
3. **Character.prefab PlayerPrefab 등록 여부**: NGO_Setup.unity NetworkManager에 등록되지 않으면 스폰 안 됨.

---

## 다음 권장 태스크
**PLAYER-04**: Player FSM (Idle/Walk/Run/Attack 상태 머신) - 방향별 이동, Sprint, Jump 애니메이션 포함
