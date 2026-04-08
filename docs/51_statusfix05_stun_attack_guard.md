# 51. STATUS-FIX-05: Stun 중 공격 차단 및 누적 입력 폐기

## 세션 목표
`PlayerController`의 공격 입력 경로에 `Stun` 가드를 추가하고,
기절 중 누적된 jump 입력이 해제 후 오발동하지 않도록 서버 정책을 명확히 반영한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerController.cs` | `Stun` 상태일 때 host 공격/점프 입력과 서버 RPC 공격/점프 입력을 차단하고, 기절 중 `_serverJump` 래치 입력을 폐기하도록 수정 |
| `feature_list.json` | `STATUS-FIX-05` 상태를 `done`으로 갱신 |
| `docs/51_statusfix05_stun_attack_guard.md` | **신규** — 구현 내용과 검증 결과 기록 |

---

## 핵심 설계

### 서버 권위 Stun 차단 위치
- `SetAttackPressed()`의 host 경로에서 `IsStunned()`를 먼저 확인하도록 변경했다.
- `SendAttackServerRpc()` 본문에도 동일한 `IsStunned()` 검증을 넣어, 원격 클라이언트 요청이 서버에 도달해도 실제 공격이 실행되지 않게 했다.
- 같은 이유로 `SetJumpPressed()`와 `SendJumpServerRpc()`에도 동일한 서버 측 차단을 넣었다.

### 누적 입력 폐기 정책
- `_serverJump`는 래치 입력이어서, 기절이 걸린 뒤에도 값이 남아 있으면 해제 직후 점프가 오발동할 수 있다.
- 이를 막기 위해 `ApplyMovement()`가 `Stun`으로 조기 반환할 때 `_serverJump = false`를 매 프레임 수행하도록 했다.
- 결과적으로 정책은 다음과 같다.
  - `Stun` 중 새 공격 입력: 즉시 폐기
  - `Stun` 중 새 점프 입력: 즉시 폐기
  - `Stun` 시점에 이미 큐에 남아 있던 jump 래치: 다음 서버 이동 틱에서 폐기

### 최소 변경 유지
- 수정 범위는 `PlayerController` 내부로 제한했다.
- `PlayerCombat`, `PlayerFSM`, `PlayerStatus` 구조는 건드리지 않았다.
- 이동 재개, 기존 이동 입력 유지, 애니메이션 정책은 이번 태스크 범위 밖으로 두었다.

---

## 검증 절차

### 컴파일 검증
1. `unity-cli editor refresh --compile`
2. `unity-cli console --filter error`
3. 결과: 컴파일 완료, `error` 콘솔 비어 있음

### 런타임 검증
1. `unity-cli editor play --wait`
2. `unity-cli exec ...` 로 임시 `NetworkManager`, `PlayerController`, `MonsterHealth` 오브젝트를 생성해 Play Mode에서 직접 검증
3. 확인 항목
   - 비기절 상태 기준 공격이 실제로 1회 적용되는지
   - `Stun` 중 `SetAttackPressed()`가 공격을 막는지
   - `Stun` 중 `SendAttackServerRpc()` 본문이 공격을 막는지
   - `Stun` 중 `SetJumpPressed()`가 `_serverJump`를 세우지 않는지
   - 기절 중 남아 있던 `_serverJump`가 `ApplyMovement()`에서 폐기되고, 해제 후에도 다시 살아나지 않는지
4. 실행 결과
   - `baseline:100->90`
   - `hostBlocked:100->100`
   - `rpcBlocked:100->100`
   - `jumpAfterInput:False`
   - `jumpAfterStunTick:False`
   - `jumpAfterRecoverTick:False`
5. `unity-cli editor stop`

---

## 주의 사항
- 이번 런타임 검증은 Play Mode에서 host 경로와 서버 RPC 본문 실행을 직접 확인한 것이다.
- 실제 원격 클라이언트 transport를 붙인 2클라이언트 검증은 이번 세션에서 수행하지 않았다.
- `Stun` 중 기존 이동 경로를 멈추는 몬스터 문제는 별도 태스크 `STATUS-FIX-06` 범위다.

---

## 다음 권장 태스크
- **STATUS-FIX-06**: 몬스터 `Stun` 시 `NavMeshAgent` 기존 경로 즉시 중단
