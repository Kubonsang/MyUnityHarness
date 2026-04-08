# 07. PLAYER-04: Player FSM (Idle / Walk / Run / Attack)

## 세션 목표
PLAYER-03의 `NetworkVariable<bool> _isMoving`(이진 상태)를 4개 상태 FSM으로 확장.
Verification: 각 상태 전환이 올바른 조건에서만 발생. 상태 중복 진입 없음. 서버와 클라이언트 상태 일치.

---

## 사용한 애니메이션 상태 (NoWeaponStance.controller)

| FSM 상태 | Animator 상태명 |
|----------|----------------|
| Idle     | `Idle_Normal_NoWeapon` |
| Walk     | `MoveFWD_Normal_InPlace_NoWeapon` |
| Run      | `SprintFWD_Battle_InPlace_NoWeapon` |
| Attack   | `Attack01_NoWeapon` (무기 장착 시 WeaponData.attackAnimStateName으로 오버라이드) |

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerAnimationController.cs` | `NetworkVariable<bool>` → `NetworkVariable<byte>` + `PlayerAnimState` enum. `AnimStateMapping[]` 배열 + Dictionary 룩업. `NetworkVariable<FixedString64Bytes> _attackAnimOverride` 추가 (무기별 공격 애님 동기화). `SetState()` / `SetAttackStateName()` API |
| `Assets/Scripts/Player/PlayerFSM.cs` | **신규**. `MonoBehaviour`. FSM 상태 결정 + 공격 타이머 + 무기 장착 API (`EquipWeapon` / `UnequipWeapon`). 서버 전용 로직 분리 (SRP) |
| `Assets/Scripts/Player/PlayerController.cs` | FSM 로직 제거 → `PlayerFSM` 위임. `SetAttackPressed()` + `SendAttackServerRpc` 추가. `_fsm?.Tick()` 호출 |
| `Assets/Scripts/Player/PlayerInputHandler.cs` | `Attack.performed` 구독/해제 추가, `OnAttack()` 콜백 추가 |
| `Assets/Scripts/Player/WeaponData.cs` | **신규**. `ScriptableObject`. `attackAnimStateName` + `attackDuration` 필드. `[CreateAssetMenu(menuName = "GNF/Weapon Data")]` |
| `feature_list.json` | PLAYER-04 → `in_progress` |

> **에디터 필수 작업**: `Assets/Resources/Character.prefab`에 `PlayerFSM` 컴포넌트 추가

---

## 아키텍처 (SRP 분리)

| 컴포넌트 | 역할 | NetworkBehaviour |
|----------|------|-----------------|
| `PlayerController` | 입력 수신, ServerRpc 전달, 물리(CharacterController) | ✅ |
| `PlayerFSM` | 애님 상태 결정, 공격 타이머, 무기 장착 | ❌ MonoBehaviour |
| `PlayerAnimationController` | NetworkVariable 동기화, Animator 적용 | ✅ |
| `PlayerInputHandler` | Input System 이벤트 → PlayerController API 호출 | ✅ |

---

## 핵심 설계

### 동기화 흐름
```
[Client] InputSystem → PlayerInputHandler
    → PlayerController.SetMoveInput / SetAttackPressed
    → (클라이언트면) ServerRpc 전송

[Server] PlayerController.ApplyMovement()
    → CharacterController.Move()
    → PlayerFSM.Tick(moveInput, sprint)
        → DetermineNextState()
        → PlayerAnimationController.SetState(state)
            → _animState(NetworkVariable<byte>) 변경 (값 동일하면 무시)
                 ↓ OnValueChanged (모든 클라이언트)
[모든 클라이언트] ApplyAnimState() → Animator.CrossFadeInFixedTime(stateName, 0.15f)
```

### 무기 교체 흐름
```
(미래) WeaponController → PlayerFSM.EquipWeapon(weaponData)
    → _currentWeapon 갱신 (공격 지속 시간)
    → PlayerAnimationController.SetAttackStateName(animName)
        → _attackAnimOverride(NetworkVariable<FixedString64Bytes>) 갱신
             ↓ OnValueChanged (모든 클라이언트, 늦게 접속한 클라이언트 포함)
