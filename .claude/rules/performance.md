---
paths:
  - "Assets/Scripts/**/*.cs"
  - "Assets/Runtime/**/*.cs"
---

## Unity Runtime 핫 패스(Hot Path) 엄격 규칙

클로드, 당신이 지금 수정하거나 읽고 있는 파일은 게임의 런타임 성능에 직결되는 C# 스크립트일 수 있습니다. 코드를 수정할 때 다음 런타임 성능 가이드라인을 기계적으로 준수하십시오.

1. **Update 루프 내 무거운 연산 절대 금지**
   - `Update()`, `FixedUpdate()`, `LateUpdate()` 내부에서 `GameObject.Find`, `GetComponent`, `Camera.main` 호출을 절대 금지합니다.
   - 참조는 반드시 `Awake()`나 `Start()`에서 변수에 캐싱해 두고 사용하십시오.

2. **루프 내 메모리 할당(Allocation) 금지**
   - 매 프레임 실행되는 코드 안에서 `new` 키워드를 통한 객체 생성, 빈번한 문자열 결합을 하지 마십시오.
   - 총알, 이펙트 등은 반드시 `UnityEngine.Pool`을 이용한 오브젝트 풀링을 사용하십시오.

3. **최적화 설계가 필요할 경우**
   - 커스텀 Update Manager, 문자열 해싱(StringToHash), ScriptableObject를 이용한 플라이웨이트 패턴 등 구조적인 성능 최적화가 필요하다고 판단되면, `unity-performance` 스킬을 호출하여 심화 매뉴얼을 읽고 적용하십시오.