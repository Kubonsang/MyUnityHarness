# 02. NET-01: NetworkManager 씬 설정

## 세션 목표
NGO_Setup.unity 씬에서 NetworkManager를 기반으로 Host/Client 연결 기반 구축.
`feature_list.json` NET-01 완료.

---

## 파악된 현황 (Inspect 결과)

### NGO_Setup.unity 기존 구성
| 구성 요소 | 내용 |
|-----------|------|
| `NetworkManager` | UnityTransport, 127.0.0.1:7777, TickRate 30, EnableNetworkLogs: 1 |
| `PlayerPrefab` | `NGO_Minimal_Setup/PlayerPrefab.prefab` — NetworkObject 포함 |
| `NetworkPrefabsList` | PlayerPrefab 등록됨 |
| `TemporaryUI` | `Start Host` / `Start Client` 버튼 (패키지 스크립트 `TemporaryUI.cs`) |

→ **NetworkManager 씬 설정은 이미 완료된 상태였음.**

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Network/NetworkConnectionLogger.cs` | 신규 생성 |
| `feature_list.json` | NET-01 → `in_progress` |

---

## 핵심 설계

### NetworkConnectionLogger.cs
`Assets/Scripts/Network/NetworkConnectionLogger.cs`

NetworkManager 콜백을 구독해 연결 이벤트를 명시적으로 콘솔에 출력.

| 이벤트 | 로그 |
|--------|------|
| `OnServerStarted` | `[Host] Server started.` |
| `OnClientConnectedCallback` (서버 측) | `[Server] Client {id} connected.` |
| `OnClientDisconnectCallback` (서버 측) | `[Server] Client {id} disconnected.` |
| `OnConnectionEvent` (클라이언트 측) | `[Client] Connected to server. Local client ID: {id}` |

**패턴**: MonoBehaviour + OnEnable/OnDisable에서 구독/해제 (메모리 누수 방지)

---

## 이 접근법을 선택한 이유
- NetworkManager는 NGO_Setup.unity에 이미 올바르게 구성됨 → 재작성 불필요 (Minimal change)
- 기존 TemporaryUI 패키지 스크립트 수정 금지 → 별도 컴포넌트 추가
- verification 기준인 "양측 콘솔에 연결 로그 출력"을 명시적으로 충족

---

## 검증 절차
1. Unity 에디터에서 `Assets/NGO_Minimal_Setup/NGO_Setup.unity` 열기
2. `NetworkManager` 오브젝트에 `NetworkConnectionLogger` 컴포넌트 추가
3. Play 모드 → **Start Host** 클릭
4. Console: `[Host] Server started.` 확인
5. ParrelSync 또는 빌드로 두 번째 인스턴스 실행 → **Start Client** 클릭
6. Host Console: `[Server] Client 1 connected.` 확인
7. Client Console: `[Client] Connected to server. Local client ID: 1` 확인
8. 검증 완료 후 `feature_list.json` NET-01 → `done`

---

## 주의 사항

**NET-02에서 반드시 해결 필요:**
기존 `PlayerPrefab`이 사용하는 패키지 스크립트:
- `ClientNetworkTransform.cs` — 클라이언트 권위 (`OnIsServerAuthoritative() = false`)
- `ClientAuthoritativeMovement.cs` — 직접 `transform.position` 수정 (클라이언트 권위)

이는 CLAUDE.md의 **Server Authority 원칙 위반**.
NET-02에서 서버 권위 기반 `NetworkPlayer` 프리팹으로 교체 예정.

---

## 다음 권장 태스크
**NET-02**: NetworkPlayer 프리팹 (NetworkObject + 서버 권위 NetworkTransform) 생성
- 클라이언트 권위 스크립트 제거
- 서버 권위 `NetworkTransform` (기본 `OnIsServerAuthoritative() = true`) 사용
- NetworkManager PlayerPrefab 교체