[Attack 상태 중이면] ApplyAnimState(Attack) → 새 무기 공격 애님으로 즉시 전환
```

### 상태 전환 규칙 (서버, DetermineNextState)
| 조건 | 전환 대상 |
|------|---------|
| `_attackTimer > 0` | Attack 유지 |
| `_attackRequested` (타이머 0일 때) | Attack 시작 (timer = CurrentAttackDuration) |
| 이동 없음 | Idle |
| 이동 + Sprint | Run |
| 이동 | Walk |

- Attack 중 재입력 → 무시 (타이머 리셋 없음)
- 중복 상태 진입 → `SetState()` 내부 early return

### PlayerAnimState enum
```csharp
public enum PlayerAnimState : byte { Idle, Walk, Run, Attack }
```
- `byte` 기반 → `NetworkVariable<byte>` 직접 사용 (커스텀 직렬화 불필요)

### AnimStateMapping (확장성)
```csharp
[System.Serializable]
public struct AnimStateMapping
{
    public PlayerAnimState state;
    public string animStateName;
}
```
- Inspector에서 배열로 관리 → 새 상태 추가 시 switch 수정 불필요
- `Awake()`에서 `Dictionary<PlayerAnimState, string>` 빌드 → O(1) 룩업

### 공격 애님 오버라이드 (`_attackAnimOverride`)
```csharp
private readonly NetworkVariable<FixedString64Bytes> _attackAnimOverride = new(
    default, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Server
);
```
- 빈 문자열이면 `_stateMappings` 기본값 사용
- NetworkVariable이므로 늦게 접속한 클라이언트도 현재 무기 상태 정확히 수신

---

## WeaponData 사용법

1. Assets 우클릭 → **Create → GNF → Weapon Data** → ScriptableObject 생성
2. Inspector에서 `attackAnimStateName`, `attackDuration` 설정
3. 서버 측 코드에서 `playerFSM.EquipWeapon(weaponData)` 호출

---

## 검증 절차
1. `Assets/Resources/Character.prefab`에 `PlayerFSM` 컴포넌트 추가 (에디터 필수)
2. NGO_Setup.unity 열기 → Play → Host 시작
3. 정지 → `Idle_Normal_NoWeapon` 재생 확인
4. WASD → `MoveFWD_Normal_InPlace_NoWeapon` 확인
5. Shift + WASD → `SprintFWD_Battle_InPlace_NoWeapon` 확인
6. 좌클릭(Attack) → `Attack01_NoWeapon` 재생, 약 1초 후 이동 상태 복귀 확인
7. Attack 중 재공격 → 타이머 리셋 없이 현 상태 유지 확인
8. ParrelSync Client → Host 조작 시 Client 화면 동기화 확인
9. 완료 → feature_list.json PLAYER-04 → `done`

---

## 주의 사항

| 항목 | 내용 |
|------|------|
| `PlayerFSM` 컴포넌트 누락 | `GetComponent<PlayerFSM>()` null → `_fsm?.Tick()` 전부 silent no-op. 검증 전 Character.prefab에 반드시 추가 필요 |
| `SprintFWD_Battle_InPlace_NoWeapon` ExitTime | Battle 계열 상태라 ExitTime 전환이 있을 수 있음. Run 상태가 즉시 이탈되면 Animator Controller 확인 필요 |
| Attack 지속 시간 | `_defaultAttackDuration = 1.0f`초는 `Attack01_NoWeapon` 실제 클립 길이와 다를 수 있음. 검증 후 Inspector에서 조정 |
| Attack 중 이동 | 물리(CharacterController)는 계속 동작 — 애니메이션만 Attack으로 고정됨 |

---

## 다음 권장 태스크
**COMBAT-01**: 서버 권위 HP 시스템 (`NetworkVariable<int>` + 사망 처리)
