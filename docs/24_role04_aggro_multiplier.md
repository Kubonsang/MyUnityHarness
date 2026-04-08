# 24. ROLE-04: AggroMultiplier

## 세션 목표
역할군별 `aggroMultiplier`를 데미지 어그로 계산에 반영한다.
Tank는 어그로를 더 많이 쌓고(×3.0), Healer/DPS는 적게 쌓아 몬스터 타겟 우선순위가 역할군에 따라 달라지게 한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Role/RoleStatModifier.cs` | static 레지스트리 + `GetAggroMultiplier(ulong)` 추가, `OnNetworkDespawn` 추가 |
| `Assets/Scripts/Monster/AggroSystem.cs` | `OnDamageDealt`에 `RoleStatModifier.GetAggroMultiplier()` 배율 곱하기 |
| `feature_list.json` | ROLE-04 → `in_progress` |

---

## 핵심 설계

### 어그로 배율 조회 흐름

```
AggroSystem.OnDamageDealt(amount, attackerClientId)
    └─ RoleStatModifier.GetAggroMultiplier(attackerClientId)   // static, O(1)
    └─ _aggroTable[attackerId] += amount × _aggroPerDamage × roleMultiplier
```

### static 레지스트리 선택 이유

`AggroSystem`은 `MonoBehaviour` (NetworkBehaviour 아님).
서버에서 실행되지만 직접 `NetworkManager`를 통해 플레이어 오브젝트를 찾는 것은 비용이 있다.
`RoleStatModifier.OnNetworkSpawn`에서 `_registry[OwnerClientId] = this`로 O(1) 접근 보장.
`OnNetworkDespawn`에서 `_registry.Remove(OwnerClientId)`로 누수 방지.

### 역할 미할당 방어

레지스트리에 없거나 `_roleData == null`이면 `GetAggroMultiplier`가 `1f` 반환.
기존 어그로 계산에 영향 없음.

---

## 에디터 설정

RoleData 에셋에 `aggroMultiplier` 설정 예시:
```
Tank   aggroMultiplier = 3.0
DPS    aggroMultiplier = 0.5
Healer aggroMultiplier = 0.3
```

---

## 검증 절차

1. 위 RoleData 에셋 수치 설정 확인
2. Host(Tank 선택) + Client(DPS 선택) 시작
3. Host(Tank)로 몬스터 공격 → 어그로 로그 확인
4. Client(DPS)로 동일 데미지 공격 → Tank 어그로가 DPS의 6배(3.0/0.5) 확인
5. `AggroSystem.GetTarget()`이 Tank를 우선 타겟으로 반환하는지 MonsterFSM 동작으로 확인
6. 완료 → feature_list.json ROLE-04 → `done`

---

## 주의 사항

- static `_registry`는 서버 전용. 클라이언트에서 호출하면 항상 1f 반환 (레지스트리가 비어있음).
- 근접 어그로(proximity aggro)에는 배율 미적용. 데미지 어그로에만 적용.

---

## 다음 권장 태스크

- **ROLE-05-A**: DPS 전용 무적 플래그(isInvincible) 통합
