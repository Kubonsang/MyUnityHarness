# 31. WEAPON-03: 장착 무기의 직업 제한(RoleType) 검증 체계 구현

## 세션 목표
`PlayerCombat.ServerEquip()` 내부에 `WeaponData.allowedRoles` 검증을 추가해,
허용되지 않은 직업의 무기 장착 요청을 서버에서 거부하고 요청 클라이언트에게 통보한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerCombat.cs` | `_roleStatModifier` 필드 추가, `IsRoleAllowed()` 검증 메서드, `EquipFailedClientRpc` 추가. `ServerEquip()`에 직업 제한 분기 삽입 |

---

## 핵심 설계

### 검증 흐름

```
ServerEquip(weaponId)
    ① weaponId 범위 검증 (기존 WEAPON-02)
    ② IsRoleAllowed(weapon)
        - allowedRoles.Length == 0 → 모든 직업 허용 (pass)
        - allowedRoles에 플레이어 직업 포함 → 허용 (pass)
        - 불포함 → 거부
            → EquipFailedClientRpc → 오너 클라이언트 Console 경고
            → return (NetworkVariable 갱신 없음)
    ③ 통과 시 기존 장착 로직 실행
```

### IsRoleAllowed()

```csharp
private bool IsRoleAllowed(WeaponData weapon)
{
    if (weapon.allowedRoles == null || weapon.allowedRoles.Length == 0) return true;
    RoleType playerRole = _roleStatModifier?.RoleData?.roleType ?? RoleType.DPS;
    foreach (var role in weapon.allowedRoles)
        if (role == playerRole) return true;
    return false;
}
```

- `RoleStatModifier.RoleData`가 null이면 (역할 미선택) DPS로 폴백.
- `foreach`로 순회 — 배열 크기가 최대 직업 수(~4)이므로 LINQ 불필요.

### EquipFailedClientRpc

```csharp
[ClientRpc]
private void EquipFailedClientRpc(string weaponName, RoleType playerRole,
    ClientRpcParams rpcParams = default)
```

- `ClientRpcParams.Send.TargetClientIds = new[] { OwnerClientId }` — 요청자에게만 전송.
- 현재는 Console 경고. 향후 UI 알림 텍스트로 교체 가능.

### 역할 조회 경로

`PlayerCombat._roleStatModifier` → `RoleStatModifier.RoleData` → `RoleData.roleType`

`RoleStatModifier`는 같은 GameObject에 있으므로 `Awake()`에서 `GetComponent<>()`로 캐싱.

---

## 검증 절차

1. WeaponData 에셋 생성. `allowedRoles`에 `Tank`만 설정.
2. Host(DPS 역할) 로컬 플레이어에서 `RequestEquipWeapon(weaponId)` 호출.
3. 서버 Console: `직업 제한 — DPS은(는) WeaponName 장착 불가` 로그 확인.
4. 클라이언트 Console: `장착 거부: WeaponName — 현재 직업(DPS)은 이 무기를 사용할 수 없습니다.` 확인.
5. HP, 데미지 등 장착 상태 변화 없음 확인 (NetworkVariable 갱신 없어야 함).
6. Tank 역할로 동일 무기 장착 시 정상 장착 확인.
7. `allowedRoles`가 비어있는 무기는 모든 직업 장착 가능 확인.
8. 검증 완료 시 feature_list.json WEAPON-03 → `done`

---

## 다음 권장 태스크

- **ITEM-01-A**: ItemData SO 설계 및 ItemType enum 정의
