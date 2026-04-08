# 에러로그: PLAYER-01 CS0246 InputSystem_Actions

## 에러
```
Assets/Scripts/Player/PlayerController.cs(27,13): error CS0246:
The type or namespace name 'InputSystem_Actions' could not be found
(are you missing a using directive or an assembly reference?)
```

## 원인
`Assets/InputSystem_Actions.inputactions.meta`의 `generateWrapperCode: 0`으로
C# 클래스 자동 생성이 비활성화된 상태였음.
`InputSystem_Actions` C# 래퍼 파일이 존재하지 않아 컴파일 실패.

## 수정 내용
`Assets/InputSystem_Actions.inputactions.meta`
```
generateWrapperCode: 0  →  generateWrapperCode: 1
```
1줄 변경. PlayerController.cs 수정 없음.

## 검증
Unity 에디터가 `.inputactions` 파일을 reimport하면 `Assets/InputSystem_Actions.cs`가 자동 생성됨.
이후 PlayerController.cs 컴파일 에러 해소 확인.

## 상태
PLAYER-01 → `test_failure` (에디터 reimport 후 재확인 필요)
