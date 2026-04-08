# 18. MONSTER-06: MonsterManager

## 세션 목표
서버 전용 중앙 틱 관리자. MonsterFSM 개별 Update() 제거 → Round-robin 배치 틱으로 교체.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/MonsterManager.cs` | **신규**. NetworkBehaviour 기반 중앙 틱 관리자. `[System.NonSerialized]` 추가 |
| `Assets/Scripts/Monster/MonsterFSM.cs` | Update() 제거, OnNetworkSpawn/Despawn에 Register/Unregister 추가 |
| `feature_list.json` | MONSTER-06 → `in_progress` |
| `docs/errorlogs/19_monster06_activeMonsters_disposed.md` | **신규**. ObjectDisposedException 원인 및 수정 기록 |

---

## 핵심 설계

### Round-robin 틱 분산

```
_activeMonsters = [A, B, C, D, E, F, G, H, I, J]  (10마리)
_ticksPerFrame  = 5

Frame 1: Tick(A, B, C, D, E)  _tickIndex → 5
Frame 2: Tick(F, G, H, I, J)  _tickIndex → 0
Frame 3: Tick(A, B, C, D, E)  ...
```

각 몬스터는 `ceil(count / _ticksPerFrame)` 프레임마다 1회 틱.

### MonsterFSM 등록 흐름

```
MonsterFSM.OnNetworkSpawn() (IsServer)
    → EnterState(Idle)
    → MonsterManager.Instance?.Register(this)   ← 추가

MonsterFSM.OnNetworkDespawn() (IsServer)
    → MonsterManager.Instance?.Unregister(this) ← 추가
```

`MonsterManager.Instance`가 null이면 no-op — MonsterManager 없이 씬을 실행해도 크래시 없음.

### Unregister 후 _tickIndex 보정

```csharp
// 제거된 항목이 _tickIndex 앞이면 인덱스를 당겨 Round-robin 연속성 유지
if (idx < _tickIndex)
    _tickIndex--;
_tickIndex = _activeMonsters.Count > 0 ? _tickIndex % _activeMonsters.Count : 0;
```

---

## deltaTime 보상 (타이머 부정확 해결)

배치 틱 특성상 각 몬스터가 N프레임마다 1회 Tick()을 받는다.
단순히 `Time.deltaTime`을 전달하면 attackDuration 등 타이머가 N배 느리게 동작한다.

**해결**: `compensatedDelta = deltaTime × max(1, count / ticksPerFrame)` 사용.

| 조건 | 보상 계수 | attackDuration 정확도 |
|------|-----------|-----------------------|
| 5마리 / ticksPerFrame=5 | ×1.0 | 정확 (매 프레임 틱) |
| 10마리 / ticksPerFrame=5 | ×2.0 | 정확 |
| 20마리 / ticksPerFrame=5 | ×4.0 | 정확 |

---

## 에디터 설정

```
씬 Hierarchy:
└── MonsterManager (GameObject)
    ├── NetworkObject (컴포넌트) ← 필수
    └── MonsterManager (컴포넌트)
          _ticksPerFrame: 5
```

MonsterManager NetworkObject는 씬 시작 시 자동 스폰(in-scene placed).
MonsterFSM은 스폰 시 자동으로 MonsterManager.Instance에 등록된다.

---

## 검증 절차

1. MonsterManager GameObject 생성 + NetworkObject + MonsterManager 컴포넌트 추가
2. Host 시작 → MonsterSpawner 동작 → 몬스터 스폰 확인
3. 몬스터가 정상 AI 동작(Chase, Attack) 하는지 확인 (Update() 없이도 동작)
   - `_activeMonsters`는 `[System.NonSerialized]`로 Inspector 미노출 (정상). Debug.Log로 카운트 확인 가능
4. 몬스터 사망 → ObjectDisposedException 미발생 확인
5. 완료 → feature_list.json MONSTER-06 → `done`

---

## 에디터 오류 기록

| 오류 | 원인 | 수정 | 링크 |
|------|------|------|------|
| ObjectDisposedException: `_activeMonsters.Array.data[1]` | `List<MonsterFSM>`을 Unity가 직렬화 가능 타입으로 인식 → Inspector ListView 바인딩 → 런타임 RemoveAt() 시 무효화 | `[System.NonSerialized]` 추가 | [errorlog](errorlogs/19_monster06_activeMonsters_disposed.md) |

---

## 다음 권장 태스크
- **MONSTER-05**: AggroSystem — FindNearestPlayer() → AggroSystem.GetTarget() 교체
