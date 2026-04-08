# 23. ROLE-03: RoleStatModifier

## 세션 목표
플레이어 스폰 시 `LobbyRoleSelector`에서 역할 데이터를 읽어
`PlayerHealth`(최대 HP)와 `PlayerController`(이동속도)에 보정값을 서버 권위로 적용한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Role/RoleStatModifier.cs` | **신규**. 스폰 시 역할 스탯 적용 NetworkBehaviour |
| `Assets/Scripts/Player/PlayerHealth.cs` | `_maxHp` → `NetworkVariable<int>` 전환 + `ApplyRoleBonus()` 추가 |
| `Assets/Scripts/Player/PlayerController.cs` | `ApplyMoveSpeedMultiplier()` 추가 |
| `feature_list.json` | ROLE-03 → `in_progress` |

---

## 핵심 설계

### RoleStatModifier 흐름

```
RoleStatModifier.OnNetworkSpawn() [서버만]
    └─ LobbyRoleSelector.Instance?.GetRoleData(OwnerClientId)
    └─ null이면 경고 로그 + 기본 스탯 유지
    └─ PlayerHealth.ApplyRoleBonus(data.maxHpBonus)
    └─ PlayerController.ApplyMoveSpeedMultiplier(data.moveSpeedMultiplier)
    └─ Debug.Log 확인 로그
```

### PlayerHealth._maxHp NetworkVariable 전환 이유

기존 `[SerializeField] private int _maxHp`는 서버에서만 수정되고 클라이언트는 Inspector 기본값(100)을 그대로 가졌다.
`PlayerHealthBar.UpdateUI(current, max)`가 `max`도 표시하므로, 클라이언트에서 `max=100`으로 고정되면 Tank HP 150/150이 150/100으로 잘못 표시된다.

전환 후: `_baseMaxHp`(Inspector 기본값) + `_maxHp`(NetworkVariable) 분리.
- 서버: `OnNetworkSpawn`에서 `_maxHp.Value = _baseMaxHp` 초기화
- `ApplyRoleBonus(bonus)`: `_maxHp.Value += bonus`, `_currentHp.Value = _maxHp.Value`
- 클라이언트: `_maxHp.OnValueChanged` 구독으로 HP 바 갱신 수신

### PlayerController._moveSpeed는 NetworkVariable 불필요

`ApplyMovement()`가 `if (IsServer)` 조건 내에서만 실행되므로
`_moveSpeed`는 서버에서만 사용된다. 클라이언트는 이동 결과를 NetworkTransform으로 수신.

### 스폰 순서와 이중 쓰기

`PlayerHealth.OnNetworkSpawn` → `_currentHp.Value = 100` (기본값으로 초기화)
`RoleStatModifier.OnNetworkSpawn` → `ApplyRoleBonus(50)` → `_maxHp.Value = 150`, `_currentHp.Value = 150`

두 번의 NetworkVariable 쓰기가 발생하지만 스폰 직후라 플레이어가 전투 중이 아니므로 허용 범위.
클라이언트 HP 바는 100/100 → 150/150으로 즉시 갱신된다.

---

## 에디터 설정

Player 프리팹에 `RoleStatModifier` 컴포넌트 추가.
`LobbyRoleSelector` 씬 오브젝트가 먼저 스폰되어 있어야 `Instance`가 null이 아님.

---

## 검증 절차

1. Player 프리팹에 `RoleStatModifier` 컴포넌트 추가
2. `LobbyRoleSelector` 씬 오브젝트 설정 완료 확인 (ROLE-02 씬 설정 참고)
3. Host 시작 → **1** 키 (Tank 선택) → 콘솔 `[LobbyRoleSelector] Client 0 → Tank` 확인
4. 플레이어 스폰 후 콘솔 `[RoleStatModifier] Client 0 → Tank: HP+50, speed×1` 확인
5. HP 바에 `150 / 150` 표시 확인 (기본 100 + Tank +50)
6. Client 연결 → **2** 키 (DPS 선택) → HP 바 `100 / 100` 확인 (maxHpBonus=0)
7. 역할 미선택 클라이언트 스폰 → `[RoleStatModifier] 역할 미선택 — 기본 스탯 유지.` 경고 확인
8. 이동속도: DPS(moveSpeedMultiplier=1.0 기본), 필요 시 Healer 0.9 등 설정 후 체감 확인
9. 완료 → feature_list.json ROLE-03 → `done`

---

## 주의 사항

- `LobbyRoleSelector.Instance`가 null이면 `GetRoleData` 호출 불가 → 기본 스탯 유지(경고 로그). 씬에 `LobbyRoleSelector` 오브젝트가 반드시 먼저 스폰되어야 한다.
- `PlayerHealth._maxHp` 필드명이 `_baseMaxHp`로 변경됨. Inspector에서 기존 값이 유지되지 않으면 재입력 필요.

---

## 다음 권장 태스크

- **ROLE-04**: AggroMultiplier — `RoleStatModifier.GetModifiedAggro(float)` 구현 및 `AggroSystem` 연동
