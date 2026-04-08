# STATUS-03 PlayMode 테스트 SetUp NullReferenceException

## 증상

PlayMode 테스트 4개 전부 SetUp에서 NullReferenceException.

## Root Cause

총 3개 원인이 겹쳐 발생:

1. **NGO 2.x `NetworkConfig` 미초기화**: `AddComponent<NetworkManager>()` 런타임 추가 시 `NetworkConfig`가 자동 초기화되지 않음. `= new NetworkConfig()` 명시 필요.

2. **NGO 싱글턴 충돌**: 이전 테스트 또는 씬에 남은 NM이 있으면 새 NM의 `Awake()`에서 `Destroy(gameObject)` — `[UnitySetUp]` + 기존 싱글턴 제거 + `yield return null` 로 해결.

3. **AddComponent 순서로 인한 cross-reference null**: `PlayerStatus.Awake()` → `GetComponent<PlayerHealth>()` null (반대로도 동일). Awake 캐싱 제거 → lazy 프로퍼티(`Health`, `Status`)로 변경해 해결.

## 수정 내용

| 파일 | 변경 |
|------|------|
| `Status03DebuffTests.cs` | `[SetUp]` → `[UnitySetUp]` 코루틴, 기존 NM 제거 + yield, `NetworkConfig = new NetworkConfig()`, PlayerHealth 먼저 AddComponent |
| `PlayerHealth.cs` | `Awake()` 제거, `_status` → lazy `Status` 프로퍼티 |
| `PlayerStatus.cs` | `Awake()` 제거, `_health` → lazy `Health` 프로퍼티 |

## 검증 결과

**4/4 PASS** — PlayMode 테스트 전부 통과. STATUS-03 → `done`.

---

## 추가 버그: ActiveEffect.Equals — 효과 만료 불가

### 증상
Host 모드에서 `TestApplyEffect`로 효과를 적용하면 만료되지 않고 영구 지속.

### Root Cause
`ActiveEffect.Equals`가 `EffectTypeId`만 비교. NGO `NetworkList<T>`의 `[i] = value` 쓰기 시 `IEquatable.Equals`로 변경 여부를 검사하는데, `RemainingDuration`이 달라도 동일 타입이면 "동일"로 판단해 업데이트 스킵. 결과적으로 `TickEffects`가 `RemainingDuration`을 감소시켜도 리스트에 반영되지 않아 효과가 만료 불가.

### 수정 내용
`ActiveEffect.Equals`를 모든 필드(EffectTypeId, RemainingDuration, Stacks) 비교로 변경.

### 검증
PlayMode 4/4 PASS 유지.
