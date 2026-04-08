# 45. STATUS-FIX-03: OnNetworkDespawn _serverDurations.Clear() + IsSpawned 가드

## 세션 목표
PR#2 리뷰 지적 2건:
- `_serverDurations`가 Despawn 시 자동 초기화되지 않아 풀링 몬스터 재스폰 시 `_activeEffects`와 인덱스 불일치 → `IndexOutOfRange` 위험
- `ApplyEffect`/`RemoveEffect`에 `IsSpawned` 가드 없어 스폰 전 NetworkList 접근 가능

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Status/StatusBehaviour.cs` | `OnNetworkDespawn` 오버라이드 추가 — `_serverDurations.Clear()` + `_tickTimer = 0f`. `ApplyEffect`/`RemoveEffect`에 `if (!IsSpawned) return;` 추가 |

---

## 핵심 설계

### OnNetworkDespawn 추가
```csharp
public override void OnNetworkDespawn()
{
    // 오브젝트 풀 재사용(Despawn → Respawn) 시 인덱스 불일치 방지.
    // NGO는 NetworkList(_activeEffects)를 자동 초기화하지만 _serverDurations는 직접 정리해야 함.
    _serverDurations.Clear();
    _tickTimer = 0f;
}
```

### 불일치 시나리오 (수정 전)
```
Spawn → Poison 적용 → _activeEffects[0], _serverDurations[0]
Despawn → NGO: _activeEffects 초기화(count=0), _serverDurations 잔류(count=1)
Respawn → Burn 적용 → _activeEffects[0], _serverDurations[1] (인덱스 불일치!)
TickEffects → _serverDurations[0] = 잔류 값 → 잘못된 duration 감소, IndexOutOfRange 가능
```

### IsSpawned 가드 추가 위치
```
ApplyEffect(): IsServer → IsSpawned → ...
RemoveEffect(): IsServer → IsSpawned → ...
```
`Update()`의 기존 패턴과 일관성 확보.

---

## 검증

### 컴파일 ✅
`unity-cli editor refresh --compile` → 에러 없음

### 불변식 논리 검증 (exec) ✅
- Despawn 전 동기: `serverDurations.Count == activeCount` [PASS]
- Despawn 후 Clear 동기: Clear 후 0 == 0 [PASS]
- Respawn 후 정상 동기: Add 후 1 == 1 [PASS]

STATUS-FIX-03 → `done` ✅

---

## 주의 사항
- `_tickTimer = 0f` 초기화도 함께 처리 — 재스폰 직후 잔류 타이머로 즉시 틱이 실행되는 것 방지
- `_activeEffects`(NetworkList) 초기화는 NGO가 담당 — 별도 처리 불필요

---

## 다음 권장 태스크
- **STATUS-FIX-04**: Stealth 해제 순서 설계 의도 명확화
