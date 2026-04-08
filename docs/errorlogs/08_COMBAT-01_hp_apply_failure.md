# COMBAT-01 — HP 데미지 미적용 오류

## 현상
`PlayerHealth`의 `[ContextMenu("Apply 10 Damage")]` 실행 시 HP가 감소하지 않음.

---

## 원인 분석

### 유력 원인 1: `Character.prefab`에 `PlayerHealth` 컴포넌트 미추가
- `PlayerHealth`가 프리팹에 없으면 스폰된 플레이어에 컴포넌트가 존재하지 않음
- `OnNetworkSpawn()` 미호출 → NetworkBehaviour로 등록 안 됨
- `IsServer`는 NetworkBehaviour가 NetworkObject에 스폰된 이후에만 `true` 반환
- **결과**: `ApplyDamage` 내 `if (!IsServer) return` 에서 즉시 반환

### 유력 원인 2: `[ContextMenu]`는 로컬 호출 — `IsServer` false
- `[ContextMenu]`는 `[ServerRpc]`가 아닌 일반 메서드
- 메서드명이 `Apply10DamageServerRpc`이나 실제로 RPC 전송 없음
- 에디터에서 Client 인스턴스(ParrelSync 등) 또는 스폰 전 오브젝트에서 실행 시 `IsServer == false`
- **결과**: 동일하게 `ApplyDamage` guard에서 차단

---

## 검증 체크리스트

```
[ ] Character.prefab에 PlayerHealth 컴포넌트가 실제로 추가되어 있는가?
[ ] ContextMenu를 실행한 인스턴스가 Host(Server) 인스턴스인가?
[ ] Play 모드 진입 후 NetworkManager가 Started 상태인가? (스폰 전 실행 시 IsServer == false)
[ ] Inspector에서 PlayerHealth > _currentHp 의 초기값이 100으로 표시되는가? (OnNetworkSpawn 정상 실행 여부 확인)
```

---

## 영향
- COMBAT-01 verification 실패
- `ApplyHeal`도 동일한 `if (!IsServer) return` 가드이므로 같은 문제 존재

---

## 복구 방향
1. `Character.prefab`에 `PlayerHealth` 컴포넌트 추가 (에디터 필수 작업)
2. Play → Host 시작 → 스폰된 플레이어 오브젝트를 Inspector에서 선택
3. `_currentHp` 값이 100인지 확인 (OnNetworkSpawn 정상 여부 판단)
4. 그 상태에서 ContextMenu 재실행 → HP 감소 여부 확인

---

## 현재 status
- `feature_list.json`: COMBAT-01 → `test_failure`
