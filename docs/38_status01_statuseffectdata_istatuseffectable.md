# 41. STATUS-01: StatusEffectData SO 및 IStatusEffectable 인터페이스 생성

## 세션 목표
STATUS 카테고리의 기반 타입 3개(`StatusEffectType`, `StatusEffectData`, `IStatusEffectable`)를 생성하여 이후 PlayerStatus / MonsterStatus 구현의 토대를 마련한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Status/StatusEffectType.cs` | **신규** — 상태 효과 열거형 (byte 기반, 디버프 6종 + 버프 5종) |
| `Assets/Scripts/Status/StatusEffectData.cs` | **신규** — 고정 속성 ScriptableObject (effectType, duration, maxStacks, effectName) |
| `Assets/Scripts/Status/IStatusEffectable.cs` | **신규** — 버프/디버프 대상 공통 인터페이스 (ApplyEffect, RemoveEffect, HasEffect, GetStacks) |

---

## 핵심 설계

### StatusEffectType (byte enum)
`ActiveEffect.EffectTypeId` 필드가 `byte` 타입이므로 enum도 `byte` 기반으로 선언.
디버프(0~5) / 버프(10~14) 로 값 범위를 구분해 향후 IsDebuff 판별을 단순화할 수 있음.

### StatusEffectData (ScriptableObject)
런타임 인스턴스 상태(남은 시간, 현재 스택)는 `ActiveEffect` 구조체가 담당.
이 SO는 **불변 고정 데이터만** 가짐 — 서버/클라 공통 참조.

### IStatusEffectable
- `ApplyEffect` / `RemoveEffect`: 서버 전용 (상태 변경은 서버 권위)
- `HasEffect` / `GetStacks`: 서버/클라 모두 호출 가능 (조회 전용)
- PlayerStatus, MonsterStatus가 이 인터페이스를 구현 (STATUS-02에서)

---

## 검증 절차

unity-cli `Assets/Refresh` 후 console 확인:
- `error CS` 없음 ✓
- 기존 `CS0618` warning(LobbyRoleSelector — RequireOwnership deprecated)은 STATUS-01 이전부터 존재하는 무관한 경고

---

## 다음 권장 태스크
- **STATUS-02**: 플레이어/몬스터 Status 컴포넌트 추가 및 `NetworkList<ActiveEffect>` 연동
