# 26. ROLE-05-A: DPS 전용 무적 플래그(isInvincible) 통합

## 세션 목표
`PlayerHealth`에 서버 권위 무적 플래그(`_isInvincible`)를 추가한다.
무적 상태 중 `ApplyDamage()`가 호출되면 데미지를 무시하고 서버 콘솔에 로그를 남긴다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerHealth.cs` | `_isInvincible` bool 필드, `SetInvincible(bool)` API, `ApplyDamage()` 내 무적 분기 추가 |

---

## 핵심 설계

### 무적 플래그 구조

```csharp
// PlayerHealth.cs 서버 전용 필드
private bool _isInvincible;

// 공개 API — 서버에서만 호출 가능
public void SetInvincible(bool value)
{
    if (!IsServer) return;
    _isInvincible = value;
    Debug.Log($"[PlayerHealth] Client {OwnerClientId} 무적 {(value ? "활성화" : "해제")}");
}
```

### 데미지 무시 분기

```csharp
public void ApplyDamage(int amount, ulong attackerClientId)
{
    if (!IsServer) return;
    if (amount <= 0) return;

    if (_isInvincible)
    {
        Debug.Log($"[PlayerHealth] Client {OwnerClientId} 무적 상태 — 데미지 {amount} 무시");
        return;
    }
    // ... HP 차감
}
```

### 설계 결정

| 항목 | 결정 | 이유 |
|------|------|------|
| 플래그 타입 | 서버 로컬 `bool` (NetworkVariable 아님) | 판정이 서버에서만 발생하므로 클라이언트 동기화 불필요 |
| 호출자 책임 | `SetInvincible()`은 범용 API | DPS 여부 판단은 호출자(스킬 시스템)가 담당. PlayerHealth는 플래그만 관리 |
| STATUS 통합 경로 | STATUS-04 `Invincible` 버프 구현 시 이 API를 재사용 | 미리 만든 경로를 활용해 STATUS 시스템 연동 시 중복 구현 방지 |

---

## 검증 절차

1. Unity 에디터에서 Host 실행
2. DPS 플레이어 스폰
3. Console에서 `PlayerHealth.SetInvincible(true)` 수동 호출 (Inspector ContextMenu 또는 테스트 코드)
4. 몬스터가 DPS 플레이어를 공격 → 서버 Console에 `무적 상태 — 데미지 N 무시` 로그 확인
5. `SetInvincible(false)` 호출 후 재공격 → HP 차감 정상 동작 확인
6. 완료 → feature_list.json ROLE-05-A → `done`

---

## 주의 사항

- 현재 `SetInvincible()`을 호출하는 진입점이 없음. ROLE-05-B(대쉬) 또는 SKILL 시스템 구현 시 연동 필요.
- `_isInvincible`은 NetworkVariable이 아니므로 클라이언트에서 무적 시각 효과(VFX)가 필요하면 별도 동기화 채널 추가 필요.

---

## 다음 권장 태스크

- **ROLE-05-B**: DPS용 단순 전방 대쉬(Dummy Dash) 발동 뼈대 — 대쉬 중 `SetInvincible(true/false)` 호출 진입점으로 활용 가능
