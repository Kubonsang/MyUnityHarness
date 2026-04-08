# 56. SKILL-02: Commit Split 이후 재검증 완료

## 세션 목표
`SKILL-01`을 별도 커밋으로 분리한 뒤, 남아 있던 `SKILL-02` 구현을 task-start 절차로 다시 점검하고 정식 `done` 상태로 마무리한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `feature_list.json` | `SKILL-02` 상태를 `in_progress`로 올린 뒤 재검증 후 `done`으로 갱신 |
| `docs/56_skill02_reverify_after_split.md` | **신규** — 커밋 분리 이후 재검증 결과 기록 |

---

## 핵심 설계

### 커밋 분리 이후 task 재개
- 이번 세션의 목적은 새로운 로직 추가가 아니라, 이미 작업 트리에 있던 `SKILL-02` 변경을 `SKILL-01` 커밋과 분리한 뒤 다시 검증하는 것이었다.
- 따라서 `SkillConditionMonitor`, `PlayerCombat`, `PlayerHealth`, `PlayerInventory`, `Character.prefab` 변경은 그대로 유지하고, `feature_list.json` 상태만 `todo -> in_progress -> done` 순서로 재정렬했다.

### 검증 하네스 보정
- 처음 재검증에서는 `PlayerInventory.Awake()`가 `SkillConditionMonitor`보다 먼저 실행되어, `_skillConditionMonitor` 캐시가 null로 잡히는 하네스 문제가 있었다.
- 실제 게임 코드 수정 없이, 검증용 임시 오브젝트 생성 순서를 `PlayerHealth -> PlayerCombat -> SkillConditionMonitor -> PlayerInventory`로 맞춰 이벤트 등록 로그가 정상 수집되도록 했다.
- 이 보정은 런타임 하네스 구성 문제를 해결한 것이며, 실제 `Character.prefab`에는 이미 `SkillConditionMonitor`가 붙어 있으므로 본 게임 경로와 충돌하지 않는다.

---

## 검증 절차

1. 컴파일 검증
   - `unity-cli status`
   - `unity-cli editor refresh --compile`
   - `unity-cli console --filter error --stacktrace short`
   - 결과: `[]`
2. 런타임 검증
   - `unity-cli console --clear --port 8090`
   - `unity-cli editor play --wait`
   - `unity-cli exec --port 8090 ...` 로 임시 `NetworkManager`/`ItemRegistry`/`ItemSkillData`/플레이어/타깃 오브젝트를 생성
   - `PlayerInventory.ServerAddItem(1)`, `PlayerCombat.PerformAttack()`, `PlayerHealth.ApplyDamage(7, 99)` 호출
   - 로그 결과:
     - `[SkillConditionMonitor] 엔트리 등록: Skill02_TestAsset +2 (client=0)`
     - `[SkillConditionMonitor] Hit 이벤트 수신: target=5, matched=1 (client=0)`
     - `[SkillConditionMonitor] Hit 이벤트 수신: target=5, matched=1 (client=0)`
     - `[SkillConditionMonitor] Damaged 이벤트 수신: amount=7, attacker=99, matched=1 (client=0)`
   - `unity-cli editor stop --port 8090`
   - 종료 후 `unity-cli console --filter error --stacktrace short --port 8090`
   - 결과: `[]`

---

## 주의 사항
- `Hit` 로그가 2회 찍힌 것은 하네스에서 `Physics.OverlapSphere`가 동일 타깃을 두 번 관측한 synthetic 상황 때문이다.
- 이번 태스크의 완료 기준은 “타격 및 피격 이벤트 리시빙 로그가 실제로 발생하는지”이므로, 최소 1회 이상 수신이 확인된 현재 결과로 기준을 충족한다.
- `EffectType` 실제 해석과 `IStatusEffectable` 경로 연동은 다음 태스크 `SKILL-03` 범위다.

---

## 다음 권장 태스크
- **SKILL-03**: `Condition 판정 로직과 Effect 부여 연동 (IStatusEffectable 경로)`
