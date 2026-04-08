# 17. MONSTER-08: MonsterObjectPool

## 세션 목표
NGO `INetworkPrefabInstanceHandler` 기반 오브젝트 풀 구현.
몬스터 사망 시 Destroy 대신 SetActive(false)로 풀 반환 → 재스폰 시 Instantiate 비용 제거.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/MonsterObjectPool.cs` | **신규**. INetworkPrefabInstanceHandler 풀 구현 |
| `Assets/Scripts/Monster/MonsterSpawner.cs` | `_monsterPrefab` → `_pool.GetFromPool()` 교체 |
| `Assets/Scripts/Monster/MonsterHealth.cs` | `Despawn(false)` → `Despawn(true)` (풀 반환 트리거) |
| `Assets/Scripts/Monster/MonsterFSM.cs` | Update()에 `!IsSpawned` 가드 추가 |
| `feature_list.json` | MONSTER-08 → `in_progress` |

---

## 핵심 설계

### INetworkPrefabInstanceHandler 역할 분담

| 호출 시점 | 호출 주체 | 메서드 | 동작 |
|-----------|-----------|--------|------|
| 서버 스폰 | MonsterSpawner | `GetFromPool()` | 풀에서 꺼냄 → `Spawn()` |
| 클라이언트 스폰 | NGO (spawn 메시지 수신) | `Instantiate()` | 풀에서 꺼냄 |
| 서버+클라이언트 사망 | NGO (`Despawn(true)`) | `Destroy()` | `SetActive(false)` → 풀 반환 |

### 풀 라이프사이클
```
Prewarm() → Stack에 N개 비활성 오브젝트 적재
    ↓
GetFromPool(pos, rot) → Pop → SetActive(true) → Spawn()
    ↓  (OnNetworkSpawn: HP 리셋, FSM Idle 리셋)
    ↓  [전투 진행]
HandleDeath() → Despawn(true)
    ↓
handler.Destroy() → SetActive(false) → Push (풀 반환)
    ↓
다음 스폰 인터벌 → GetFromPool() → 재사용
```

### 재스폰 시 상태 초기화 (자동)
`Spawn()` 호출 → `OnNetworkSpawn()` 재호출:
- `MonsterHealth.OnNetworkSpawn()` → `_currentHp.Value = _data.maxHp` ✓
- `MonsterFSM.OnNetworkSpawn()` → `EnterState(AiState.Idle)` ✓
- `MonsterAnimationController.OnNetworkSpawn()` → `ApplyAnimState(Idle)` ✓

### Despawn(true) vs Despawn(false)
- `Despawn(false)`: NGO 등록 해제만. handler.Destroy() **미호출** → 풀 반환 안 됨.
- `Despawn(true)`: handler.Destroy() **호출** → SetActive(false) → 풀 반환. ← 선택

---

## 에디터 설정

```
씬 Hierarchy:
└── MonsterObjectPool (GameObject)
    └── MonsterObjectPool (컴포넌트)
          _monsterPrefab: [몬스터 프리팹 — 동일 프리팹]
          _initialPoolSize: 5

└── MonsterSpawner (GameObject)
    ├── NetworkObject (컴포넌트)
    └── MonsterSpawner (컴포넌트)
          _pool: [MonsterObjectPool 컴포넌트 드래그]
          _spawnInterval: 5
          _spawnRadius: 15
          _maxMonsters: 10
```

### NetworkManager 필수 설정
`_monsterPrefab`은 NetworkManager → NetworkPrefabs 목록에도 등록 필요.
(INetworkPrefabInstanceHandler가 override하므로 실제 Instantiate는 핸들러가 담당)

---

## 검증 절차

1. 에디터 설정 완료 (위 참조)
2. Host 시작 → 몬스터 동적 스폰 확인
3. 몬스터 사망(HP 0) → Hierarchy에서 비활성화 확인 (제거가 아닌 SetActive(false))
4. 다음 스폰 인터벌 → 동일 오브젝트가 재활성화·재스폰 확인 (Hierarchy 오브젝트 수 동일)
5. 재스폰된 몬스터 HP 만땅 확인
6. 완료 → feature_list.json MONSTER-08 → `done`, MONSTER-02 → `done`

---

## MONSTER-02 연동

MONSTER-02 verification: "HP 0 → Despawn(destroy: false)"는 MONSTER-08에서 `Despawn(true)` + 풀 핸들러로 해결.
MONSTER-08 검증 완료 시 MONSTER-02도 `done` 처리 가능.

---

## 다음 권장 태스크
- **MONSTER-05**: AggroSystem — FindNearestPlayer() → AggroSystem.GetTarget() 교체
- **MONSTER-06**: MonsterManager — MonsterFSM.Update() 제거 + 배치 틱
