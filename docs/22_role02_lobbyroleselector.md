# 22. ROLE-02: LobbyRoleSelector

## 세션 목표
클라이언트가 역할을 요청하면 서버가 중복 검증 후 저장하고 결과를 통보하는
서버 권위 역할 선택 시스템 구현.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Role/LobbyRoleSelector.cs` | **신규**. 서버 권위 역할 선택 NetworkBehaviour |
| `feature_list.json` | ROLE-02 → `in_progress` |

---

## 핵심 설계

### 역할 선택 흐름

```
클라이언트.SelectRoleServerRpc(roleTypeIndex)
    └─ 서버: None 요청 차단
    └─ 서버: RoleData 존재 확인 (_availableRoles 미연결 방어)
    └─ 서버: 타 클라이언트 중복 검증 (본인 제외 foreach)
    └─ 서버: _selectedRoles[callerId] = requested
    └─ 서버: NotifySelectionClientRpc(전체 브로드캐스트) → UI 갱신용
    └─ 실패 시: SelectRoleFailedClientRpc(요청자만 타겟 전송)
```

### RequireOwnership = false

`LobbyRoleSelector`는 씬 오브젝트이므로 클라이언트가 소유하지 않음.
`ServerRpcParams`로 실제 호출자 clientId를 안전하게 수신.

### 중복 검증 — ContainsValue 대신 foreach

본인 제외 필터를 명시적으로 적용.
같은 클라이언트가 역할을 교체할 때 자신의 기존 선택이 중복으로 걸리지 않음.

### 실패 알림 타겟 ClientRpc

`ClientRpcParams.Send.TargetClientIds`로 실패한 클라이언트에만 전송.
전체 브로드캐스트 후 필터링보다 불필요한 RPC 트래픽 제거.

### 연결 해제 시 역할 해제

`NetworkManager.OnClientDisconnectCallback`에서 `_selectedRoles.Remove(clientId)`.
해제하지 않으면 해당 역할이 영구 잠금되어 다른 클라이언트가 선택 불가.

### static Instance

ROLE-03의 `PlayerRoleHandler.OnNetworkSpawn`에서
`LobbyRoleSelector.Instance.GetRoleData(clientId)`로 조회.
`FindObjectOfType` 대신 O(1) 접근 (MonsterManager.Instance 패턴과 동일).

---

## 에디터 설정

```
씬 Hierarchy:
└── LobbyRoleSelector (GameObject)
    ├── NetworkObject (컴포넌트)  ← 필수
    └── LobbyRoleSelector (컴포넌트)
          _availableRoles: [TankRoleData, DPSRoleData, HealerRoleData]
```

---

## 검증 절차

### 씬 사전 설정 (최초 1회)
1. 테스트 씬 Hierarchy에 빈 GameObject 추가 → 이름 `LobbyRoleSelector`
2. NetworkObject 컴포넌트 추가
3. LobbyRoleSelector 컴포넌트 추가
4. `_availableRoles` 배열 Size=3, Tank / DPS / Healer RoleData 에셋 연결

### 런타임 검증 (키보드 디버그 입력 사용)
5. Host 시작 → **1** 키 → 콘솔 `[LobbyRoleSelector] Client 0 → Tank` 확인
6. Client 연결 → **2** 키 → 콘솔 `Client 1 → DPS` 확인
7. Client에서 **1** 키 (Tank 중복 시도) → `Selection failed: Tank is already taken.` 경고 확인
8. Client 연결 해제 → Host에서 **2** 키 (DPS 재선택 가능) 확인
9. 완료 → feature_list.json ROLE-02 → `done`

---

## 주의 사항

- UI 연동 없음. `NotifySelectionClientRpc` / `SelectRoleFailedClientRpc` 내 이벤트 연결은 UI 시스템 구현 시 추가.
- `_availableRoles` 미연결 시 "Role data not found." 경고로 방어 처리됨.

---

## 다음 권장 태스크
- **ROLE-03**: PlayerSetup — 스폰 시 RoleData로 HP + 이동속도 보정 (PlayerRoleHandler 구현)
