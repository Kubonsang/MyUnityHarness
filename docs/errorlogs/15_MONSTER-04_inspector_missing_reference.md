# MONSTER-04 에디터 오류: MissingReferenceException (InspectorWindow)

## 에러 메시지 (반복 패턴)
```
MissingReferenceException: The object of type 'NetworkObject' has been destroyed
  but you are still trying to access it.
  UnityEngine.Behaviour.get_enabled ()
  UnityEditor.EditorGUI.DoInspectorTitlebar (...)
  UnityEditor.InspectorWindow:RedrawFromNative()

동일 패턴: MonsterHealth, MonsterAnimationController, MonsterFSM 각각 동일 에러
```

## 근본 원인

**에디터 Inspector UI 문제. 런타임 동작에는 영향 없음.**

1. 몬스터 오브젝트가 Hierarchy에서 선택된 채로 플레이 중
2. HP → 0 → `HandleDeath()` → `NetworkObject.Despawn(false)`
3. NGO가 in-scene placed NetworkObject를 내부적으로 `Destroy()` 처리 (destroy 파라미터와 무관하게)
4. Unity Inspector가 이전 선택을 유지하며 파괴된 컴포넌트를 redraw 시도
5. `Behaviour.get_enabled()` 호출 시 `MissingReferenceException` 발생

## 적용된 수정 (MonsterHealth.cs — HandleDeath)

```csharp
private void HandleDeath()
{
#if UNITY_EDITOR
    // Inspector가 파괴된 컴포넌트를 redraw하려는 MissingReferenceException 방지.
    if (UnityEditor.Selection.activeGameObject == gameObject)
        UnityEditor.Selection.activeGameObject = null;
#endif
    NetworkObject.Despawn(false);
}
```

- `#if UNITY_EDITOR`: 빌드에 포함되지 않음. 순수 에디터 편의 코드
- Despawn 직전에 Inspector 선택 해제 → 에디터가 redraw 시 null 참조 발생 없음

## 검증

1. 몬스터 Hierarchy 선택 상태에서 HP → 0 발생
2. Inspector 선택이 자동으로 해제되는 것 확인
3. MissingReferenceException 미발생 확인

## 현재 상태
- MONSTER-04: `in_progress` → 게임플레이 검증 완료, 에디터 에러 수정 후 재확인 필요
