# 11. MONSTER-01: MonsterData ScriptableObject

## 세션 목표
몬스터 종류별 기본 스탯(maxHp, damage, moveSpeed, attackRange, attackDuration, detectionRange)을 Inspector에서 편집 가능한 ScriptableObject로 정의.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Monster/MonsterData.cs` | **신규**. `[CreateAssetMenu(menuName = "GNF/Monster Data")]` ScriptableObject |
| `feature_list.json` | MONSTER-01 → `in_progress` |

---

## 핵심 설계

### 패턴 참조
`WeaponData.cs` 패턴 그대로 적용:
- `[CreateAssetMenu]` 메뉴 등록
- `public` 필드 + `[Tooltip]` 속성
- `using UnityEngine` 외 의존성 없음

### 필드 목록

| 필드 | 타입 | 기본값 | 용도 |
|------|------|--------|------|
| `maxHp` | `int` | 50 | MonsterHealth 초기 HP |
| `damage` | `int` | 10 | MonsterFSM Attack 시 PlayerHealth.ApplyDamage 인수 |
| `moveSpeed` | `float` | 3f | NavMeshAgent.speed 설정값 |
| `attackRange` | `float` | 1.5f | MonsterFSM Idle→Chase→Attack 전환 판정 반경 |
| `attackDuration` | `float` | 1.0f | MonsterFSM Attack 상태 체류 시간 (타이머) |
| `detectionRange` | `float` | 10f | MonsterFSM Idle→Chase 전환 플레이어 탐지 반경 |

### 의존성
MonsterData는 **순수 데이터** — Unity 런타임 의존성 없음.
MonsterHealth(MONSTER-02), MonsterFSM(MONSTER-04), MonsterSpawner(MONSTER-07)가 `[SerializeField]` 참조로 주입받는다.

---

## 검증 절차

1. Unity 에디터 컴파일 확인 (오류 없음)
2. Project 창 빈 폴더 우클릭 → **Create → GNF → Monster Data** 메뉴 확인
3. 생성된 에셋 선택 → Inspector에서 6개 필드 편집 가능 확인
4. 완료 → feature_list.json MONSTER-01 → `done`

---

## 주의 사항

없음. 순수 데이터 클래스이며 런타임 로직 없음.

---

## 다음 권장 태스크
- **MONSTER-02**: MonsterHealth — NetworkVariable<int> HP + ApplyDamage(amount, attackerClientId) + OnDamageDealt 이벤트
- **MONSTER-09**: IDamageable 인터페이스 — MONSTER-02와 병행 가능
