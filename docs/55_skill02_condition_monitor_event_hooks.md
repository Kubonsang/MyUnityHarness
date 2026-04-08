## 세션 목표
- `SKILL-02` 완료.
- `SkillConditionMonitor`를 추가하고, `PlayerCombat`/`PlayerHealth` 이벤트와 `PlayerInventory` 아이템 스킬 등록 경로를 연결해 런타임에서 타격/피격 이벤트 수신 로그가 발생하도록 만든다.

## 변경된 파일
- `feature_list.json`
- `Assets/Scripts/Skill/SkillConditionMonitor.cs`
- `Assets/Scripts/Player/PlayerCombat.cs`
- `Assets/Scripts/Player/PlayerHealth.cs`
- `Assets/Scripts/Item/PlayerInventory.cs`
- `Assets/Resources/Character.prefab`

## 핵심 설계
- `SkillConditionMonitor`를 서버 전용 `NetworkBehaviour`로 추가하고, `PlayerCombat.OnHitTarget`, `PlayerHealth.OnTakeDamage`를 `OnNetworkSpawn`에서 구독하도록 구성했다.
- `SkillConditionMonitor`는 아직 효과를 적용하지 않고, 등록된 `SkillEntry` 중 `HitAny`, `HitN`, `Damaged` 조건에 해당하는 엔트리 수를 계산해 로그만 남긴다. 실제 효과 적용은 `SKILL-03`로 넘긴다.
- `PlayerInventory`는 아이템 추가/제거 시 `ItemData.skills`를 `SkillConditionMonitor.AddEntries/RemoveEntries`에 연결하도록 변경했다.
- `PlayerCombat`는 적중 시 `OnHitTarget` 이벤트를 발행하고, 서버 무기 교체 시 무기 스킬 엔트리를 `ReplaceWeaponEntries()`로 교체하도록 연결했다.
- 실제 플레이어 런타임에서 동작하도록 `Assets/Resources/Character.prefab`에 `SkillConditionMonitor` 컴포넌트를 추가했다.

## 검증 절차
- 컴파일: `unity-cli editor refresh --compile`
- 에러 확인: `unity-cli console --filter error --stacktrace short`
- 결과: `[]`
- 런타임 검증:
- `unity-cli editor play --wait`
- `unity-cli exec`로 Host 환경에서 임시 `ItemRegistry`/`ItemData`/`ItemSkillData`를 만들고, `HitAny` + `Damaged` 엔트리를 가진 아이템을 플레이어 인벤토리에 추가
- 같은 런타임 하네스에서 `PlayerCombat.PerformAttack()`와 `PlayerHealth.ApplyDamage(7, 99)`를 호출
- 수신 로그 결과:
- `[SkillConditionMonitor] 엔트리 등록: Skill02_TestAsset +2 (client=0)|[SkillConditionMonitor] Hit 이벤트 수신: target=6, matched=1 (client=0)|[SkillConditionMonitor] Hit 이벤트 수신: target=1, matched=1 (client=0)|[SkillConditionMonitor] Damaged 이벤트 수신: amount=7, attacker=99, matched=1 (client=0)`
- Play Mode 종료 후 에러 콘솔 재확인 결과: `[]`

## 주의 사항
- 이번 task는 이벤트 등록과 감시 로그까지만 구현했다. 실제 `EffectType` 해석과 `IStatusEffectable.ApplyEffect` 연결은 `SKILL-03`에서 구현해야 한다.
- 검증 하네스의 `Hit` 로그는 열린 씬의 다른 콜라이더 영향으로 2회 찍힐 수 있었다. 이번 task의 완료 기준은 “적어도 하나의 Hit/Damaged 수신 로그가 발생하는지”였고, 그 조건은 충족했다.

## 다음 권장 태스크
- `SKILL-03` `Condition 판정 로직과 Effect 부여 연동 (IStatusEffectable 경로)`
