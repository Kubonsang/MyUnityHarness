# 01. 프로젝트 청사진

> **이 문서는 AI 에이전트 간 인수인계 문서입니다.**
> 세션 시작 전 반드시 읽고, 세션 종료 시 변경 사항을 반영하세요.

---

## 프로젝트 개요

- **프로젝트명**: GNF_
- **장르**: 4인 멀티플레이어 롤플레잉 게임
- **엔진**: Unity 6 (6000.3.8f1)
- **렌더 파이프라인**: URP 17.3.0
- **멀티플레이어**: Netcode for GameObjects 2.10.0 (서버 권위 방식)
- **입력**: Input System Package 1.18.0 (이벤트 기반)

---

## Unity 환경 및 의존성

| 패키지 | 버전 | 용도 | 설치 상태 |
|--------|------|------|-----------|
| com.unity.netcode.gameobjects | 2.10.0 | 멀티플레이어 네트워킹 | ✅ |
| com.unity.inputsystem | 1.18.0 | 입력 처리 | ✅ |
| com.unity.cinemachine | 3.1.6 | 카메라 시스템 | ✅ |
| com.unity.ai.navigation | 2.0.10 | AI NavMesh | ✅ |
| com.unity.multiplayer.center | 1.0.1 | 멀티플레이어 허브 | ✅ |
| com.unity.render-pipelines.universal | 17.3.0 | 렌더링 | ✅ |
| com.unity.timeline | 1.8.10 | 타임라인 연출 | ✅ |
| com.unity.test-framework | 1.6.0 | 유닛 테스트 | ✅ |

---

## 프로젝트 구조

```
GNF_/
├── Assets/
│   ├── Scripts/              ← 게임 로직 스크립트 (현재 비어있음)
│   ├── Resources/            ← 런타임 로드 에셋 (Character.prefab 등)
│   ├── Scenes/               ← 씬 파일 (SampleScene.unity)
│   ├── Settings/             ← URP 렌더 파이프라인 설정
│   ├── RPGTinyHeroWavePBR/   ← 캐릭터 에셋 팩
│   └── InputSystem_Actions.inputactions  ← 9개 액션 정의됨
├── docs/                     ← AI 협업용 작업 문서 (NN_xxx.md)
│   └── errorlogs/            ← 에러 로그 (NN_xxx.md)
├── feature_list.json         ← 피처 작업 추적 파일
├── ProjectSettings/
└── CLAUDE.md                 ← 최우선 참조 문서
```

**SampleScene 현재 상태**: Cinemachine Camera, Main Camera, Plane(Ground), Directional Light, Global Volume 존재. 스크립트 없음.

---

## 우선순위 원칙 (충돌 시 이 순서를 따른다)

1. **Correctness** — 정확성을 우아함과 타협하지 않는다.
2. **Verification** — 검증 가능성을 속도와 타협하지 않는다.
3. **Minimal change** — 작은 안전한 변경 > 큰 리팩토링.
4. **Readability**
5. **Performance** (런타임 핫패스에만 엄격하게 적용)
6. **Reusability**
7. **Abstraction**

불확실할 때: **YAGNI > KISS > Readability > DRY > Abstraction**

---

## 작업 워크플로우 (모든 코딩 태스크에 적용)

```
Step 1. Inspect   → 관련 파일 먼저 읽기. 기존 패턴 재사용 확인.
Step 2. Plan      → 기존 클래스 수정 > 새 서브시스템 생성. 최소 변경 우선.
Step 3. Implement → 현재 아키텍처 보존. 불필요한 rename/이동 금지.
Step 4. Verify    → 컴파일, 논리적 일관성, 런타임 동작 확인.
Step 5. Report    → Goal / Files Inspected / Changes Made / Why / Verification / Risks / Next Task
```

---

## 작업 추적: feature_list.json

### 스키마
```json
{
  "id": "NET-01",
  "task": "작업 설명",
  "status": "todo",
  "verification": "완료 판단 기준 (구체적으로)"
}
```

### status 값
| 값 | 의미 |
|----|------|
| `todo` | 작업 대기 |
| `in_progress` | 진행 중 (부분 구현 또는 블로킹) |
| `test_failure` | 구현 완료, 검증 실패 |
| `done` | 완료 — verification 증거 필수 |

### 실행 규칙
1. **No Untracked Work** — `feature_list.json`에 없는 작업은 절대 구현하지 않는다.
2. **One Task at a Time** — 세션당 하나의 태스크만.
3. **Atomic Changes** — 현재 태스크 범위만 변경. 관계없는 개선 금지.
4. **Verification Required** — 증거 없이 `done` 처리 금지.
5. **Failure Logging** — `test_failure` 시 즉시 `docs/errorlogs/`에 기록.

