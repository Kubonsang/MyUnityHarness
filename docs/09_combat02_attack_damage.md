# 09. COMBAT-02: 공격 요청 RPC + 서버 데미지 처리

## 세션 목표
클라이언트 공격 입력 → ServerRpc → 서버 대상 탐지 → HP 차감 흐름 구현.
클라이언트가 직접 HP를 수정할 수 없음을 보장.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerCombat.cs` | **신규**. `MonoBehaviour`. `PerformAttack()` — Physics.OverlapSphere로 대상 탐지 후 `ApplyDamage()` 호출 |
| `Assets/Scripts/Player/PlayerController.cs` | `_combat` 필드 추가 + Awake 캐싱. `SetAttackPressed()` / `SendAttackServerRpc()`에서 `_combat?.PerformAttack()` 호출 추가 |
| `feature_list.json` | COMBAT-02 → `in_progress` |

> **에디터 필수 작업**: `Assets/Resources/Character.prefab`에 `PlayerCombat` 컴포넌트 추가

---

## 범위 분리

| 항목 | 이번 작업 (COMBAT-02) | 후속 태스크 |
|------|----------------------|-------------|
| OverlapSphere 대상 탐지 + ApplyDamage 호출 | ✅ | - |
| 자신 제외 유효성 검증 | ✅ | - |
| 공격 타이밍 (애니메이션 hit frame 연동) | ❌ | 신규 태스크 필요 |
| LayerMask 최적화 | ❌ | 신규 태스크 필요 |

---

## 핵심 설계

### 공격 처리 흐름 (전체)
```
[Client] InputSystem → PlayerInputHandler.OnAttack()
    → PlayerController.SetAttackPressed()
        → [IsOwner && !IsServer] SendAttackServerRpc() → 서버로 전송
        → [IsOwner && IsServer]  직접 실행

[Server] SendAttackServerRpc() 수신 또는 직접 실행
    ├─ PlayerFSM.NotifyAttack()         → 공격 애니메이션 재생 (기존)
    └─ PlayerCombat.PerformAttack()     → 데미지 처리 (신규)
           ↓ Physics.OverlapSphere
       대상 PlayerHealth 발견 → ApplyDamage(_attackDamage)
           ↓ NetworkVariable<int> 갱신
       [모든 클라이언트] HP 동기화
```

### SRP 역할 분리
| 컴포넌트 | 역할 |
|----------|------|
| `PlayerController` | 입력 수신 + ServerRpc 전달 + 물리 이동 |
| `PlayerFSM` | 애니메이션 상태 결정 |
| `PlayerCombat` | 공격 히트 판정 + 데미지 적용 |
| `PlayerHealth` | HP 데이터 + 사망 처리 |

### 대상 탐지 로직
```csharp
Collider[] hits = Physics.OverlapSphere(transform.position, _attackRange);
foreach (var hit in hits)
{
    if (hit.gameObject == gameObject) continue;  // 자신 제외
    if (hit.TryGetComponent(out PlayerHealth target))
        target.ApplyDamage(_attackDamage);
}
```
- `Physics.OverlapSphere` — 서버에서만 실행 (PlayerController.IsServer 보장)
- `PlayerHealth`가 없는 Collider(지형, 오브젝트 등)는 자동으로 무시
- 클라이언트는 `ApplyDamage`를 직접 호출할 수 없음 (`if (!IsServer) return` 가드)

---

## 검증 절차
1. `Character.prefab`에 `PlayerCombat` 컴포넌트 추가 (에디터)
2. NGO_Setup.unity → Play → Host + ParrelSync Client 실행
3. 플레이어 2명 동일 화면에 배치
4. 공격 입력(좌클릭) → 상대방 `PlayerHealth._currentHp` Inspector에서 감소 확인
5. 공격 범위 밖 → HP 미감소 확인 (`_attackRange` 조정하여 테스트)
6. Client에서 공격 → Host Client 양측 HP 동기화 확인
7. HP 0 → 오브젝트 Despawn 확인
8. 완료 → feature_list.json COMBAT-02 → `done`

---

## 주의 사항

| 항목 | 내용 |
|------|------|
| `PlayerCombat` 컴포넌트 누락 | `_combat == null` → `?.PerformAttack()` silent no-op. 반드시 prefab에 추가 필요 |
| 공격 즉시 판정 | 공격 입력 시점에 OverlapSphere 실행. 애니메이션 hit frame과 무관. 플레이어가 공격 판정 전에 이동했을 경우 어색할 수 있음 |
| LayerMask 미적용 | 모든 Collider를 순회 후 TryGetComponent 필터링. 씬이 복잡해지면 성능 저하 가능. Player Layer 설정 후 LayerMask 도입 권장 |
| 다단 히트 | OverlapSphere 결과 중 한 플레이어에게 Collider가 여러 개이면 중복 데미지 가능. 현재 단순 씬 구성에서는 문제 없음 |

---

## 다음 권장 태스크
- **ROLE-01**: 4가지 캐릭터 역할 인터페이스 정의 (Tank, Healer, DPS, Support)
- **COMBAT-01-UI**: HP UI 렌더링
