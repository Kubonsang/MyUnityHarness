# 16. MONSTER-07: MonsterSpawner

## 세션 목표
서버 전용 연속 스포너 구현. 동적 스폰(`Instantiate` + `NetworkObject.Spawn()`)으로 in-scene 배치 방식의 NGO 호환 문제를 근본 해결.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/MonsterSpawner.cs` | **신규**. NetworkBehaviour 기반 연속 스포너 |
| `feature_list.json` | MONSTER-07 → `in_progress` |

---

## 핵심 설계

### 동적 스폰이 중요한 이유
- in-scene 배치 NetworkObject: NGO가 `Despawn(false)` 시 내부적으로 Destroy 처리 → 에디터 MissingReferenceException
- **동적 스폰 (`Instantiate` + `Spawn()`)**: `Despawn(false)` = SetActive(false), `Despawn(true)` = Destroy — 의도대로 동작

### 활성 몬스터 카운트 관리
별도 이벤트 구독 없이 `_spawnedMonsters` 리스트를 스폰 시점에 정리:
```csharp
for (int i = _spawnedMonsters.Count - 1; i >= 0; i--)
{
    if (_spawnedMonsters[i] == null || !_spawnedMonsters[i].IsSpawned)
        _spawnedMonsters.RemoveAt(i);
}
```
저빈도(spawnInterval) 호출이므로 O(n) 정리 허용.

### 스폰 위치
`Random.insideUnitCircle * _spawnRadius` → `NavMesh.SamplePosition()` → 실제 NavMesh 위치.
샘플 실패 시 해당 틱 스폰 건너뜀.

---

## 에디터 설정

```
씬 Hierarchy:
└── MonsterSpawner (GameObject)
    ├── NetworkObject (컴포넌트) ← 필수
    └── MonsterSpawner (컴포넌트)
          _monsterPrefab: [몬스터 프리팹 — NetworkObject + MonsterHealth + MonsterFSM 포함]
          _spawnInterval: 5
          _spawnRadius: 15
          _maxMonsters: 10
```

### 몬스터 프리팹 필수 컴포넌트
```
MonsterPrefab:
├── NetworkObject
├── NavMeshAgent
├── Animator
├── CapsuleCollider       ← PlayerCombat OverlapSphere 탐지용
├── MonsterHealth         ← _data: MonsterData 에셋 할당
├── MonsterAnimationController ← State Mappings 설정
└── MonsterFSM            ← _data: 동일 MonsterData 에셋 할당
```

---

## 검증 절차

1. 씬에 NavMesh 베이크 확인
2. MonsterSpawner 오브젝트 생성 + 프리팹 할당
3. Host 시작 → `_spawnInterval`초 후 몬스터 Hierarchy에 동적 생성 확인
4. 몬스터 수 `_maxMonsters` 도달 시 추가 스폰 중단 확인
5. 몬스터 사망(HP 0) → Hierarchy에서 제거 → 다음 스폰 인터벌에 재생성 확인
6. 완료 → feature_list.json MONSTER-07 → `done`

---

## MONSTER-08 연동 예정

현재: `Instantiate` + `Spawn(destroyWithScene: true)` — 매 스폰마다 Instantiate 비용 발생.
MONSTER-08: NGO NetworkObjectPool 도입 → `GetNetworkObject()` + `Spawn()` — Instantiate 없이 재사용.

---

## 다음 권장 태스크
- **MONSTER-04 최종 검증**: 동적 스폰 후 FSM 동작 확인 → done 처리
- **MONSTER-05**: AggroSystem — MonsterFSM.FindNearestPlayer() 교체
- **MONSTER-06**: MonsterManager — Update() 배치 틱으로 교체
