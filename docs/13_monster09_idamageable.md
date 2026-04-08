# 13. MONSTER-09: IDamageable 인터페이스 + PlayerCombat 확장

## 세션 목표
`IDamageable` 인터페이스를 도입해 `PlayerCombat`이 `PlayerHealth`와 `MonsterHealth`를 동일하게 타격하도록 통합.
`attackerClientId` 전달로 AggroSystem(MONSTER-05) 연동 준비.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Interface/IDamageable.cs` | **신규**. `ApplyDamage(int amount, ulong attackerClientId)` 인터페이스 |
| `Assets/Scripts/Player/PlayerHealth.cs` | `IDamageable` 구현. `ApplyDamage(int amount)` → `ApplyDamage(int amount, ulong attackerClientId)` 시그니처 변경 |
| `Assets/Scripts/Monster/MonsterHealth.cs` | `IDamageable` 추가 (시그니처 이미 일치) |
| `Assets/Scripts/Player/PlayerCombat.cs` | `NetworkObject` 캐싱 + `TryGetComponent<IDamageable>` + `attackerClientId` 전달 |
| `feature_list.json` | MONSTER-09 → `in_progress` |

> ⚠️ **MONSTER-02 미검증 상태**: `MonsterHealth`는 코드 완성이나 에디터 검증 미완. 본 태스크의 인터페이스 추가는 시그니처 변경 없는 클래스 선언 수정이므로 독립적으로 안전.

---

## 핵심 설계

### IDamageable 인터페이스
```csharp
public interface IDamageable
{
    void ApplyDamage(int amount, ulong attackerClientId);
}
```
런타임 의존성 없는 순수 인터페이스. MonsterHealth.OnDamageDealt(MONSTER-02)가 이 ID를 AggroSystem(MONSTER-05)에 전달한다.

### PlayerHealth 시그니처 변경
- `ApplyDamage(int amount)` → `ApplyDamage(int amount, ulong attackerClientId)`
- `attackerClientId` 는 PlayerHealth 내부에서 미사용 (PvP 미지원)
- 인터페이스 통일 목적으로만 수신
- ContextMenu 테스트 코드: `ApplyDamage(10, 0)`

### PlayerCombat 변경
```
Before: TryGetComponent<PlayerHealth> → ApplyDamage(_attackDamage)
After:  TryGetComponent<IDamageable>  → ApplyDamage(_attackDamage, attackerClientId)
```
- `NetworkObject` 캐싱: `Awake()`에서 `GetComponent<NetworkObject>()`
- `OwnerClientId`: 공격자의 클라이언트 ID → MonsterHealth.OnDamageDealt로 전파 → AggroSystem 어그로 누적

### 타격 대상 확장
| 구현 전 | 구현 후 |
|---------|---------|
| PlayerHealth만 타격 | PlayerHealth + MonsterHealth 모두 타격 |

---

## 검증 절차

1. Unity 에디터 컴파일 확인 (오류 없음)
2. Host + Client 연결. 플레이어 공격 → 상대방 PlayerHealth HP 감소 확인 (기존 동작 유지)
3. 몬스터 프리팹에 MonsterHealth 추가 후 → 플레이어 공격 → MonsterHealth HP 감소 확인
4. Client가 직접 ApplyDamage 호출 불가 확인 (`if (!IsServer) return` 가드)
5. 완료 → feature_list.json MONSTER-09 → `done`

---

## 주의 사항

| 항목 | 내용 |
|------|------|
| PlayerHealth 시그니처 변경 | `ApplyDamage(int amount)` 직접 호출 코드가 있으면 컴파일 에러. 현재 PlayerCombat만 호출하므로 문제 없음 |
| MONSTER-02 미검증 | MonsterHealth 동작이 확인되지 않아 몬스터 타격 검증은 MONSTER-02 에디터 설정 후 가능 |

---

## 다음 권장 태스크
- **MONSTER-02 검증**: 몬스터 프리팹 설정 후 HP 감소 / Despawn(destroy:false) 확인
- **MONSTER-03**: MonsterAnimationController (NetworkVariable&lt;byte&gt; 상태 동기화)
