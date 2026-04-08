# PLAYER-03 검증 실패: Walk 애니메이션 미재생

## 증상
- WASD 입력 시 플레이어 이동 정상
- Walk 애니메이션(`MoveFWD_Normal_InPlace_NoWeapon`) 전혀 재생되지 않음

---

## 원인 분석

### 확인된 원인 (우선순위 순)

#### 1. [확정] PlayerAnimationController 컴포넌트 미추가
- `Assets/Resources/Character.prefab`에 PlayerAnimationController 컴포넌트가 없음
- grep 결과: GUID `d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9` 없음
- **영향**: `PlayerController.Awake()`에서 `GetComponent<PlayerAnimationController>()` → null
- `_animController?.SetMoving(...)` → null 조건부 호출이라 예외 없이 무시됨
- 결과: NetworkVariable `_isMoving` 값이 절대 변경되지 않음 → 어떤 클라이언트도 애니메이션 전환 안 됨

#### 2. [확인됨, 양호] NetworkManager PlayerPrefab 등록
- NGO_Setup.unity: `PlayerPrefab: {guid: 3a3804bb750474782a9dc02e16806c90}` → Character.prefab ✅

#### 3. [위험 요소] NoWeaponStance.controller 기본 상태
- Default state: `Idle_Battle_NoWeapon` (Battle 계열)
- CrossFade 대상: `Idle_Normal_NoWeapon` (Normal 계열)
- ExitTime 기반 전환이 Walk→다른 상태로 강제 전환할 가능성 있음
- **현재 원인은 아니지만**, PlayerAnimationController 추가 후 2차 실패 시 이 원인 재조사 필요

---

## 수정 방법

### 필요한 에디터 작업 (코드 변경 없음)

**`Assets/Resources/Character.prefab` 열기**
1. Inspector → Add Component → `PlayerAnimationController` 추가
2. Ctrl+S 저장

### 수정 후 검증 항목
1. Play → Host 시작 → Inspector에서 Character 오브젝트 선택
2. WASD 입력 → `PlayerAnimationController` 컴포넌트의 `Is Moving` 체크박스 변경 확인
3. Animator 창에서 `MoveFWD_Normal_InPlace_NoWeapon` 상태 하이라이트 확인
4. 입력 해제 → `Idle_Normal_NoWeapon` 복귀 확인
5. (ExitTime 문제 발생 시) 아래 별도 처리 참조

---

## ExitTime 문제 발생 시 (2차 실패 시나리오)

### 증상
- PlayerAnimationController 추가 후에도 Walk 상태가 곧바로 다른 상태로 전환됨

### 원인
- NoWeaponStance.controller의 상태들이 ExitTime 기반 전환으로 연결됨
- `CrossFadeInFixedTime`으로 진입한 Walk 상태가 ExitTime에 의해 다른 상태로 이동

### 해결 옵션
1. **Animator Controller에서 ExitTime 전환 제거** (에디터에서 해당 transition 선택 → Has Exit Time 해제)
2. **별도 심플 Animator Controller 생성** — `Idle_Normal_NoWeapon` / `MoveFWD_Normal_InPlace_NoWeapon` 두 상태만 있고 ExitTime 없는 minimal controller
3. **Animator Override Controller 사용** — 기존 controller를 수정하지 않고 override

---

## 관련 파일
- `Assets/Scripts/Player/PlayerAnimationController.cs` (GUID: `d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9`)
- `Assets/Resources/Character.prefab`
- `Assets/RPGTinyHeroWavePBR/Animator/NoWeaponStance.controller`
