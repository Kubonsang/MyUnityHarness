## 세션 목표
- `SKILL-01` 완료.
- 스킬 시스템의 데이터 계층 뼈대(`ConditionType`, `EffectType`, `SkillEffectDef`, `SkillEntry`, `ItemSkillData`)를 추가하고, `ItemData`/`WeaponData`에서 이를 참조할 수 있게 한다.

## 변경된 파일
- `feature_list.json`
- `Assets/Scripts/Skill/ConditionType.cs`
- `Assets/Scripts/Skill/EffectType.cs`
- `Assets/Scripts/Skill/SkillEffectDef.cs`
- `Assets/Scripts/Skill/SkillEntry.cs`
- `Assets/Scripts/Skill/ItemSkillData.cs`
- `Assets/Scripts/Item/ItemData.cs`
- `Assets/Scripts/Player/WeaponData.cs`

## 핵심 설계
- `ConditionType`는 설계 문서 기준으로 `Time`, `HitAny`, `HitN`, `Damaged`, `Kill`, `HpLow`, `Dodge`를 정의했다.
- `EffectType`는 즉발 `Damage`, 기존 `StatusEffectType`과 이름을 맞춘 상태 효과군, 그리고 후속 task용 `Projectile`을 포함했다.
- `SkillEffectDef`와 `SkillEntry`는 인스펙터 조합이 쉬운 `[System.Serializable]` 데이터 클래스로 두고, 효과 목록은 `List<SkillEffectDef>`로 구성했다.
- `ItemSkillData`는 `CreateAssetMenu(menuName = "GNF/Skill Data")`를 제공하는 ScriptableObject로 추가했다.
- `ItemData`, `WeaponData`에 `ItemSkillData[] skills` 필드를 열어 이후 `PlayerInventory`/`PlayerCombat` 연동 전에도 데이터 조립이 가능하게 했다.

## 검증 절차
- 컴파일: `unity-cli editor refresh --compile`
- 에러 확인: `unity-cli console --filter error --stacktrace short`
- 결과: `[]`
- 에디터 직렬화 검증: `unity-cli exec`로 `ItemSkillData` 인스턴스를 만들고 `SkillEntry` 1개 + `SkillEffectDef` 2개를 조립한 뒤, `SerializedObject`로 `entries/effects`와 `ItemData.skills`, `WeaponData.skills` 배열을 확인
- 결과: `entryCount=1;firstCond=HitN;firstCondParam=3;effectCount=2;firstEffect=Stun;itemSkills=1;weaponSkills=1`

## 주의 사항
- 이번 task는 데이터 계층만 추가했다. 실제 이벤트 감시와 효과 적용은 `SKILL-02`, `SKILL-03`, `SKILL-04`에서 이어진다.
- 새 `Skill/` 스크립트와 `skills` 필드는 컴파일 후 Unity가 `.meta`를 생성하므로, 다음 커밋 시 생성된 메타 파일 포함 여부를 함께 확인하는 것이 좋다.

## 다음 권장 태스크
- `SKILL-02` `SkillConditionMonitor 런타임 이벤트 등록 로직`
