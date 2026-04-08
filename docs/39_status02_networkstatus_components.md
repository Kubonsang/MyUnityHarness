# 42. STATUS-02: 플레이어/몬스터 Status 컴포넌트 및 NetworkList 연동

## 세션 목표
`PlayerStatus` / `MonsterStatus` NetworkBehaviour 컴포넌트를 생성하고, `NetworkList<ActiveEffect>`를 통해 서버 권위 상태 효과를 모든 클라이언트에 동기화한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Status/ActiveEffect.cs` | **신규** — `INetworkSerializable` + `IEquatable<ActiveEffect>` 구조체 |
| `Assets/Scripts/Status/StatusBehaviour.cs` | **신규** — 공통 로직 추상 기반 (NetworkList 관리, 틱, IStatusEffectable 구현) |
| `Assets/Scripts/Status/PlayerStatus.cs` | **신규** — StatusBehaviour 상속 (LogTag = "PlayerStatus") |
| `Assets/Scripts/Status/MonsterStatus.cs` | **신규** — StatusBehaviour 상속 (LogTag = "MonsterStatus") |

---

## 핵심 설계

### ActiveEffect 구조체
```
EffectTypeId (byte) | RemainingDuration (float) | Stacks (byte)  →  7 bytes/슬롯
```
`StatusEffectType`을 byte로 저장해 대역폭 절약. `IEquatable` 구현은 NGO `NetworkList<T>` 요구사항.

### StatusBehaviour 기반 클래스
PlayerStatus / MonsterStatus의 ~100줄 동일 로직을 하나로 통합.
CLAUDE.md "Only extract shared systems when duplication is repeated and stable" 기준 충족.

### 서버 틱 구조
```
Update() → _tickTimer 누적
  → TickInterval(1초) 도달 시 TickEffects() 실행
    → RemainingDuration -= 1f
    → 만료 시 RemoveAt → 자동 NetworkList 동기화
```
매프레임 NetworkList 쓰기 없음 — 초 단위 1회만 변경 발생.

### IStatusEffectable 구현
| 메서드 | 서버 전용 | 동작 |
|--------|-----------|------|
| `ApplyEffect` | ✅ | 이미 있으면 duration 갱신 + 스택 증가, 없으면 Add |
| `RemoveEffect` | ✅ | 첫 번째 일치 슬롯 RemoveAt |
| `HasEffect` | ❌ | foreach 조회 |
| `GetStacks` | ❌ | foreach 조회, 없으면 0 |

---

## 검증 절차

unity-cli `Assets/Refresh` 후 console 확인:
- `error CS` 없음 ✅
- 기존 CS0618 warning(LobbyRoleSelector)만 존재

에디터 런타임 검증 (STATUS-03 이후 가능):
1. PlayerStatus가 붙은 플레이어 스폰
2. `ApplyEffect(data, 1)` 서버 호출 → Console: `효과 적용` 로그
3. 1초 후 → `RemainingDuration` 감소 확인 (Inspector NetworkList)
4. 만료 시 → `효과 만료` 로그 + 슬롯 제거 확인

---

## 주의 사항
- `StatusBehaviour.Update()` — `if (!IsServer) return` 가드로 클라이언트 틱 비용 없음.
- `NetworkList<ActiveEffect>` 인덱스 기반 업데이트: `_activeEffects[i] = effect` 로 해야 NGO가 변경 이벤트를 발행함 (참조 수정 불가).

---

## 다음 권장 태스크
- **STATUS-03**: 디버프 3종(Wound, Stun, Poison) 효과 로직
- **STATUS-04**: 버프 5종(Invincible, Stealth, Valor, Haste, Fortify) 효과 로직
