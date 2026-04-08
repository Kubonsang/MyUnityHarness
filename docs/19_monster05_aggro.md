# 19. MONSTER-05: AggroSystem

## 세션 목표
데미지 누적 + 거리 기반 + decay 어그로 시스템 구현. MonsterFSM.FindNearestPlayer() 교체.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/AggroSystem.cs` | **신규**. MonoBehaviour 어그로 시스템 |
| `Assets/Scripts/Monster/MonsterFSM.cs` | `_aggroSystem` 캐시, `GetAITarget()` 추가, `FindNearestPlayer()` fallback 처리 |
| `feature_list.json` | MONSTER-05 → `in_progress` |

---

## 핵심 설계

### 어그로 공식

| 종류 | 공식 | 설명 |
|------|------|------|
| 데미지 어그로 | `+= damage × _aggroPerDamage` | OnDamageDealt 이벤트 수신 시 즉시 적용 |
| 근접 어그로 | `+= _proximityAggroPerSecond / dist × deltaTime` | Tick()마다 탐지 범위 내 플레이어에 적용 |
| decay | `-= _aggroDecayPerSecond × deltaTime` (최소 0) | Tick()마다 전체 감소 |

### MonsterFSM 연동

```
GetAITarget() {
    if (_aggroSystem != null) → AggroSystem.GetTarget()   ← MONSTER-05
    else                      → FindNearestPlayer()        ← fallback
}
```

AggroSystem이 프리팹에 없어도 크래시 없이 거리 기반 fallback으로 동작.

### 풀링 호환 (OnEnable/OnDisable)

| 이벤트 | 동작 |
|--------|------|
| `OnEnable` (스폰) | `_aggroTable.Clear()` + `OnDamageDealt` 구독 |
| `OnDisable` (풀 반환) | `OnDamageDealt` 구독 해제 |

재스폰 시 어그로 테이블 자동 초기화. 풀 라이프사이클과 완벽 호환.

### 핫패스 할당 방지

- `Physics.OverlapSphereNonAlloc` — `Collider[32]` 재사용 버퍼
- `List<ulong> _keysCache` — Dictionary decay 순회용 재사용 리스트

---

## 에디터 설정

```
몬스터 프리팹에 AggroSystem 컴포넌트 추가:
    _data:                    [MonsterFSM과 동일 MonsterData 에셋]
    _aggroDecayPerSecond:     2
    _aggroPerDamage:          1
    _proximityAggroPerSecond: 0.5
```

---

## 검증 절차

1. 몬스터 프리팹에 AggroSystem 추가 + _data 할당
2. Host 시작 → 2명 이상 플레이어 중 한 명이 몬스터를 먼저 공격
3. 몬스터가 공격한 플레이어를 우선 추적하는지 확인 (데미지 어그로)
4. 공격 없이 장시간 경과 → decay로 최근접 플레이어로 전환 확인
5. 완료 → feature_list.json MONSTER-05 → `done`

---

## 주의 사항

- `GetTarget()` 내 OverlapSphereNonAlloc 버퍼 최대 32개. 플레이어 4명이므로 충분.
- AggroSystem이 없으면 FindNearestPlayer() fallback → 어그로 없이 거리 기반 동작.

---

## 다음 권장 태스크
- **ROLE-01**: 4가지 캐릭터 역할 인터페이스 (Tank, Healer, DPS, Support)
