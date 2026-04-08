# 29_WEAPON-01-B: PlayerFSM EquipWeapon() 호출 시 _animController null

## 증상
`PlayerFSM.EquipWeapon()`을 에디터에서 호출(ContextMenu 또는 테스트 코드)하면
`_animController`가 null이어서 `SetAttackStateName()`이 실행되지 않음.

## Root Cause
Edit Mode에서 Inspector ContextMenu로 `EquipWeapon()`을 호출하면
`Awake()`가 실행되지 않은 상태이므로 `_animController`와 `_combat`이 null.

## 수정 내용
`Assets/Scripts/Player/PlayerFSM.cs` — `EquipWeapon()` 내부에 null 체크 + 지연 초기화 추가:

```csharp
public void EquipWeapon(WeaponData weapon)
{
    _currentWeapon = weapon;

    if (_animController == null) _animController = GetComponent<PlayerAnimationController>();
    if (_combat == null)         _combat         = GetComponent<PlayerCombat>();

    _animController?.SetAttackStateName(weapon != null ? weapon.attackAnimStateName : string.Empty);
    _combat?.EquipWeapon(weapon);
}
```

추가로 `#if UNITY_EDITOR` 블록에 ContextMenu 테스트 메서드 추가:
- `Test/Equip Test Weapon` — `_testWeaponAsset` SerializeField 장착
- `Test/Unequip Weapon` — 무기 해제

## 검증 결과
수정 후 ContextMenu에서 `EquipWeapon()` 호출 시 정상 동작 확인 (사용자 검증 완료).

## 후속 변경 이력
WEAPON-02에서 무기 교체 흐름이 역전되면서 이 errorlog의 수정 내용 중 일부가 다시 변경됨:

- `_combat` 필드 및 lazy init 코드 → **제거** (PlayerFSM이 PlayerCombat을 더 이상 참조하지 않음)
- `_combat?.EquipWeapon(weapon)` 호출 → **제거**
- `#if UNITY_EDITOR` ContextMenu 테스트 블록 전체 → **제거** (PlayerCombat의 `Test/Request Equip Weapon`으로 대체)

현재 `PlayerFSM.EquipWeapon()`은 `_animController.SetAttackStateName()` 호출만 담당하며,
`PlayerCombat.ApplyWeaponLocally()`에서 서버 전용으로 호출된다.
