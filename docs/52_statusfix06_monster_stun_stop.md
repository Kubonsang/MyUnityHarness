# 52. STATUS-FIX-06: Monster Stun 이동 완전 정지

## 세션 목표
`MonsterFSM`에서 `Stun` 적용 시 기존 `NavMeshAgent` 경로를 즉시 끊고,
기절 중에는 완전히 정지한 상태를 유지하며, 해제 후에는 상태 머신이 다시 재평가되도록 만든다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/MonsterFSM.cs` | `Stun` 전용 이동 잠금 상태 추가, 경로 초기화 + `isStopped` 잠금/해제 처리 반영 |
| `feature_list.json` | `STATUS-FIX-06` 상태를 `done`으로 갱신 |
| `docs/52_statusfix06_monster_stun_stop.md` | **신규** — 구현/검증 결과 기록 |

---

## 핵심 설계

### Stun 중 정지 정책
- 기존 구현은 `Stun`일 때 `Tick()`에서 즉시 `return`만 해서, 이미 잡혀 있던 `NavMeshAgent` 경로가 남을 수 있었다.
- 이번 수정에서는 `Tick()` 초반에 `IsStunned()`를 확인하고, `ApplyStunMovementLock()`을 먼저 호출한 뒤 AI 틱을 스킵한다.
- `ApplyStunMovementLock()`은 다음을 수행한다.
  - 현재 경로가 있으면 `ResetPath()`로 즉시 제거
  - 그 다음 `isStopped = true`로 잠금

### 기절 해제 후 재개 정책
- `_stunMovementLocked` 플래그로 “현재 stun 때문에 이동이 잠겼는지”만 추적한다.
- 기절이 해제된 첫 틱에서 `ReleaseStunMovementLockIfNeeded()`가 `isStopped = false`를 1회 실행한다.
- 이후 같은 틱 안에서 기존 FSM switch가 그대로 실행되므로, 기존 상태(`Chase`, `Attack`, `Hit`) 기준으로 자연스럽게 다음 상태를 재평가한다.

### 풀 재사용 안정성
- 몬스터는 풀링되어 재사용될 수 있으므로 `OnNetworkSpawn()` / `OnNetworkDespawn()`에서
  `isStopped`와 `_stunMovementLocked`를 초기화했다.
- 이를 통해 기절 상태에서 despawn된 개체가 다음 spawn 때 정지 상태를 끌고 오지 않도록 했다.

---

## 검증 절차

### 컴파일 검증
1. `unity-cli editor refresh --compile`
2. `unity-cli console --filter error`
3. 결과: 컴파일 완료, `error` 콘솔 비어 있음

### 런타임 검증
1. 콘솔 초기화 후 `unity-cli editor play --wait`
2. `unity-cli exec ...` 로 임시 plane + `NavMeshSurface(CollectObjects.Children)` + `MonsterFSM` + `NavMeshAgent` 환경 구성
3. `NavMesh.CalculatePath` + `agent.SetPath(...)`로 chase 중 기존 경로가 존재하는 상태를 강제로 만든 뒤 `Stun` 적용
4. 확인 항목
   - `Stun` 직전: `path=True`, `stopped=False`
   - `Stun` 적용 틱: `path=False`, `stopped=True`
   - `Stun` 해제 후 첫 틱: `stopped=False`이며 FSM 상태 전이가 다시 진행되는지
5. 실행 결과
   - `warped:True`
   - `calc:True`
   - `setPath:True`
   - `before:path=True|stopped=False`
   - `hasStun:True`
   - `stun:Chase|path=False|stopped=True`
   - `recover:Attack|stopped=False`
6. `unity-cli editor stop`
7. 종료 후 `unity-cli console --filter error` 결과 빈 배열 확인

### 결과 해석
- `Stun` 직후 기존 경로가 비워지고 `isStopped`가 유지되어 “기존 이동이 즉시 중단됨”을 확인했다.
- 해제 후 `stopped=False`와 상태 전이(`recover:Attack`)가 관찰되어, stun 잠금이 풀린 뒤 FSM이 다시 흐름을 이어감도 확인했다.

---

## 주의 사항
- 런타임 검증은 synthetic Play Mode 환경에서 reflection과 임시 NavMesh를 사용해 수행했다.
- 해제 후 예시 결과가 `Attack`으로 나온 것은 테스트 구성상 FSM이 stun 해제 직후 다음 상태를 다시 계산한 결과이며,
  핵심 확인 포인트는 “stun 잠금이 풀리고 FSM이 정지 상태에 갇히지 않는다”는 점이다.
- `플레이어 Stun 공격 차단` 회귀 검증은 이미 `STATUS-FIX-05`에서 별도로 확인했다.

---

## 다음 권장 태스크
- **TEST-STATUS-01**: 플레이어/몬스터 `Stun` 회귀 방지 PlayMode 검증 추가
