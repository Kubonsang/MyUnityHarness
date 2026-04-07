---
paths:
  - "Assets/Scripts/**/*.cs"
---

## 🚨 Unity NGO (Netcode) 핵심 보안 및 동기화 규칙

클로드, 당신이 현재 작업 중인 파일은 네트워크 동기화가 포함된 스크립트입니다. 과거에 발생했던 치명적인 동기화 깨짐 현상(예: 클라이언트가 권한 없이 상태를 직접 수정)을 방지하기 위해 다음 원칙을 기계적으로 준수하십시오.

### 1. 절대적인 서버 권한 (Server-Authoritative)
- 이 프로젝트는 철저하게 서버 권한 모델을 따릅니다.
- 서버만이 게임 상태(State)를 결정하는 유일한 진실의 원천(Source of truth)입니다.
- 클라이언트는 절대로 게임의 핵심 상태(HP, 위치, 인벤토리 등)를 직접 변경할 수 없으며, 오직 서버에 액션(요청)만 보내야 합니다. 이후 서버가 요청의 유효성을 검증(Validate)하고 최종 결과를 적용해야 합니다.

### 2. 상태(State)와 이벤트(Event)의 엄격한 분리
동기화하려는 데이터의 성격에 따라 다음을 명확히 구분하여 사용하십시오.
- **NetworkVariable:** 체력, 장착 무기 등 '지속적으로 유지되고 동기화되어야 하는 상태(Persistent synchronized state)'에만 사용하십시오. 네트워크 대역폭 낭비를 막기 위해 불필요하게 쓰기 빈도를 높이지 마십시오.
- **RPC (Remote Procedure Call):** 데미지 발생 알림, 스킬 이펙트 재생 등 '일회성 이벤트나 요청(One-time events or requests)'에만 사용하십시오. RPC를 상태 동기화 목적으로 남용해서는 절대 안 됩니다.

### 3. 클라이언트 측 예측 (Client-Side Prediction) 주의
- 예측 상태와 서버 상태를 하나의 변수에 섞어 쓰지 마십시오.
  ```csharp
  public NetworkVariable<Vector3> ServerPosition = new NetworkVariable<Vector3>();
  private Vector3 _predictedPosition;
  ```

### 4. 심화 지식 참조
- 복잡한 네트워크 패턴 설계가 필요하다면 `unity-ngo` 스킬을 호출하여 상세 매뉴얼을 읽고 적용하십시오.

## NGO 동기화 테스트 규칙
넷코드(NetworkVariable, Rpc 등) 관련 로직을 수정했다면, 반드시 `--scenario` 모드를 사용하여 호스트와 클라이언트 환경이 모두 정상 작동하는지 증명해야 합니다.

1. `testplay.scenario.json` (예시) 파일 구성:
   ```json
   {
     "schema_version": "1",
     "instances": [
       {"role": "host", "config": "testplay.json", "ready_phase": "running"},
       {"role": "client", "config": "testplay.json", "depends_on": "host"}
     ]
   }
   ```
2. `testplay run --scenario testplay.scenario.json`을 실행하여 두 인스턴스의 Exit Code가 모두 0인지 확인하십시오.