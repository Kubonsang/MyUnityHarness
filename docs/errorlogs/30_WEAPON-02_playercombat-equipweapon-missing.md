# 30_WEAPON-02: PlayerFSM에서 PlayerCombat.EquipWeapon() 미존재 컴파일 오류

## 증상

```
Assets/Scripts/Player/PlayerFSM.cs(48,17): error CS1061:
'PlayerCombat' does not contain a definition for 'EquipWeapon'
and no accessible extension method 'EquipWeapon' accepting a first
argument of type 'PlayerCombat' could be found
```

WEAPON-02 구현 후 Unity 컴파일 오류 발생.

## Root Cause

WEAPON-01-B에서 `PlayerFSM.EquipWeapon()`이 `_combat.EquipWeapon(weapon)`을 호출하도록 설계됐다.
WEAPON-02에서 `PlayerCombat`의 무기 장착 진입점을 `RequestEquipWeapon(int weaponId)` + 내부 `ApplyWeaponLocally()`로 재설계하면서
`PlayerCombat.EquipWeapon(WeaponData)` 공개 메서드가 제거됐다.

결과적으로 호출 방향이 역전됐음에도 `PlayerFSM`의 역참조 코드가 남아 있었다:

```
[이전 - WEAPON-01-B]
PlayerFSM.EquipWeapon(weapon)
    → _animController.SetAttackStateName()
    → _combat.EquipWeapon(weapon)   ← 이 방향

[이후 - WEAPON-02]
PlayerCombat.ApplyWeaponLocally(weaponId)
    → _fsm.EquipWeapon(weapon)      ← 역전된 방향
        → _animController.SetAttackStateName()
```

## 수정 내용

`Assets/Scripts/Player/PlayerFSM.cs`:

- `_combat PlayerCombat` 필드 제거
- `Awake()`에서 `_combat = GetComponent<PlayerCombat>()` 제거
- `EquipWeapon()` 내부의 lazy init `if (_combat == null) ...` 및 `_combat?.EquipWeapon(weapon)` 제거

`PlayerFSM.EquipWeapon()`은 이제 애니메이션 상태 이름 설정만 담당한다.
무기 스탯 교체(`_equippedWeapon`)는 `PlayerCombat.ApplyWeaponLocally()`가 직접 처리한다.

## 검증 결과

수정 후 컴파일 오류 해소 (Unity 에디터 재컴파일 필요).
