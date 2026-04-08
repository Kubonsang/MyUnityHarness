# 08. COMBAT-01: 서버 권위 HP 시스템

## 세션 목표
서버 권위 HP 시스템 구현. `NetworkVariable<int>`로 HP를 동기화하고, HP 0 시 사망 처리.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Player/PlayerHealth.cs` | **신규**. `NetworkBehaviour`. `NetworkVariable<int> _currentHp` + `ApplyDamage` / `ApplyHeal` 서버 전용 API + `OnHpChanged` 이벤트 + `HandleDeath` |
| `feature_list.json` | COMBAT-01 → `in_progress`, COMBAT-01-UI 신규 추가 (`todo`) |

> **에디터 필수 작업**: `Assets/Resources/Character.prefab`에 `PlayerHealth` 컴포넌트 추가

---

## 범위 분리

| 항목 | 이번 작업 (COMBAT-01) | 후속 태스크 |
|------|----------------------|-------------|
| `NetworkVariable<int>` HP + 서버 전용 API | ✅ | - |
| HP 0 시 `Despawn(destroy: true)` | ✅ | - |
| UI 구독용 `OnHpChanged` 이벤트 노출 | ✅ | - |
| HP UI 렌더링 (Canvas / WorldSpace) | ❌ | **COMBAT-01-UI** |
| 공격 RPC → `ApplyDamage` 호출 | ❌ | **COMBAT-02** |

---

## 핵심 설계

### 동기화 흐름
```
[Server] ApplyDamage(amount) 호출
    → _currentHp.Value 갱신 (NetworkVariable)
         ↓ OnValueChanged (모든 클라이언트)
[모든 클라이언트] OnCurrentHpChanged → OnHpChanged?.Invoke(currentHp, maxHp)
    → UI 레이어(미구현)가 이벤트를 구독해 HP 표시 갱신

[Server] _currentHp.Value <= 0
    → HandleDeath() → NetworkObject.Despawn(destroy: true)
         → 모든 클라이언트에서 오브젝트 제거
```

### NetworkVariable 설정
```csharp
NetworkVariableReadPermission.Everyone      // 모든 클라이언트 읽기
NetworkVariableWritePermission.Server       // 서버만 쓰기
```

### 서버 전용 API
| 메서드 | 설명 |
|--------|------|
| `ApplyDamage(int amount)` | 데미지 적용. COMBAT-02가 호출. `if (!IsServer) return` 가드 |
| `ApplyHeal(int amount)` | HP 회복. `Mathf.Min(_maxHp, ...)` 초과 방지 |

### 늦게 접속한 클라이언트 동기화
`OnNetworkSpawn`에서 `_currentHp.OnValueChanged` 구독 후 즉시 `OnHpChanged?.Invoke` 호출.
NGO의 NetworkVariable은 스폰 시 현재 값을 클라이언트에 전달하므로 별도 ClientRpc 불필요.

---

## 검증 절차
1. `Assets/Resources/Character.prefab`에 `PlayerHealth` 컴포넌트 추가 (에디터)
2. NGO_Setup.unity → Play → Host 시작
3. 콘솔에서 `playerHealth.ApplyDamage(30)` 직접 호출 (Inspector Debug 또는 임시 코드)
4. `OnHpChanged` 이벤트 수신 로그 확인 (임시 구독 추가)
5. HP 0 이하 시 오브젝트 Despawn 확인
6. ParrelSync Client → 동일 HP 값 동기화 확인
7. 완료 → feature_list.json COMBAT-01 → `done`

---

## 주의 사항

| 항목 | 내용 |
|------|------|
| `PlayerHealth` 컴포넌트 누락 | Character.prefab에 추가 전까지 HP 시스템 동작 불가 |
| 사망 시 `Despawn(destroy: true)` | 리스폰 시스템 도입 시 `Despawn(destroy: false)` + 풀링으로 교체 필요 |
| `_maxHp` 비동기화 | `_maxHp`는 NonNetworkVariable. 모든 클라이언트가 동일한 프리팹을 사용하므로 현재 무관하나, 역할별 스탯(ROLE-01) 도입 시 재검토 필요 |
| HP UI 없음 | `OnHpChanged` 이벤트는 노출됐으나 UI 렌더링은 COMBAT-01-UI 태스크로 분리됨 |

---

## 다음 권장 태스크
- **COMBAT-02**: 공격 요청 RPC → `ApplyDamage()` 호출 (공격 대상 유효성 검증 포함)
- **COMBAT-01-UI**: HP UI 렌더링 (WorldSpace HP 바 또는 HUD)