---

## 문서화 규칙

- 작업 기록: `docs/NN_xxx.md` (순번, 한국어)
- 에러 기록: `docs/errorlogs/NN_xxx.md`
- **매 세션 종료 시**: 세션 목표 / 변경 파일 / 핵심 결정 / 검증 결과 / 미해결 이슈 / 다음 단계 기록
- 언어: 한국어 (기술 용어·코드는 영어)

---

## 코딩 원칙

- **Single Responsibility** — 클래스 ~200줄 기준 검토, 300줄 초과 시 분리 또는 정당화
- **Composition over Inheritance**
- **명확한 코드 > 영리한 추상화**
- **네이밍**: `_camelCase` (private), `PascalCase` (public)
- `const`, `readonly`, `[SerializeField]` 활용. 매직 넘버 금지.
- 한 번만 쓰는 코드는 추상화하지 않는다. (YAGNI)

### Unity 성능 제약 (런타임 핫패스 한정)
- `Update()` 내 무거운 연산 / 씬 전체 검색 금지
- `GetComponent<T>()`, `Camera.main` → `Awake()`에서 캐싱
- `GameObject.Find`, `FindObjectOfType`, `SendMessage` 금지
- 루프 내 `new` / 문자열 `+` 금지
- Object Pooling: 총알·이펙트·VFX 등 반복 스폰에 필수
- 빈 `Update()` 콜백 반드시 삭제

---

## 멀티플레이어 규칙 (NGO)

### 권위 모델
- **서버**: 게임 상태의 단일 진실 (HP, 전투 결과, 스폰/디스폰, 인벤토리, 위치)
- **클라이언트**: 서버에 행동 요청(RPC)만 전송

### NetworkVariable vs RPC 판단
| 데이터 성격 | 사용 |
|------------|------|
| 지속적 동기화 상태 (HP, 스탯 등) | `NetworkVariable` |
| 일회성 이벤트 (공격, 이펙트 트리거) | `RPC` |
| 클라이언트 로컬 표현 (UI 애니메이션 등) | 동기화 불필요 |
| 예측 임시 상태 | 예측 경로 명시, 서버 해소와 분리 |

### Sync 설계 전 체크리스트
네트워크 동기화 추가 전 판단:
- 서버 권위 게임플레이 상태인가?
- 클라이언트 로컬 표현 상태인가?
- 일회성 이벤트인가?
- 예측 임시 상태인가?

**반드시 공유해야 하는 것만 동기화한다.**

### Bandwidth 제약
- `NetworkVariable` 빈번한 쓰기 지양
- 변경되지 않은 값 전송 금지
- 순수 시각적 로컬 상태는 동기화하지 않는다

---

## 금지 항목

- 태스크에서 요청하지 않은 기능 추가 금지
- 요청 없이 광범위 리팩토링 금지
- 검증 증거 없이 `done` 처리 금지
- 기존 프로젝트 패턴 무시 금지
- `[SerializeField]` 참조를 `GameObject.Find()`로 교체 금지
- 클라이언트 편의를 멀티플레이어 권위로 취급 금지

---

## 개발 로드맵

**전략**: 네트워크 우선 (Server-authoritative 기반을 먼저 구축)

| ID | Phase | Task | Status |
|----|-------|------|--------|
| SETUP-01 | 환경 | NGO 패키지 설치 | ✅ done |
| NET-01 | 네트워크 | NetworkManager 씬 설정 및 Host/Client 연결 | todo |
| NET-02 | 네트워크 | NetworkPlayer 프리팹 (NetworkObject + NetworkTransform) | todo |
| PLAYER-01 | 플레이어 | PlayerController: 이동 (서버 권위) | todo |
| PLAYER-02 | 플레이어 | PlayerInputHandler: Input System 이벤트 연동 | todo |
| PLAYER-03 | 플레이어 | PlayerAnimationController: Animator 상태 동기화 | todo |
| PLAYER-04 | 플레이어 | Player FSM: Idle / Walk / Run / Attack | todo |
| COMBAT-01 | 전투 | HP 시스템 (NetworkVariable\<int\>) | todo |
| COMBAT-02 | 전투 | 공격 요청 RPC + 서버 데미지 처리 | todo |
| ROLE-01 | 역할 | 캐릭터 역할 인터페이스 정의 (Tank/Healer/DPS/Support) | todo |

> 세션 종료 시 이 테이블의 status를 `feature_list.json`과 동기화할 것.
