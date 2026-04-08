# 14. MONSTER-03: MonsterAnimationController

## 세션 목표
`NetworkVariable<byte>`로 몬스터 애니메이션 상태(Idle/Chase/Attack/Dead)를 멀티플레이어 동기화.
PlayerAnimationController 패턴을 그대로 적용, 몬스터 전용 요소만 변경.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/MonsterAnimationController.cs` | **신규**. NetworkBehaviour + NetworkVariable&lt;byte&gt; |
| `feature_list.json` | MONSTER-03 → `in_progress` |

---

## PlayerAnimationController와의 차이점

| 항목 | PlayerAnimationController | MonsterAnimationController |
|------|--------------------------|---------------------------|
| 상태 enum | `PlayerAnimState` (Idle/Walk/Run/Attack) | `MonsterAnimState` (Idle/Chase/Attack/Dead) |
| 무기 오버라이드 | `_attackAnimOverride` NetworkVariable 있음 | 없음 (몬스터 무기 교체 미지원) |
| 호출자 | PlayerFSM | MonsterFSM (MONSTER-04) |

---

## 에디터 설정

```
몬스터 프리팹:
├── NetworkObject
├── MonsterHealth         (_data 할당)
├── MonsterAnimationController
│     _crossFadeTime: 0.15
│     State Mappings:
│       [0] Idle   → "Idle"    ← Animator Controller의 실제 상태명으로 변경
│       [1] Chase  → "Walk"    ← 실제 상태명으로 변경
│       [2] Attack → "Attack"  ← 실제 상태명으로 변경
│       [3] Dead   → "Die"     ← 실제 상태명으로 변경
└── Animator              (Controller에 Idle/Walk/Attack/Die 상태 포함)
```

> **주의**: `animStateName`은 Animator Controller 내 State 이름과 **정확히 일치**해야 함.
> RPGMonsterBundlePBR 애니메이터의 실제 상태명을 확인 후 Inspector에서 수정 필요.

---

## 검증 절차

1. 컴파일 확인 (오류 없음)
2. 몬스터 프리팹에 `MonsterAnimationController` 추가 + State Mappings 확인
3. Host 시작 → 몬스터 스폰 → Inspector에서 `_animState.Value = 0 (Idle)` 확인
4. (MonsterFSM 구현 전 임시 테스트) Inspector에서 `_animState` 값 수동 변경 → Animator 상태 전환 확인
5. 클라이언트 늦게 접속 → Idle 상태 즉시 수신 확인 (OnNetworkSpawn에서 ApplyAnimState 호출)
6. 완료 → feature_list.json MONSTER-03 → `done`

---

## 다음 권장 태스크
- **MONSTER-04**: MonsterFSM — NavMeshAgent AI + SetState() 호출로 MonsterAnimationController 구동
