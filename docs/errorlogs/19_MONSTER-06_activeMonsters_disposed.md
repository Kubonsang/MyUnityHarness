# MONSTER-06 에디터 오류: ObjectDisposedException (Inspector ListView)

## 에러 메시지 (반복 패턴)
```
ObjectDisposedException: SerializedProperty _activeMonsters.Array.data[1] has disappeared!
  UnityEditor.SerializedProperty.SyncSerializedObjectVersion()
  UnityEditor.UIElements.Bindings.BaseListViewSerializedObjectBinding.UpdateArraySize()
  UnityEditor.UIElements.Bindings.BaseListViewSerializedObjectBinding.OnPropertyValueChanged()
  UnityEditor.UIElements.Bindings.SerializedObjectBindingContext.DefaultOnPropertyChange()
  UnityEditor.RetainedMode:UpdateSchedulers()
```

## 근본 원인

**에디터 Inspector UI 문제. 런타임 동작에는 영향 없음.**

1. `List<MonsterFSM>`은 `MonsterFSM : MonoBehaviour` (UnityEngine.Object) 레퍼런스 목록
2. Unity는 `List<UnityEngine.Object>` 타입을 직렬화 가능 타입으로 인식
3. Inspector(특히 Debug 모드)가 `_activeMonsters`에 `SerializedProperty` 바인딩 생성
4. 런타임에 `Unregister()` → `RemoveAt()` 호출 → 리스트 크기 변경
5. Inspector의 UIElements ListView 바인딩이 해당 인덱스 접근 시 `ObjectDisposedException`

## 적용된 수정 (MonsterManager.cs)

```csharp
[System.NonSerialized] // Inspector SerializedProperty 바인딩 방지
private readonly List<MonsterFSM> _activeMonsters = new List<MonsterFSM>();
```

- `[System.NonSerialized]`: Unity 직렬화 시스템에서 이 필드를 명시적으로 제외
- Inspector(Normal/Debug 모드 모두)가 SerializedProperty 바인딩을 생성하지 않음
- 런타임 동작에 영향 없음. 빌드에도 포함되지 않는 메타데이터

## 유사 패턴 참조

- `docs/errorlogs/15_monster04_inspector_missing_reference.md` — Despawn 후 Inspector가 파괴된 컴포넌트를 redraw하는 유사 패턴

## 검증

1. `[System.NonSerialized]` 추가 후 Inspector에서 `_activeMonsters` 미노출 확인
2. 몬스터 사망 → Unregister() 호출 → ObjectDisposedException 미발생 확인
