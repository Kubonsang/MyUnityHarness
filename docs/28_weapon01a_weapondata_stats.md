# 28. WEAPON-01-A: WeaponData 스탯 필드 추가

## 세션 목표
`WeaponData` ScriptableObject에 전투 스탯(`attackDamage`, `attackRange`)과 장착 제한(`allowedRoles`) 필드를 추가한다.
PlayerCombat 수정은 WEAPON-01-B에서 별도 진행한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/WeaponData.cs` | `attackDamage`, `attackRange`, `allowedRoles` 필드 추가 / Header 섹션 정리 |

---

## 핵심 설계

### 추가된 필드

```csharp
[Header("전투 스탯")]
public int attackDamage = 10;      // 1회 공격 데미지 (PlayerCombat 기본값과 동일)
public float attackRange = 2f;     // 공격 판정 반경 (PlayerCombat 기본값과 동일)

[Header("장착 제한")]
public RoleType[] allowedRoles = new RoleType[0];  // 빈 배열 = 모든 역할 허용
```

### 기본값 선택 이유

| 필드 | 기본값 | 이유 |
|------|--------|------|
| `attackDamage` | 10 | `PlayerCombat._attackDamage` 기존 SerializeField 기본값과 동일 |
| `attackRange` | 2f | `PlayerCombat._attackRange` 기존 SerializeField 기본값과 동일 |
| `allowedRoles` | 빈 배열 | 무기 미설정 시 모든 역할이 장착 가능한 기본 동작 |

### 타 태스크 연계

- **WEAPON-01-B**: `PlayerCombat`이 `_attackDamage` / `_attackRange` SerializeField 대신 장착된 `WeaponData`의 값을 읽도록 교체
- **WEAPON-03**: `PlayerCombat`이 `allowedRoles`로 장착 유효성 검증

---

## 검증 절차

1. Unity 에디터에서 Assets 우클릭 → `Create → GNF → Weapon Data`로 WeaponData 에셋 생성
2. Inspector에서 다음 필드 편집 가능 확인:
   - **애니메이션**: `attackAnimStateName`, `attackDuration`
   - **전투 스탯**: `attackDamage`, `attackRange`
   - **장착 제한**: `allowedRoles` (RoleType 배열)
3. 컴파일 오류 없음 확인
4. 검증 완료 시 feature_list.json WEAPON-01-A → `done`

---

## 다음 권장 태스크

- **WEAPON-01-B**: PlayerCombat 데미지를 장착된 WeaponData에서 읽도록 수정
