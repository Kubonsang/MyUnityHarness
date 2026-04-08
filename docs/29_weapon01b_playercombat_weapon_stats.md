# 29. WEAPON-01-B: PlayerCombat 데미지를 장착된 무기에서 읽도록 수정

## 세션 목표
`PlayerCombat`이 `attackDamage` / `attackRange`를 SerializeField 하드코딩 대신
장착된 `WeaponData`에서 읽도록 수정한다.
무기 미장착 시 SerializeField 기본값으로 폴백해 하위 호환성을 유지한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerCombat.cs` | `_equippedWeapon` 필드, `CurrentDamage`/`CurrentRange` 프로퍼티 추가. ※ WEAPON-02에서 `EquipWeapon()` API는 `RequestEquipWeapon()` + `ApplyWeaponLocally()`로 재설계됨 |
| `Assets/Scripts/Player/PlayerFSM.cs` | WEAPON-01-B 시점: `_combat` 필드 캐싱 + `EquipWeapon()`에서 `_combat?.EquipWeapon()` 호출. ※ WEAPON-02에서 흐름 역전으로 `_combat` 역참조 제거됨 |

---

## 핵심 설계

### 무기 스탯 조회 경로

```csharp
// PlayerCombat.cs
private int   CurrentDamage => _equippedWeapon != null ? _equippedWeapon.attackDamage : _attackDamage;
private float CurrentRange  => _equippedWeapon != null ? _equippedWeapon.attackRange  : _attackRange;

public void PerformAttack()
{
    Collider[] hits = Physics.OverlapSphere(transform.position, CurrentRange);
    foreach (var hit in hits)
        target.ApplyDamage(CurrentDamage, attackerClientId);
}
```

### 무기 장착 흐름 (WEAPON-01-B 시점)

```
PlayerFSM.EquipWeapon(weapon)
  → _animController.SetAttackStateName()   ← 애니메이션 처리
  → _combat.EquipWeapon(weapon)            ← 전투 스탯 교체
```

> ※ WEAPON-02에서 흐름이 역전됨. 현재(WEAPON-02 이후) 실제 흐름:
> ```
> PlayerCombat.ApplyWeaponLocally(weaponId)
>   → _equippedWeapon 갱신              ← 전투 스탯 교체
>   → _fsm.EquipWeapon(weapon)          ← 애니메이션 처리
> ```

### 폴백 설계

| 상태 | 데미지 | 범위 |
|------|--------|------|
| 무기 미장착 | `PlayerCombat._attackDamage` SerializeField | `PlayerCombat._attackRange` SerializeField |
| 무기 장착됨 | `WeaponData.attackDamage` | `WeaponData.attackRange` |

SerializeField 기본값은 Inspector에서 조정 가능하므로 무기 미구현 구간에서도 동작 유지.

---

## 검증 절차

1. WeaponData 에셋 생성 (`attackDamage=30`, `attackRange=3` 등 기본값과 다른 수치 설정)
2. `PlayerCombat` Inspector → `Test/Request Equip Weapon`으로 장착 요청
3. 서버 Console에서 `[PlayerCombat] 무기 적용 → WeaponDataName (damage=30, range=3)` 로그 확인
4. 공격 시 WeaponData 수치가 반영되는지 몬스터 HP 변화로 확인
5. `Test/Request Unequip` 호출 후 SerializeField 기본값으로 복귀 확인
6. 검증 완료 시 feature_list.json WEAPON-01-B → `done`

---

## 다음 권장 태스크

- **WEAPON-02**: ✅ 완료 — 클라이언트 요청 → ServerRpc → NetworkVariable 전파
- **WEAPON-03**: ✅ 완료 — allowedRoles 직업 제한 검증 + EquipFailedClientRpc
