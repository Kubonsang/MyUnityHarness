# 58. SKILL-04: SkillProjectile payload chaining

## 세션 목표
`EffectType.Projectile`이 즉시 효과를 적용하는 대신 서버에서 `SkillProjectile`을 생성하고, 명중 시 payload 효과를 대상에게 전달하는 연쇄 로직을 완성한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Skill/SkillConditionMonitor.cs` | `Projectile` 효과 감지, payload 분리, `SkillProjectile` 스폰 및 명중 후 payload 적용 경로 추가 |
| `Assets/Scripts/Skill/SkillProjectile.cs` | **신규** — 서버 전용 투사체 이동/명중/자기 소멸 로직 구현 |
| `Assets/Resources/SkillProjectile.prefab` | **신규** — `NetworkObject`, `NetworkTransform`, `Rigidbody`, `SphereCollider`, `SkillProjectile`를 가진 런타임 프리팹 추가 |
| `Assets/NGO_Minimal_Setup/NetworkPrefabsList.asset` | `SkillProjectile` prefab 등록 |
| `Assets/DefaultNetworkPrefabs.asset` | `SkillProjectile` prefab 등록 |
| `Assets/Resources/ScriptableObjects/Status/posion.asset` | `targetType`을 `Self`에서 `Enemy`로 수정해 독 디버프가 명중 대상에게 적용되도록 보정 |
| `feature_list.json` | `SKILL-04` 상태를 `done`으로 갱신 |
| `docs/58_skill04_projectile_payload_chain.md` | **신규** — 구현 및 검증 기록 |

---

## 핵심 설계

### `Projectile`는 즉발이 아니라 payload carrier로 처리
- `SkillConditionMonitor.ApplyEffects()`에서 `EffectType.Projectile`을 우선 감지하면, 나머지 효과를 새 `SkillEntry` payload로 복제한 뒤 즉시 적용하지 않고 `SkillProjectile`을 발사한다.
- payload에는 `Projectile` 자신을 제외한 효과만 담아, 명중 시 중복 발사 루프가 생기지 않게 했다.

### `SkillProjectile`는 서버 권위로만 이동/명중
- `SkillProjectile`은 서버에서만 target `NetworkObjectId`를 추적해 이동한다.
- `_impactDistance` 이내로 들어오면 `SkillConditionMonitor.ApplyProjectilePayload()`를 호출해 payload 효과를 즉시 적용하고, 이후 `NetworkObject.Despawn(destroy: true)`로 정리한다.
- 클라이언트에는 `NetworkTransform`으로 위치만 동기화한다.

### prefab 등록과 상태 데이터 보정
- 실제 NGO `Spawn()` 경로를 검증하기 위해 `SkillProjectile.prefab`을 만들고 두 `NetworkPrefabsList` 자산에 모두 등록했다.
- 런타임 검증 중 `Poison`이 시전자에게 적용되는 문제가 드러났고, 원인은 `Assets/Resources/ScriptableObjects/Status/posion.asset`의 `targetType=Self` 설정이었다.
- `Poison`은 디버프이며 `SKILL-04`의 검증 기준도 “명중 시 독 디버프 전이”이므로, 데이터만 `Enemy`로 바로잡아 현재 아키텍처 안에서 가장 작은 수정으로 해결했다.

---

## 검증 절차

1. 코드 컴파일 확인
   - `unity-cli editor refresh --compile`
   - `unity-cli console --filter error --stacktrace short`
   - 결과: `[]`
2. 런타임 1차 확인
   - `unity-cli editor play --wait`
   - 열린 씬의 `NetworkManager`를 `StartHost()` 한 뒤, `Character.prefab` 두 개를 source/target으로 스폰
   - `HitAny -> Projectile + Poison` 엔트리를 source `SkillConditionMonitor`에 등록
   - 내부 `HandleHitTarget(targetId)` 호출 후 `SkillProjectile.StepProjectile()`을 반사 호출해 명중 강제
   - 중간 결과: `launched=1;poisoned=False;stacks=0;hpBeforeTick=100;hpAfterTick=100;remainingProjectiles=1`
   - 분석 결과 `Poison` asset의 target이 `Self`로 잡혀 있어 target 전이가 실패함을 확인
3. 데이터 수정 후 런타임 재검증
   - `posion.asset`의 `targetType`을 `Enemy`로 수정
   - `unity-cli editor stop`
   - `unity-cli editor refresh`
   - `unity-cli editor play --wait`
   - 동일한 synthetic Host 하네스로 다시 검증
   - 결과: `launched=1;sourcePoisoned=False;targetPoisoned=True;targetStacks=1;hpBeforeTick=100;hpAfterTick=95;remainingProjectiles=1`
   - 다음 프레임 확인: `projectileCount=0`
4. 종료 후 최종 확인
   - `unity-cli editor stop`
   - `unity-cli editor refresh --compile`
   - `unity-cli console --filter error --stacktrace short`
   - 결과: `[]`

### 결과 해석
- `Projectile` 효과는 실제 `SkillProjectile` 스폰으로 분리되었다.
- 명중 시 payload의 `Poison`이 시전자에게 가지 않고 target에 적용되었다.
- `StatusBehaviour.TickEffects()` 강제 호출 결과 target HP가 `100 -> 95`로 감소해, 독 디버프가 상태 등록에 그치지 않고 실제 DoT 사이클까지 이어짐을 확인했다.
- 투사체는 다음 프레임에 0개로 정리되어 명중 후 소멸 경로도 확인했다.

---

## 주의 사항
- 이번 검증은 Host 단일 인스턴스 기준의 synthetic Play Mode 하네스이며, 원격 클라이언트가 붙은 2클라이언트 transport 검증은 아직 아니다.
- `Assets/Resources/ScriptableObjects/Status/posion.asset` 파일명 오탈자는 기존 자산 경로 호환을 위해 이번 태스크에서 건드리지 않았다.
- 투사체 VFX, 사운드, object pool 최적화는 현재 tracked scope 밖이며 이번 구현에는 포함하지 않았다.

---

## 다음 권장 태스크
- `feature_list.json` 기준 미완료 tracked task는 없다. 다음 단계는 `SKILL-02~04` 변경 묶음 리뷰 또는 커밋/PR 준비다.
