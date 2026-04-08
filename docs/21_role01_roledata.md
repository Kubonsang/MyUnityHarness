# 21. ROLE-01-A / ROLE-01-B: RoleType & RoleData

## 세션 목표
역할군 시스템의 데이터 기반(RoleType enum + RoleData ScriptableObject)을 정의한다.
이후 ROLE-02 / ROLE-03 / ROLE-04가 이 파일을 참조한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Role/RoleType.cs` | **신규**. enum: None=0 / Tank=1 / DPS=2 / Healer=3 |
| `Assets/Scripts/Role/RoleData.cs` | **신규**. ScriptableObject: 6개 스탯 필드 |
| `feature_list.json` | ROLE-01-A, ROLE-01-B → `done` |

---

## 핵심 설계

### RoleData 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `roleType` | RoleType | 에셋 식별자 |
| `displayName` | string | 로비 UI 표시명 |
| `maxHpBonus` | int | 기본 HP에 더하는 절댓값 보너스 |
| `attackDamageMultiplier` | float [0.1~5] | 최종 데미지 배율 |
| `moveSpeedMultiplier` | float [0.1~3] | 이동속도 배율 |
| `aggroMultiplier` | float [0~10] | 데미지 어그로 배율 |
| `healPotencyMultiplier` | float [0.1~5] | 힐량 배율 (Healer 전용, SKILL 이후 사용) |

### maxHpBonus를 덧셈으로 선택한 이유

기획서에서 "Tank HP +50" 형태의 절대 보너스를 상정.
곱셈 방식은 기본 HP 변경 시 모든 역할군 수치가 연쇄적으로 바뀌는 부작용이 있어 덧셈 채택.
PlayerHealth에서 `_baseMaxHp + data.maxHpBonus`로 계산 (ROLE-03에서 구현).

### RoleType.None = 0

로비에서 역할 미선택 상태를 명시적으로 표현.
`NetworkVariable<byte>` 기본값 0이 "선택 안 됨"과 일치하도록 보장.
enum 항목 순서 변경 금지 — 순서가 바뀌면 기존 저장값이 깨짐.

---

## 에디터 설정

Assets 우클릭 → Create → GNF → Role Data로 3종 에셋 생성:

```
Tank   RoleData: roleType=Tank,   maxHpBonus=50,   aggroMultiplier=3.0, attackDamageMultiplier=0.8
DPS    RoleData: roleType=DPS,    maxHpBonus=0,    aggroMultiplier=0.5, attackDamageMultiplier=1.2
Healer RoleData: roleType=Healer, maxHpBonus=-20,  aggroMultiplier=0.3, healPotencyMultiplier=2.0
```

수치는 예시. Inspector에서 자유롭게 조정 가능.

---

## 검증 절차

1. Assets 우클릭 → Create → GNF → Role Data 에셋 생성 확인
2. Inspector에서 RoleType 드롭다운 표시 확인 (None / Tank / DPS / Healer)
3. 각 필드 Inspector 편집 가능 확인 (Range 슬라이더 포함)
4. 완료 → feature_list.json ROLE-01-A, ROLE-01-B → `done`

---

## 주의 사항

- `healPotencyMultiplier`는 SKILL 시스템 완성 전까지 참조하는 코드 없음.
- 실제 스탯 적용은 ROLE-03(PlayerRoleHandler)에서 구현.

---

## 다음 권장 태스크
- **ROLE-02**: LobbyRoleSelector — 서버 권위 역할 선택 로직 (역할 중복 불허 포함)
