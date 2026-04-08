# 27. ROLE-05-B: DPS용 단순 전방 대쉬(Dummy Dash) 발동 뼈대

## 세션 목표
DPS 역할군 전용 전방 대쉬 스킬의 뼈대를 구현한다.
Q키 입력 → 서버 권위 검증 → CharacterController.Move() 전방 이동 + 무적(ROLE-05-A 연동).

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/InputSystem_Actions.inputactions` | `Dash` 버튼 액션 추가 (Q / Gamepad RightShoulder) |
| `Assets/InputSystem_Actions.cs` | 생성 파일에 Dash 액션 필드·프로퍼티·콜백 추가 |
| `Assets/Scripts/Role/RoleSkillController.cs` | **신규** — DPS 대쉬 로직 |
| `Assets/Scripts/Player/PlayerInputHandler.cs` | `_skillController` 참조 + Dash 이벤트 바인딩 |

---

## 핵심 설계

### 입력 흐름

```
Q 키 (로컬 오너)
  → PlayerInputHandler.OnDash()
  → RoleSkillController.SetDashPressed()
    → IsServer: TryDash() 직접 호출
    → 클라이언트: DashServerRpc() → 서버에서 TryDash()
```

### 대쉬 로직 (서버 전용)

```csharp
// TryDash() 검증 조건
if (roleType != RoleType.DPS) → 거부 로그 후 return
if (_dashTimer > 0 || _cooldownTimer > 0) → 거부 로그 후 return

// 대쉬 시작
_dashTimer = _dashDuration;       // 기본 0.2s
SetInvincible(true);              // ROLE-05-A 연동

// Update() 매 서버 프레임
CharacterController.Move(transform.forward * _dashSpeed * dt);  // 기본 15 m/s

// 대쉬 완료
_cooldownTimer = _dashCooldown;   // 기본 3s
SetInvincible(false);
```

### RoleSkillController Inspector 파라미터

| 파라미터 | 기본값 | 설명 |
|----------|--------|------|
| `_dashSpeed` | 15 | 대쉬 이동 속도 (m/s) |
| `_dashDuration` | 0.2 | 대쉬 지속 시간 (s) |
| `_dashCooldown` | 3 | 재사용 대기 (s) |

### Input 바인딩

| 장치 | 키 |
|------|-----|
| Keyboard | Q |
| Gamepad | RightShoulder (R1) |

---

## 에디터 설정

1. Player 프리팹에 `RoleSkillController` 컴포넌트 추가
2. `InputSystem_Actions.inputactions` 에셋 선택 → Inspector에서 `Reimport` → `InputSystem_Actions.cs` 자동 재생성 확인
   - ⚠️ 재생성 전까지 Dash 액션 미반영. 생성 파일(`InputSystem_Actions.cs`)은 이미 수동 업데이트 완료

---

## 검증 절차

1. Unity 에디터에서 `InputSystem_Actions.inputactions` 선택 → 우클릭 → `Reimport` 실행
2. Host 실행 → DPS 역할 플레이어 스폰
3. Q키 입력 → 서버 Console에 `대쉬 시작` 로그 확인
4. 대쉬 중 캐릭터가 전방으로 빠르게 이동 확인
5. 대쉬 중 몬스터 공격 → `무적 상태 — 데미지 N 무시` 로그 확인
6. 대쉬 완료 후 쿨다운(`3s`) 중 Q키 입력 → `쿨다운 N.N s 남음` 로그 확인
7. Tank/Healer 플레이어 Q키 → `DPS 역할 아님` 로그 확인
8. 완료 → feature_list.json ROLE-05-B → `done`

---

## 주의 사항

- `InputSystem_Actions.cs`는 Unity가 `.inputactions` 에셋 임포트 시 자동 재생성한다. 재생성되면 수동 추가분이 덮어씌워지므로, **재생성 후 Dash 액션이 유지되는지 확인**할 것. 재생성 후 빠진 항목은 다시 추가 필요.
- `_skillController`가 null이면 Dash 입력은 무시된다 (플레이어 프리팹에 컴포넌트 미추가 시).
- `PlayerHealth._isInvincible`은 NetworkVariable이 아니므로 클라이언트에서 시각 피드백(VFX) 필요 시 별도 동기화 필요.

---

## 다음 권장 태스크

- **WEAPON-01-A**: WeaponData 스탯 필드 추가 (attackDamage, attackRange 등)
