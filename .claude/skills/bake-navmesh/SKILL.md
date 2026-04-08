---
name: bake-navmesh
description: 씬 구조가 변경되었을 때 백그라운드에서 임시 Editor 스크립트를 사용해 NavMesh를 새로 굽고(Bake) 갱신합니다.
argument-hint: "없음"
---

# NavMesh Baker

1. `Assets/Editor/TempNavMeshBaker.cs` 를 생성합니다.
2. `UnityEditor.AI.NavMeshBuilder.BuildNavMesh()` 를 호출하는 메뉴 아이템이나 초기화 함수를 작성하십시오.
3. `testplay run --shadow` 환경을 통해 해당 빌드 함수를 실행시킵니다.
4. NavMesh 데이터가 새로 생성되거나 업데이트되었음을 확인한 후 임시 스크립트를 정리(rm) 하십시오.