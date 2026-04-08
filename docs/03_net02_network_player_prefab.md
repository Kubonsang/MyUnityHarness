# 03. NET-02: NetworkPlayer 프리팹 생성

## 세션 목표
기존 `PlayerPrefab`의 클라이언트 권위 스크립트를 서버 권위 구조로 교체.
`feature_list.json` NET-02 완료.

---

## 파악된 현황 (Inspect 결과)

### PlayerPrefab 기존 컴포넌트 (변경 전)
| 컴포넌트 | GUID | 문제 |
|---------|------|------|
| NetworkObject | `d5a57f767e5e46a458fc5d3c628d0cbb` | - |
| **ClientNetworkTransform** | `da52bf8bbc1de48cfb221a6ff30f7972` | CLAUDE.md 위반: 클라이언트 권위 |
| **ClientAuthoritativeMovement** | `455521db0066b4b4280c34d2fdba6763` | CLAUDE.md 위반: 직접 transform 수정 |
| SetColorBasedOnOwnerId | `ac35373b42abe46ea8f7cab1a1c353f0` | - |

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Network/NetworkPlayer.cs` | 신규 생성 |
| `Assets/Scripts/Network/NetworkPlayer.cs.meta` | 신규 생성 (GUID: `3a7f2d1c8e4b5f6a9c0d2e3b4f5a6c7d`) |
| `Assets/NGO_Minimal_Setup/PlayerPrefab.prefab` | 컴포넌트 교체/제거/추가 |
| `feature_list.json` | NET-02 → `in_progress` |

---

## 핵심 설계

### 1. NetworkPlayer.cs
`Assets/Scripts/Network/NetworkPlayer.cs`

PLAYER-01에서 이동 로직이 추가될 기반 컴포넌트.

```csharp
using Unity.Netcode;
using UnityEngine;

[RequireComponent(typeof(NetworkObject))]
public class NetworkPlayer : NetworkBehaviour
{
    public override void OnNetworkSpawn()
    {
        Debug.Log($"[NetworkPlayer] Spawned — IsOwner: {IsOwner}, IsServer: {IsServer}, ClientId: {OwnerClientId}");
    }
}
```

### 2. PlayerPrefab.prefab 변경 내용

| 처리 | 컴포넌트 | 이유 |
|------|---------|------|
| **교체** | ClientNetworkTransform → NetworkTransform | 서버 권위 보장 |
| **제거** | ClientAuthoritativeMovement | 직접 transform 수정 금지 (이동 로직은 PLAYER-01) |
| **추가** | NetworkPlayer | 스폰 로그 및 PLAYER-01 기반 |

**교체 후 컴포넌트 목록:**
- Transform, MeshFilter, BoxCollider, MeshRenderer (유지)
- NetworkObject (유지)
- **NetworkTransform** (서버 권위, `AuthorityMode: 0` = Server)
- SetColorBasedOnOwnerId (유지)
- **NetworkPlayer** (신규)

---

## 이 접근법을 선택한 이유
- `ClientNetworkTransform`은 `OnIsServerAuthoritative()` = false → 서버 권위 위반
- `ClientAuthoritativeMovement`는 클라이언트가 직접 `transform.position` 수정 → 치팅 취약
- `NetworkTransform` 기본값은 `OnIsServerAuthoritative()` = true → CLAUDE.md 준수
- PLAYER-01 전까지 이동 로직이 없으므로 `NetworkPlayer`는 스폰 로그만 포함 (YAGNI)

---

## 검증 절차
1. Unity 에디터에서 `Assets/NGO_Minimal_Setup/NGO_Setup.unity` 열기
2. 에디터가 `NetworkPlayer` 스크립트를 reimport — **Console 에러 없음** 확인
3. `PlayerPrefab` Inspector에서 NetworkTransform, NetworkPlayer 컴포넌트 표시 확인
4. Play 모드 → **Start Host** 클릭
5. Console: `[NetworkPlayer] Spawned — IsOwner: True, IsServer: True, ClientId: 0` 확인
6. ParrelSync 또는 빌드로 두 번째 인스턴스 → **Start Client** 클릭
7. Host Console: `[Server] Client 1 connected.` (NET-01 로그)
8. Client Console: `[NetworkPlayer] Spawned — IsOwner: False, IsServer: False, ClientId: 0` 확인
9. 두 화면에서 Cube가 같은 위치에 스폰됨 확인
10. 검증 완료 후 `feature_list.json` NET-01, NET-02 → `done`

---

## 주의 사항

**NetworkPlayer.cs.meta GUID 충돌 가능성:**
- `Assets/Scripts/Network/NetworkPlayer.cs.meta`의 GUID를 수동으로 `3a7f2d1c8e4b5f6a9c0d2e3b4f5a6c7d`로 지정
- Unity 에디터가 파일을 reimport할 때 이 GUID를 유지하면 정상
- 만약 에디터가 다른 GUID를 할당하면 PlayerPrefab의 NetworkPlayer 컴포넌트가 **Missing Script**로 표시됨
- **해결**: Inspector에서 Missing Script 슬롯에 NetworkPlayer 스크립트를 수동으로 재할당 후 저장

---

## 다음 권장 태스크
**PLAYER-01**: PlayerController (이동, CharacterController + NetworkTransform, 서버 권위)
- 로컬 플레이어만 입력 수신
- 이동 결과를 서버에서 처리 → 모든 클라이언트 동기화
- Input System과 연동 (PLAYER-02 준비)
