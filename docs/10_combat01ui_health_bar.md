# 10. COMBAT-01-UI: WorldSpace HP 바

## 세션 목표
`PlayerHealth.OnHpChanged` 이벤트를 구독해 모든 클라이언트 화면에 HP 수치를 반영하는 WorldSpace UI 구현.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/UI/PlayerHealthBar.cs` | 수정. Canvas/Image를 코드로 자동 생성 (에디터 Canvas 설정 불필요). `BuildBar()` 신규 추가 |
| `feature_list.json` | COMBAT-01-UI → `in_progress` |

> **에디터 필수 작업**: Character.prefab 루트에 `PlayerHealthBar` 컴포넌트 추가만 하면 됨. Canvas 수동 생성 불필요.

---

## WorldSpace Canvas 수동 설정이 안 되는 이유 (2026-03-10 수정 배경)

Unity WorldSpace Canvas는 Transform.localScale = (1,1,1) 상태에서 RectTransform.sizeDelta (기본 800×600 px)가 **월드 단위 800m × 600m**로 렌더링됨.
카메라 클리핑 또는 화면 외부에 위치해 UI가 보이지 않음.

**수정 방향**: `BuildBar()`에서 `localScale = (0.01, 0.01, 0.01)` + `sizeDelta = (barWidth/0.01, 18)` 으로 자동 설정.
1 world unit = 100px @ scale 0.01 → `_barWidth = 1.0m`이면 Canvas = 100px 너비.

---

## 핵심 설계

### 동작 흐름
```
[Server] PlayerHealth.ApplyDamage()
    → _currentHp(NetworkVariable) 갱신
         ↓ OnValueChanged (모든 클라이언트)
[모든 클라이언트] OnCurrentHpChanged → OnHpChanged.Invoke(current, max)
    → PlayerHealthBar.UpdateUI(current, max)
        → _hpSlider.value = current / max
        → _hpLabel.text = "70 / 100"  (할당 시)
```

### Billboard
```csharp
private void LateUpdate()
    => transform.forward = _mainCamera.transform.forward;
```
- Camera.main을 Start()에서 캐싱 (Update 내 반복 조회 방지)
- `transform.forward = camera.forward` — 카메라 뷰 평면에 수직으로 고정

### 초기값 동기화
- `Start()`에서 즉시 `UpdateUI(_health.CurrentHp, _health.MaxHp)` 호출
- `PlayerHealth.OnNetworkSpawn()` 이후 `OnHpChanged` 발생 시 자동 갱신

---

## 에디터 설정 절차

```
Character.prefab 열기
└── 자식 오브젝트 추가: "HealthBarCanvas"
    Component: Canvas
      Render Mode: World Space
      Width: 1 / Height: 0.15 (단위: 미터, 추후 조정)

    └── 자식: "HpSlider"
        Component: Slider
          Min: 0 / Max: 1 / Value: 1
          Interactable: ✗ (비활성)
          Fill Area > Fill: Image (원하는 색상)

    └── (선택) 자식: "HpLabel"
        Component: TextMeshPro - Text (UI)
          Text: "100 / 100"
          Alignment: Center

└── 자식 오브젝트 추가: "HealthBarPanel" (또는 HealthBarCanvas에 직접)
    Component: PlayerHealthBar
      _hpSlider: HpSlider 할당
      _hpLabel: HpLabel 할당 (선택)

HealthBarCanvas 위치: Character 머리 위 (예: Y = 2.2)
```

> **주의**: Canvas의 `Event Camera` 필드는 Runtime에 자동 할당되므로 비워도 됨.

---

## 검증 절차
1. 에디터 설정 완료 후 NGO_Setup.unity → Play → Host 시작
2. Inspector에서 `PlayerHealth._currentHp` 확인 (100)
3. ContextMenu "Apply 10 Damage" → HP 바 90/100으로 줄어드는지 확인
4. ParrelSync Client → 동일 HP 바 값 동기화 확인
5. HP 0 → 오브젝트 Despawn + HP 바 소멸 확인
6. 완료 → feature_list.json COMBAT-01-UI → `done`

---

## 주의 사항

| 항목 | 내용 |
|------|------|
| 에디터 설정 필수 | 스크립트만으로는 동작 불가. WorldSpace Canvas + Slider를 직접 추가해야 함 |
| `_health == null` | `PlayerHealth` 컴포넌트가 prefab에 없으면 Start()에서 early return. HP 바 미표시 |
| `Camera.main` null | Cinemachine 초기화 전 Start()가 실행되는 경우 `_mainCamera` null. LateUpdate에서 `if (_mainCamera != null)` 가드로 방어 |
| 자신 HP 바 표시 | 로컬 플레이어 자신의 HP 바도 WorldSpace로 표시됨. HUD로 분리하려면 추가 로직 필요 |

---

## 다음 권장 태스크
- **COMBAT-02** 검증 (Character.prefab에 PlayerCombat 추가)
- **ROLE-01**: 4가지 캐릭터 역할 인터페이스 정의
