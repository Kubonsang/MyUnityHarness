# 42. STATUS-FIX-01: IsSpawned 가드 + PlayerStatus Awake 캐싱

## 세션 목표
PR#2 리뷰 지적 사항 2건 수정.
- `StatusBehaviour.Update()`: 스폰 전 NetworkList 접근 방지 가드 추가
- `PlayerStatus._health`: lazy 프로퍼티 → Awake 캐싱으로 변경해 Update 핫패스 GetComponent 제거

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Status/StatusBehaviour.cs` | `Update()`에 `if (!IsSpawned) return;` 추가 |
| `Assets/Scripts/Status/PlayerStatus.cs` | lazy `Health` 프로퍼티 제거 → `Awake()` + `_health = GetComponent<PlayerHealth>()` 추가 |

---

## 핵심 설계

### IsSpawned 가드 (StatusBehaviour.cs)
```csharp
private void Update()
{
    if (!IsServer) return;
    if (!IsSpawned) return; // OnNetworkSpawn 이전 NetworkList 접근 방지
    ...
}
```
`MonsterHealth.ApplyDamage()`의 기존 패턴(`if (!IsSpawned) return;`)과 동일하게 맞춤.
스폰 전 `_tickTimer`가 1초를 넘어도 `TickEffects()`가 NetworkList에 접근하지 않음.

### PlayerStatus Awake 캐싱
```csharp
// Before (lazy — Update 핫패스에서 GetComponent 호출 위험)
private PlayerHealth Health => _health != null ? _health : (_health = GetComponent<PlayerHealth>());

// After (MonsterStatus 패턴 동일)
private void Awake()
{
    _health = GetComponent<PlayerHealth>();
}
// OnEffectTick에서 _health 직접 사용
```

lazy에서 Awake로 전환 가능한 이유:
- 테스트 코드(`Status03DebuffTests.cs`)가 이미 `AddComponent<PlayerHealth>()` → `AddComponent<PlayerStatus>()` 순서로 추가 → Awake 시점에 PlayerHealth 존재 보장
- 프리팹 사용 시에도 GO에 두 컴포넌트가 동시에 존재 → 순서 문제 없음
- 기존 lazy 전환은 양방향 Awake 의존성 문제 때문이었으나, PlayerHealth는 `Status`를 lazy로 유지하므로 단방향 안전

---

## 검증

### 컴파일 ✅
`unity-cli editor refresh --compile` → 에러 없음

### 수식 검증 (exec) ✅
- IsSpawned=false 시 shouldTick=false [PASS]
- PlayerStatus Awake 캐싱 후 status/health 모두 non-null [PASS]

STATUS-FIX-01 → `done` ✅

---

## 주의 사항
- `PlayerHealth.Status` lazy 프로퍼티는 그대로 유지. `ApplyDamage`/`ApplyHeal`은 스폰 후에만 호출되므로 핫패스 문제 없음
- `PlayerStatus._health`가 null인 경우(PlayerHealth 없는 GO에 PlayerStatus만 붙인 경우) `OnEffectTick`에서 early return으로 안전 처리

---

## 다음 권장 태스크
- **STATUS-FIX-02**: ActiveEffect CasterClientId 추가 → DoT 어그로 귀속
