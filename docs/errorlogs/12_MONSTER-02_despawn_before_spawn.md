# MONSTER-02 / MONSTER-09 검증 실패: Despawn before NetworkObject was spawned

## 에러 메시지
```
[Netcode-Server Sender=0] [Monster][Attempted despawn before NetworkObject was spawned]
Unity.Netcode.NetworkObject:Despawn (bool)
MonsterHealth:HandleDeath () (at Assets/Scripts/Monster/MonsterHealth.cs:89)
MonsterHealth:ApplyDamage (int,ulong) (at Assets/Scripts/Monster/MonsterHealth.cs:77)
PlayerCombat:PerformAttack () (at Assets/Scripts/Player/PlayerCombat.cs:42)
```

## 근본 원인

씬에 배치된 몬스터 GameObject의 `NetworkObject`가 NGO 스폰 시스템에 등록되지 않은 상태에서 `HandleDeath()`가 `NetworkObject.Despawn(destroy: false)`를 호출.

### IsServer 가드가 통과되는 이유
- `IsServer`는 NetworkManager 전역 상태 기반 → Host 모드에서 항상 `true`
- `IsSpawned`는 이 특정 NetworkObject가 NGO에 등록됐는지 개별 판단 → 스폰 전 `false`
- 두 값이 독립적이기 때문에 `IsServer` 통과 후 `Despawn()` 에러 발생

### 스폰이 안 된 이유 (추정)
씬에 프리팹을 배치했지만 NGO의 in-scene NetworkObject로 올바르게 설정되지 않았거나,
Host 시작 전에 테스트를 시도했을 가능성.

---

## 적용된 수정 (MonsterHealth.cs)

```csharp
public void ApplyDamage(int amount, ulong attackerClientId)
{
    if (!IsServer) return;
    if (!IsSpawned) return;  // ← 추가: NGO 스폰 전 Despawn/NetworkVariable 쓰기 방지
    if (amount <= 0) return;
    ...
}
```

`HandleDeath`가 아닌 `ApplyDamage` 진입부에 가드를 배치 → NetworkVariable 쓰기(`_currentHp`)와 `Despawn()` 모두 차단.

---

## 2차 실패: HP 0이 되어도 Despawn 미발생 (에러 없음)

### 원인
`HandleDeath()` 는 정상 호출됨 (Debug.Log로 HP=0 확인 후 동기적으로 실행).
`Despawn(destroy: false)`가 실행되지만 **in-scene placed NetworkObject에서는 GameObject를 SetActive(false)로 전환하는 것을 NGO가 보장하지 않음**.
NGO 2.x는 in-scene 오브젝트를 씬 생명주기에 묶어 관리하므로 `destroy: false`가 의도대로 동작하지 않는 경우 존재.

### 적용된 수정 (MonsterHealth.cs — HandleDeath)

```csharp
// 변경 전
NetworkObject.Despawn(destroy: false);

// 변경 후
NetworkObject.Despawn(destroy: true);  // in-scene 오브젝트 테스트용. MONSTER-07/08 구현 시 destroy: false로 복원
```

**trade-off**: `destroy: true`는 풀링 불가. MONSTER-07(동적 스폰) + MONSTER-08(NGO NetworkObjectPool) 구현 시 동적으로 생성된 오브젝트에서 `destroy: false`로 복원.

---

## 재검증 절차

1. Host 시작 → Inspector `NetworkObject.IsSpawned = true` 확인
2. 플레이어 공격 → `[MonsterHealth] ... 피해를 입었습니다.` 로그 확인
3. HP 0 → 오브젝트가 Hierarchy에서 완전히 사라지는 것 확인 (`destroy: true`)
4. 완료 → feature_list.json MONSTER-02, MONSTER-09 → `done`

---

## 현재 상태
- MONSTER-02: `test_failure` → 수정 적용 (destroy:true), 재검증 필요
- MONSTER-09: `test_failure` → 동일 재검증 필요

---

## 재발 방지
MONSTER-07 MonsterSpawner: 서버가 `Instantiate` + `networkObject.Spawn()` → `destroy: false` 복원 가능.
현재: in-scene 배치 오브젝트 → `destroy: true` 임시 사용.
