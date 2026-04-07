---
name: unity-performance
description: Unity 런타임 성능 최적화가 필요하거나, Update 루프 내의 게임플레이 핫 패스(Hot Path) 코드를 작성/수정할 때 참고하는 스킬입니다.
---

## Unity Runtime Performance 가이드라인

게임의 핵심 프레임 루프(`Update`, `FixedUpdate`, `LateUpdate`) 내에서의 연산 지연은 프로젝트에 치명적입니다. 코드를 작성하기 전, 반드시 엔진의 수명 주기를 명확히 이해하고 아래의 원칙을 기계적으로 준수하십시오.

### 1. 매 프레임 연산 최소화 및 타임 슬라이싱 (Time Slicing)
- 프레임 루프 내부에서 무거운 연산은 절대 수행하지 마십시오.
- 매 프레임마다 실행될 필요가 없는 로직인지 우선 고민하고, 불필요한 로직은 `Update` 계열 외부로 분리해야 합니다.
- 불가피하게 무거운 연산이 필요하다면, 작업을 여러 프레임으로 분산시켜 처리하는 **타임 슬라이싱(Time Slicing)** 기법을 적용하여 CPU 스파이크를 방지하세요.

### 2. 무거운 함수의 결과 캐싱 (Caching)
- `GetComponent`, `Camera.main`과 같이 탐색 비용이 큰 함수를 `Update` 메서드 내부에서 반복 호출하는 것은 심각한 프레임 드랍을 유발합니다.
- 반드시 `Awake`나 `Start` 수명 주기 단계에서 단 한 번만 호출하여 참조를 변수에 캐싱하고, 이후에는 해당 변수만 재사용하도록 코딩하십시오.

### 3. 커스텀 Update Manager 구축
- 수천 개의 객체에서 단순히 조건 충족 여부만 검사하기 위해 개별 객체의 `Update`를 활성화하면, C/C++ 기반의 Unity 엔진 코어와 C# 스크립트 환경 간의 인터롭(Interop) 호출 오버헤드가 막대하게 발생합니다.
- 콜백이 필요할 때만 객체를 구독(Subscribe)시키고 필요 없을 때 취소(Unsubscribe)하는 **커스텀 Update Manager (Observer 패턴 기반)**를 구현하여 불필요한 엔진 호출 비용을 제거하십시오.

### 4. 문자열 대신 해시(Hash) 값 사용
- 루프 내부에서 잦은 문자열 결합이나 탐색을 피하십시오.
- 특히 `Animator`, `Material`, `Shader` 등의 속성에 접근할 때 문자열(String)을 그대로 넘기면 내부적으로 매번 해싱(Hashing) 연산이 발생합니다.
- 초기화 시점에 `Animator.StringToHash`나 `Shader.PropertyToID`를 사용해 정수형 해시값을 미리 구하고, 이를 캐싱해 두었다가 재사용하십시오.

### 5. 오브젝트 풀링 (Object Pooling) 적극 활용
- 루프 내에서 `new`를 통한 반복적인 메모리 할당이나 `Instantiate` / `Destroy`의 잦은 호출은 가비지 컬렉터(GC)를 자극하여 게임을 멈칫거리게 만듭니다.
- 총알, 이펙트 등 자주 생성되고 파괴되는 객체는 미리 생성해 풀(Pool)에 보관하고 꺼내 쓰는 **오브젝트 풀링** 패턴을 적용하세요. 
- Unity 2021 LTS 버전부터 내장된 `UnityEngine.Pool` 네임스페이스를 적극 활용하십시오.

### 6. 디버그 로그의 조건부 비활성화
- `Debug.Log` 등 런타임 플로우에 섞여 있는 로깅 함수는 릴리스 빌드의 성능을 크게 저하시킵니다.
- 작업 완료 후에는 임시 로그를 제거하거나, `[System.Diagnostics.Conditional]` 속성 및 전처리기 지시어(`#if UNITY_EDITOR` 등)를 사용하여 빌드 시 모든 로그 호출과 스택 트레이스 수집이 완전히 제외되도록 클래스를 구성하십시오.

### 7. ScriptableObject를 활용한 데이터 중복 방지 (Flyweight 패턴)
- 여러 `GameObject`가 동일하게 공유하는 불변(Immutable) 설정값이 있다면, 개별 `MonoBehaviour`마다 중복해서 들고 있어 메모리를 낭비하지 마십시오.
- 대신 해당 데이터를 `ScriptableObject` 에셋으로 단 한 번만 생성해두고, 각 객체가 이를 참조 공유하는 **플라이웨이트(Flyweight) 패턴** 구조로 설계하십시오.
