# 43. STATUS-FIX-02: ActiveEffect CasterClientId — DoT 어그로 귀속

## 세션 목표
PR#2 리뷰 지적: DoT 피해(`Poison`/`Burn` 틱)가 `attackerClientId=0`으로 고정되어 어그로 테이블에 시전자가 귀속되지 않는 문제 수정.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Status/ActiveEffect.cs` | `CasterClientId ulong` 필드 추가 + `NetworkSerialize` 직렬화 추가 |
| `Assets/Scripts/Status/IStatusEffectable.cs` | `ApplyEffect` 시그니처에 `casterClientId = 0` 파라미터 추가 |
| `Assets/Scripts/Status/StatusBehaviour.cs` | `ApplyEffect` + `OnEffectTick` 시그니처 업데이트, `TickEffects`에서 `effect.CasterClientId` 전달 |
| `Assets/Scripts/Status/PlayerStatus.cs` | `OnEffectTick(type, stacks, casterClientId)` — `ApplyDamage`에 casterClientId 전달 |
| `Assets/Scripts/Status/MonsterStatus.cs` | 동일 |

---

## 핵심 설계

### 데이터 흐름
```
ApplyEffect(data, stacks, casterClientId=1)
  → ActiveEffect { ..., CasterClientId=1 } 를 NetworkList에 저장

TickEffects()
  → OnEffectTick(Poison, stacks=3, casterClientId=1)
    → MonsterStatus._health.ApplyDamage(15, attackerClientId=1)
      → AggroSystem.OnDamageDealt(15, 1) → _aggroTable[1] += 15 × aggroPerDamage
```

### CasterClientId Equals 제외 근거
`Equals`는 `RemainingDuration`, `Stacks`만 비교. `CasterClientId`는 적용 후 불변이므로 포함하지 않아도 NGO NetworkList `[i]=value` 쓰기 무결성에 영향 없음.

### 갱신(Refresh) 시 CasterClientId 유지
동일 효과 재적용 시 기간·스택만 갱신, `CasterClientId`는 최초 시전자 유지.
재적용 시 시전자를 교체해야 할 요구사항이 생기면 별도 태스크로 처리.

### 하위 호환성
`ApplyEffect(data, stacks = 1, casterClientId = 0)` — 기존 호출부(테스트 코드, Editor ContextMenu)는 수정 없이 컴파일 유지.

---

## 검증

### 컴파일 ✅
`unity-cli editor refresh --compile` → 에러 없음

### 논리 검증 (exec) ✅
- casterClientId=1, Poison 3스택 → `ApplyDamage(15, 1)` → `_aggroTable[1]` 귀속 [PASS]

STATUS-FIX-02 → `done` ✅

---

## 주의 사항
- **NetworkList 대역폭**: `CasterClientId`(ulong, 8바이트)가 `ActiveEffect` 직렬화에 추가됨. 기존 13바이트(byte+float+byte) → 21바이트. 효과가 많을수록 late-join 동기화 비용 소폭 증가.
- **재적용 시 시전자 교체 미지원**: 동일 효과를 다른 플레이어가 재적용해도 CasterClientId는 최초 시전자로 유지됨. SKILL 시스템 구현 시 요구사항 재검토 필요.

---

## 다음 권장 태스크
- **STATUS-OPT-01**: NetworkList 틱 쓰기 최적화 — RemainingDuration 서버 로컬 분리 검토
