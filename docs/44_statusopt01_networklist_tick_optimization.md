# 44. STATUS-OPT-01: NetworkList 틱 쓰기 최적화

## 세션 목표
PR#2 리뷰 지적: `TickEffects()`에서 매 초 `_activeEffects[i] = effect`로 전체 `ActiveEffect` 구조체를 NetworkList에 쓰는 문제 수정.
`RemainingDuration` 추적을 서버 전용 `_serverDurations`로 분리해 NetworkList 쓰기를 이벤트 발생 시에만 발생하도록 최적화.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Status/StatusBehaviour.cs` | `List<float> _serverDurations` 추가. `TickEffects` 에서 NetworkList 쓰기 제거. `ApplyEffect`/`RemoveEffect` 에서 `_serverDurations` 병렬 관리 |

---

## 핵심 설계

### 변경 전 쓰기 빈도
```
TickEffects() 매 초 실행:
  for i in activeEffects:
    effect.RemainingDuration -= 1f
    _activeEffects[i] = effect  ← NGO NetworkList 쓰기 N회/초
```

### 변경 후 쓰기 빈도
```
TickEffects() 매 초 실행:
  for i in activeEffects:
    _serverDurations[i] -= 1f   ← 서버 로컬, 네트워크 전송 없음
    if 만료: _activeEffects.RemoveAt(i)  ← NetworkList 1회 쓰기 (불가피)

ApplyEffect() 신규:
  _activeEffects.Add(...)        ← NetworkList 1회 쓰기 (불가피)
  _serverDurations.Add(duration)

ApplyEffect() 리프레시:
  _serverDurations[i] = duration ← 서버 로컬만 갱신
  if 스택 변경: _activeEffects[i] = existing  ← NetworkList 쓰기 (스택 변경 시에만)
  else: NetworkList 쓰기 없음 (단일 스택 효과 Wound/Stun/Burn 등)
```

### 최적화 효과
| 시나리오 | 이전 | 이후 |
|----------|------|------|
| 효과 N개 활성 중 (틱) | N회/초 NetworkList 쓰기 | 0회/초 |
| 단일 스택 효과 재적용 | 1회 NetworkList 쓰기 | 0회 |
| 다중 스택 효과 스택 증가 | 1회 NetworkList 쓰기 | 1회 (변화 없음) |
| 효과 만료 | 1회 RemoveAt | 1회 RemoveAt (변화 없음) |

### Late-join 동기화 유지
`NetworkList<ActiveEffect>` 는 그대로 유지되므로 늦게 접속한 클라이언트에게 전체 목록이 동기화됨.
`RemainingDuration`은 "최초 적용 시 전체 지속시간" 또는 "마지막 스택 변경 시 기준값"을 반영.
정확한 카운트다운이 필요한 클라이언트 UI는 `ActiveEffect.RemainingDuration` 기준으로 로컬 추정 가능.

### 불변식: `_activeEffects.Count == _serverDurations.Count` 항상 유지
- `Add`: 양쪽 동시 추가
- `RemoveAt(i)`: 양쪽 동시 제거 (역순 루프 보장)
- `RemoveEffect`: 양쪽 동시 제거

---

## 검증

### 컴파일 ✅
`unity-cli editor refresh --compile` → 에러 없음

### 불변식 논리 검증 (exec) ✅
- Add 동기: `durations.Count == effectCount` [PASS]
- Tick 후 개수 유지: 쓰기 없이 카운트 동일 [PASS]
- Remove 동기: 양쪽 동시 제거 후 count=0 [PASS]
- Wound 재적용 NetworkList 쓰기: 0회 (스택 변화 없을 때) [PASS]

STATUS-OPT-01 → `done` ✅

---

## 주의 사항
- **클라이언트 UI 카운트다운 정밀도 저하**: 클라이언트가 보는 `RemainingDuration`은 최초 적용 시 값. 정확한 잔여 시간은 클라이언트가 로컬에서 추정해야 함 (UI 구현 시 고려).
- **`_serverDurations` 인덱스 무결성**: `_activeEffects`와 인덱스가 항상 동일해야 함. 이 불변식이 깨지면 잘못된 효과가 만료됨 → Add/RemoveAt은 반드시 두 리스트에 동시 적용.
- **다중 스택 재적용 스택 변화 없을 때**: Poison이 이미 max stacks에 도달한 상태에서 재적용하면 스택 변화 없음 → NetworkList 쓰기 없음 (서버 타이머만 갱신). 정상 동작.

---

## 다음 권장 태스크
- **SKILL-01**: 스킬 시스템 ConditionType/EffectType Enum 및 SO 뼈대
