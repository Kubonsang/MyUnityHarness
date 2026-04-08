---
name: generate-scriptable-object
description: GUID 충돌 위험 없이, 임시 Editor C# 스크립트와 testplay-runner를 활용해 완벽하게 유효한 ScriptableObject 에셋을 안전하게 생성합니다.
argument-hint: "[클래스명] [생성할 경로 및 파일명.asset]"
---

# Scriptable Object Generator

단순히 `.asset` 텍스트 파일을 만들면 GUID가 꼬이거나 메타데이터가 깨집니다. 반드시 다음 절차로 생성하십시오.

1. `Assets/Editor/TempSOGenerator.cs` 파일을 생성하고 다음 로직을 작성합니다.
   - `AssetDatabase.CreateAsset(ScriptableObject.CreateInstance<클래스명>(), "경로");`
   - `AssetDatabase.SaveAssets();`
2. `testplay run --shadow` (또는 에디터 리프레시 명령어)를 실행하여 Unity 컴파일러가 위 코드를 실행하도록 트리거합니다.
3. 생성이 완료된 것을 확인하면 `TempSOGenerator.cs` 와 `.meta` 파일을 즉시 삭제(rm) 하십시오.