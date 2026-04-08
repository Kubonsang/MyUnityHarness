# 57. SKILL-03: Condition 판정과 Effect 적용 연결

## 세션 목표
`SkillConditionMonitor`가 단순 이벤트 로그 단계에서 벗어나, 조건 충족 시 실제 `IStatusEffectable` / `IDamageable` 경로로 효과를 적용하도록 연결한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Skill/SkillConditionMonitor.cs` | 조건별 상태 추적, 쿨다운, `Damage` / 상태 효과 적용, 상태 데이터 매핑 추가 |
| `feature_list.json` | `SKILL-03` 상태를 `done`으로 갱신 |
| `docs/57_skill03_condition_effect_apply.md` | **신규** — 구현 및 검증 기록 |

---

## 핵심 설계

### 최소 변경 범위 유지
- 실제 수정은 `SkillConditionMonitor` 한 파일에 집중했다.
- `PlayerCombat`, `PlayerHealth`, `PlayerInventory`, `StatusBehaviour`의 기존 구조는 유지하고, `SKILL-02`에서 이미 연결된 이벤트 훅을 그대로 재사용했다.

### 서버 전용 조건 상태 추적
- `_activeEntries`를 단순 `SkillEntry` 리스트가 아니라 등록 단위 식별자(`RegistrationId`)를 가진 런타임 엔트리로 승격했다.
- `HitN`용 `_hitCounters`, 엔트리 쿨다운용 `_cooldownEndTimes`, `Time`용 `_timeAccumulators`를 추가해 서버에서만 조건 진행 상태를 추적한다.
- `RemoveEntries()` 시 해당 엔트리의 카운터/쿨다운/타이머를 함께 정리해, 아이템 제거 후 상태가 남지 않게 했다.

### Effect 적용 경로
- `EffectType.Damage`는 대상 `IDamageable.ApplyDamage()`로 직접 연결했다.
- 상태 계열 효과는 `EffectType`을 `StatusEffectType`으로 매핑한 뒤, 대상 `IStatusEffectable.ApplyEffect()`로 적용한다.
- `StatusEffectData.duration`을 스킬별로 덮어쓸 수 있도록, 기본 카탈로그를 복제하지 않고 `(type, duration)` 키 기반 런타임 override 캐시를 두었다.
- `StatusTargetType`에 따라 자기 자신(`Self`/`Ally`) 또는 이벤트 대상(`Enemy`/`Any`)을 선택한다.

### 현재 지원 범위
- 이번 세션에서 실제 판정/적용을 연결한 조건:
  - `HitAny`
  - `HitN`
  - `Damaged`
  - `Time`
  - `HpLow`
- `Kill`은 상위 kill 이벤트가 아직 실제 코드에 없고,
  `Dodge`는 ROLE-05 무적 프레임 판정 의존성이 남아 있어 이번 태스크에서는 미연결로 뒀다.
- `Projectile` 효과는 예정대로 `SKILL-04`에서 처리한다.

---

## 검증 절차

1. 컴파일 검증
   - `unity-cli editor refresh --compile`
   - `unity-cli console --filter error --stacktrace short`
   - 결과: `[]`
2. 런타임 검증
   - `unity-cli console --clear`
   - `unity-cli editor play --wait`
   - `unity-cli exec ...` 로 임시 Host / Player / Monster 환경 구성
   - 런타임에서 커스텀 `StatusEffectData` 2개 생성
     - `Stun` (`Enemy`, 2초)
     - `Fortify` (`Self`, 3초)
   - `SkillConditionMonitor`에 아래 엔트리를 등록
     - `HitN(2)` -> `Stun`
     - `Damaged` -> `Fortify`
   - 내부 조건 처리 호출 후 확인 결과
     - `stunAfterFirst:False`
     - `stunAfterSecond:True`
     - `fortifyAfterDamaged:True`
     - `targetHp:100`
     - `playerHp:93`
   - `unity-cli editor stop`
   - 종료 후 `unity-cli console --filter error --stacktrace short`
   - 결과: `[]`

### 결과 해석
- 첫 번째 적중에서는 `HitN(2)`가 아직 충족되지 않아 대상 `Stun`이 걸리지 않았다.
- 두 번째 적중 후에는 대상 `MonsterStatus`에 `Stun`이 실제 등록되었다.
- 피격 시에는 플레이어 자신의 `PlayerStatus`에 `Fortify`가 실제 등록되었다.
- 즉, 조건 판정 결과가 로그에 그치지 않고 `IStatusEffectable` 경로로 실제 상태 변화까지 이어짐을 확인했다.

---

## 주의 사항
- 이번 검증은 `SKILL-02`에서 이미 확인한 이벤트 훅 위에, `SKILL-03`의 핵심인 “조건 -> 실제 효과 적용” 부분을 분리해서 확인한 것이다.
- `HitN` 검증은 물리 오버랩의 중복 영향을 피하기 위해 monitor 내부 핸들러를 직접 호출하는 synthetic Play Mode 하네스를 사용했다.
- `Kill`, `Dodge`, `Projectile`은 아직 미구현/후속 범위다.
- `HpLow`는 현재 조건 충족 동안 계속 재평가되는 구조이므로, 데이터 설계상 지속 갱신이 의도인지 후속 밸런싱 때 다시 확인하는 편이 안전하다.

---

## 다음 권장 태스크
- **SKILL-04**: `SkillProjectile`을 이용한 조건-효과 지연(Payload Chaining) 연쇄 로직
