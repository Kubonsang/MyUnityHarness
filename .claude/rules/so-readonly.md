## ScriptableObject Read-Only Rule

기획 데이터(`RoleData`, `WeaponData`, `MonsterData` 등)의 무결성을 보장하기 위한 규칙입니다.

1. **런타임 쓰기 절대 금지:** `ScriptableObject` 클래스 내부에 런타임에서 변하는 상태값(예: `currentHp`, `currentCooldown`)을 정의하지 마십시오. 에디터 환경에서 SO를 수정하면 프로젝트 에셋 원본이 오염됩니다.
2. **상태 분리 패턴:** SO는 오직 "기본/최대/고정 수치"만을 제공해야 하며, 런타임 상태는 이 SO를 참조하는 별도의 `NetworkVariable` 이나 로컬 인스턴스화된 래퍼(Wrapper) 클래스에서 관리해야 합니다.