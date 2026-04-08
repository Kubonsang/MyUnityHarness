
## Component Dependency Rule

유니티 환경에서 컴포넌트 간의 결합도를 안전하게 관리하기 위한 강제 규칙입니다.

1. **RequireComponent 강제:** 스크립트 내부에서 `GetComponent<TargetType>()`을 호출해야만 정상 작동하는 클래스라면, 클래스 선언부 상단에 반드시 `[RequireComponent(typeof(TargetType))]` 어트리뷰트를 명시하십시오. 이는 런타임 NullReferenceException을 구조적으로 방지합니다.
2. **안전한 참조 캐싱:** 빈번하게 접근하는 컴포넌트는 `Update()` 내부가 아닌 `Awake()`나 `Start()`에서 캐싱하여 사용해야 합니다.