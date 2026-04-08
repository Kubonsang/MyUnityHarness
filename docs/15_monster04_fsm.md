# 15. MONSTER-04: MonsterFSM

## 세션 목표
NavMeshAgent 기반 서버 AI FSM 구현. Idle→Chase→Attack→Dead 상태 전환 + IDamageable 공격 데미지 적용.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/MonsterFSM.cs` | **신규**. NetworkBehaviour + NavMeshAgent |
| `feature_list.json` | MONSTER-04 → `in_progress` |

---

## 상태 머신 구조

```
Idle ──(플레이어 탐지)──→ Chase ──(attackRange 진입)──→ Attack
 ↑                          │                              │
 └──(탐지 범위 벗어남)──────┘ ← ─ ─(공격 완료, 탐지 무)   │
 ↑                                                         │
 └──────────────────────────(공격 완료, 탐지 있음 → Chase)─┘
Any ──(HP <= 0)──→ Dead
```

| 상태 | 행동 |
|------|------|
| Idle | 매 틱 FindNearestPlayer() → 탐지 시 Chase 진입 |
| Chase | NavMeshAgent.SetDestination() 추적 + attackRange 체크 |
| Attack | ResetPath() + ApplyAttackDamage() + attackDuration 타이머 대기 |
| Dead | ResetPath() + Dead 애니메이션. 이후 MonsterHealth.Despawn(false) |

---

## 핵심 설계

### 공격 데미지 적용 시점
Attack 상태 **진입 시 1회** 적용. 히트 판정은 IDamageable.ApplyDamage(_data.damage, 0).
attackerClientId = 0 (서버 소유). PlayerHealth는 이 값을 미사용.

### Update() 임시 포함
```
// MONSTER-06 MonsterManager 구현 시 이 Update()를 제거하고
// OnNetworkSpawn에서 MonsterManager.Register(this) 호출로 교체한다.
private void Update()
{
    if (!IsServer) return;
    Tick(Time.deltaTime);
}
```
MONSTER-06 구현 전까지는 개별 Update()로 동작. 성능 이슈는 MONSTER-06에서 해결.

### FindNearestPlayer() → MONSTER-05 교체 예정
현재: `Physics.OverlapSphere` → `TryGetComponent<PlayerHealth>()` → 거리 기반 최근접 선택
MONSTER-05: `AggroSystem.GetTarget()` → 거리 + 데미지 + decay 기반 우선순위 선택

### NavMesh 가드
```csharp
if (_agent.isOnNavMesh)
    _agent.SetDestination(_target.position);
```
NavMesh 미베이크 상태에서도 경고 없이 동작.

---

## 에디터 설정

```
몬스터 프리팹:
├── NetworkObject
├── NavMeshAgent           ← 자동 RequireComponent
├── Animator               ← MonsterAnimationController 참조용
├── CapsuleCollider        ← PlayerCombat OverlapSphere 탐지용
├── MonsterData            ← [SerializeField] _data 할당
├── MonsterHealth          ← _data 동일 에셋 할당
├── MonsterAnimationController  ← State Mappings 실제 애님명 설정
└── MonsterFSM             ← _data 동일 에셋 할당
```

**씬 설정**: AI Navigation 패키지로 NavMesh 베이크 필요 (Window → AI → Navigation).

---

## 검증 절차

1. 씬에 NavMesh 베이크 확인
2. 몬스터 프리팹에 컴포넌트 모두 추가 + MonsterData 할당
3. Host 시작 → 몬스터 IsSpawned = true 확인
4. 플레이어가 detectionRange 진입 → `[MonsterFSM] Chase` (Debug.Log 없음, Inspector _state 확인)
5. 플레이어가 attackRange 진입 → PlayerHealth HP 감소 확인
6. 플레이어 이동해 detectionRange 벗어남 → 몬스터 Idle 복귀 + NavAgent 정지
7. 몬스터 HP 0 → Dead 애니메이션 → Despawn
8. 완료 → feature_list.json MONSTER-04 → `done`

---

## 주의 사항

| 항목 | 내용 |
|------|------|
| Update() 성능 | 몬스터 수 증가 시 개별 Update() + OverlapSphere 부하. MONSTER-06에서 해결 |
| NavMesh 미베이크 | `_agent.isOnNavMesh = false` → SetDestination 미작동, 몬스터 이동 안 함 |
| AttackRange 즉시 적용 | 공격 진입 시 즉시 데미지. 애니메이션 히트 프레임과 타이밍 불일치 가능 |

---

## 다음 권장 태스크
- **MONSTER-05**: AggroSystem — FindNearestPlayer() 교체 + 데미지 누적 어그로 + decay
- **MONSTER-06**: MonsterManager — Update() 제거 + 배치 틱
