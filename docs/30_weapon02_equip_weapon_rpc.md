# 30. WEAPON-02: 서버 권위 무기 교체(EquipWeapon) 통신부 개발

## 세션 목표
클라이언트가 무기 장착 요청을 서버로 전송하고, 서버가 검증 후 `NetworkVariable<int>`로
모든 클라이언트에 장착 상태를 동기화하는 통신부를 구현한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerCombat.cs` | `MonoBehaviour` → `NetworkBehaviour` 전환, `NetworkVariable<int> _weaponId`, `EquipWeaponServerRpc`, `RequestEquipWeapon` API, `_weaponRegistry[]`, `OnNetworkSpawn/Despawn` 추가. `_networkObject` 필드 제거 |

---

## 핵심 설계

### 무기 교체 흐름

```
[클라이언트 IsOwner]
    RequestEquipWeapon(weaponId)
        ├─ IsServer → ServerEquip(weaponId)       // 호스트
        └─ !IsServer → EquipWeaponServerRpc(weaponId) → ServerEquip(weaponId)

[서버 ServerEquip]
    weaponId 범위 검증 (-1 허용, 범위 밖 → 거부 로그)
    _weaponId.Value = weaponId         // NetworkVariable 갱신 → 모든 클라이언트로 전파
    ApplyWeaponLocally(weaponId)       // 서버 즉시 로컬 적용

[클라이언트 OnWeaponIdChanged]
    ApplyWeaponLocally(newId)          // 클라이언트 로컬 적용

[공통 ApplyWeaponLocally]
    _equippedWeapon = _weaponRegistry[weaponId] (또는 null)
    if IsServer → _fsm?.EquipWeapon(weapon)  // FSM은 서버 전용
```

### 무기 레지스트리

```csharp
[SerializeField] private WeaponData[] _weaponRegistry = new WeaponData[0];
```

- 인덱스 = weaponId. 서버/클라이언트 모두 동일한 에셋을 Inspector에서 할당.
- `weaponId = -1`: 무기 미장착 (해제).

### NetworkVariable 선택 근거

무기 장착 상태는 영구 게임 상태 → `NetworkVariable<int>` 사용.
- 늦게 접속한 클라이언트도 `OnNetworkSpawn`에서 현재 값 수신 가능.
- RPC 단독으로 구현하면 늦은 접속자가 현재 장착 무기를 알 수 없음.

### 서버/클라이언트 권위 분리

| 동작 | 권위 |
|------|------|
| weaponId 검증 | 서버 |
| `_weaponId.Value` 갱신 | 서버 (`NetworkVariableWritePermission.Server`) |
| `_equippedWeapon` 로컬 적용 | 서버 + 클라이언트 각자 |
| `PlayerFSM.EquipWeapon()` | 서버 전용 (FSM은 서버 컴포넌트) |

---

## 에디터 설정

1. PlayerPrefab Inspector에서 `PlayerCombat._weaponRegistry` 배열에 WeaponData 에셋 할당.
   - 인덱스 0 = 기본 검, 인덱스 1 = 단검 등 프로젝트 규약에 따라 배열.
2. PlayerCombat이 `NetworkBehaviour`로 변경되었으므로 스크립트 참조 재확인.

---

## 검증 절차

1. PlayerPrefab의 `_weaponRegistry[0]`에 WeaponData 에셋(attackDamage ≠ 기본값) 할당.
2. Host 실행 → 로컬 플레이어 선택 → Inspector 또는 테스트 코드에서 `RequestEquipWeapon(0)` 호출.
3. 서버 Console에서 `[PlayerCombat] 무기 적용 → WeaponDataName (damage=N, range=N)` 확인.
4. Client 접속 → 동일 로그 출력 확인 (OnWeaponIdChanged 경로).
5. 늦게 접속한 Client에서도 현재 장착 무기가 적용되는지 확인 (OnNetworkSpawn 경로).
6. `RequestEquipWeapon(-1)` 호출 → 무기 해제, SerializeField 기본값 복귀 확인.
7. 검증 완료 시 feature_list.json WEAPON-02 → `done`

---

## 주의 사항

- `_weaponRegistry`는 서버/클라이언트가 동일한 배열 순서를 가져야 한다. 에셋 순서 변경 시 weaponId 기준이 달라짐.
- PlayerFSM.EquipWeapon()은 서버 전용이므로 클라이언트에서는 시각적 무기 교체(향후 구현)를 별도 처리해야 한다.

---

## 다음 권장 태스크

- **WEAPON-03**: 장착 무기의 직업 제한(RoleType) 검증 — `EquipWeaponServerRpc` 내부에 `allowedRoles` 체크 추가
