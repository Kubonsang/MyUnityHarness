# 38. NET-04: NetworkConnectionLogger Awake()→Start() 타이밍 보정

## 세션 목표
`Awake()`에서 `NetworkManager.Singleton`을 읽는 패턴을 `Start()`로 이전해 Script Execution Order에 따른 `null` 접근 가능성을 제거한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Network/NetworkConnectionLogger.cs` | `Awake()` → `Start()`로 변경, null 분기에 `LogWarning` 추가 |

---

## 핵심 설계

### 문제
`NetworkManager.Singleton`은 `Awake()` 순서가 보장되지 않으면 `null`이 될 수 있다.
기존 코드는 `!= null` 가드 덕분에 크래시는 없지만 `MaxPacketQueueSize = 512` 설정이 조용히 무시될 수 있었다.

### 수정
```csharp
// Before
private void Awake() { ... }

// After
private void Start()
{
    // Start()에서 접근 — Awake() 시점에는 NetworkManager.Singleton이 null일 수 있음
    if (NetworkManager.Singleton != null && ...)
    {
        transport.MaxPacketQueueSize = 512;
        Debug.Log(...);
    }
    else
    {
        Debug.LogWarning("[NetworkConnectionLogger] NetworkManager.Singleton이 Start() 시점에 null — MaxPacketQueueSize 설정 건너뜀");
    }
}
```

### 선택 이유
- `Start()`는 씬 내 모든 오브젝트의 `Awake()`가 완료된 후 호출 → `NetworkManager.Singleton` 초기화 보장.
- `LogWarning` 추가: null인 경우 설정 누락 여부를 콘솔에서 즉시 파악 가능.
- 코드 변경량 최소 (메서드명 + warning 분기 1개).

---

## 검증 절차

1. Unity 에디터에서 Play Mode 진입 (Host 실행)
2. Console에 `[NetworkConfig] MaxPacketQueueSize increased to 512` 로그 출력 확인
3. `LogWarning` 로그가 없으면 설정 정상 적용
4. 완료 → `feature_list.json` NET-04 → `done`

---

## 주의 사항
- `NetworkManager` 오브젝트가 이 컴포넌트보다 훨씬 늦게 초기화되는 구조라면 (예: Additive Scene 로드) `Start()`도 null일 수 있음. 현재 씬 구조(동일 씬)에서는 문제없음.

---

## 다음 권장 태스크
- **ITEM-05**: `PlayerInventory` 캐싱 누락 수정 (`_roleStatModifier` Awake 캐싱, `_ownerRpcParams` OnNetworkSpawn 캐싱)
- **ITEM-06**: `_slots.OnListChanged` 구독 등록 및 초기 슬롯 순회 스텁 추가
