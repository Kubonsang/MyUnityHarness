# 12. MONSTER-02: MonsterHealth

## 세션 목표
서버 권위 몬스터 HP 시스템 구현. PlayerHealth 패턴을 기반으로 `attackerClientId` 전달과 `Despawn(destroy: false)`(풀 반환)을 추가.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/MonsterHealth.cs` | **신규**. NetworkBehaviour. ApplyDamage(amount, attackerClientId) + OnDamageDealt 이벤트 |
| `feature_list.json` | MONSTER-02 → `in_progress` |

---

## PlayerHealth와의 차이점

| 항목 | PlayerHealth | MonsterHealth |
|------|-------------|---------------|
| maxHp 소스 | `[SerializeField] int _maxHp` | `MonsterData._data.maxHp` |
| ApplyDamage 시그니처 | `ApplyDamage(int amount)` | `ApplyDamage(int amount, ulong attackerClientId)` |
| 추가 이벤트 | 없음 | `OnDamageDealt(int amount, ulong attackerClientId)` |
| 사망 Despawn | `Despawn(destroy: true)` | `Despawn(destroy: false)` ← 풀 반환 |
| ApplyHeal | 있음 | 없음 (몬스터 회복 미지원) |

---

## 핵심 설계

### 동작 흐름
```
[Server] MonsterFSM Attack → ApplyDamage(damage, attackerClientId)
    → _currentHp(NetworkVariable) 갱신
    → OnDamageDealt(amount, attackerClientId) 발생
         ↓ AggroSystem(MONSTER-05)이 구독
    AggroSystem._aggroTable[attackerClientId] += amount * aggroPerDamage

    HP 0 → HandleDeath() → Despawn(destroy: false)
         ↓ MonsterObjectPool(MONSTER-08)이 풀에 반환
    재스폰 시 OnNetworkSpawn() → _currentHp.Value = _data.maxHp
```

### OnDamageDealt 발생 순서
HP 차감 **후** 이벤트 발생 → AggroSystem이 올바른 HP 상태에서 구독 처리 가능.

### Despawn(destroy: false) 이유
- `destroy: true`: 오브젝트 파괴 → 재스폰 시 새로 Instantiate 필요
- `destroy: false`: 오브젝트 비활성화 → MONSTER-08 풀에서 재사용. Instantiate 비용 제거.

### MonsterData null 처리
서버 `OnNetworkSpawn()`에서 `_data == null` 시 `Debug.LogError` 출력 후 return.
클라이언트는 서버가 이미 설정한 `_currentHp.Value`를 동기화받으므로 별도 null 체크 불필요.

---

## 에디터 설정

```
몬스터 프리팹 루트:
├── NetworkObject (컴포넌트)
└── MonsterHealth (컴포넌트)
      _data: [MonsterData 에셋 할당]
```

---

## 검증 절차

1. Unity 에디터 컴파일 확인 (오류 없음)
2. 몬스터 프리팹에 `MonsterHealth` 추가 + `MonsterData` 에셋 할당
3. NGO_Setup.unity → Play → Host 시작
4. Inspector → `MonsterHealth._currentHp` = 50 확인 (MonsterData.maxHp 기본값)
5. ContextMenu "Get Damage 10" → `_currentHp` = 40 확인
6. `_currentHp` = 0 → `Despawn(destroy: false)` → 오브젝트 비활성화 확인 (Hierarchy에서 사라짐)
7. 완료 → feature_list.json MONSTER-02 → `done`

---

## 주의 사항

| 항목 | 내용 |
|------|------|
| `_data == null` | MonsterData 미할당 시 서버 OnNetworkSpawn에서 HP 초기화 안 됨. LogError로 감지 가능 |
| Despawn(destroy: false) 후 재활성화 | MONSTER-08 구현 전까지 오브젝트가 비활성 상태로 풀에 쌓임. 현재 단계에서는 정상 동작 |
| ContextMenu attackerClientId = 0 | 테스트용으로 0 전달. AggroSystem 구현 후 실제 ID 사용 |

---

## 다음 권장 태스크
- **MONSTER-03**: MonsterAnimationController — NetworkVariable&lt;byte&gt; 상태 동기화
- **MONSTER-09**: IDamageable 인터페이스 — MONSTER-02와 병행 가능
