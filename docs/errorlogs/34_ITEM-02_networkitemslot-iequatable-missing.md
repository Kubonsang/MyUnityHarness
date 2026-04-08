# 34_ITEM-02: NetworkItemSlot IEquatable 미구현 컴파일 오류

## 증상

```
Assets/Scripts/Item/PlayerInventory.cs(24,51): error CS0315:
The type 'NetworkItemSlot' cannot be used as type parameter 'T'
in the generic type or method 'NetworkList<T>'.
There is no boxing conversion from 'NetworkItemSlot' to
'System.IEquatable<NetworkItemSlot>'.
```

## Root Cause

NGO `NetworkList<T>`의 제네릭 제약은 `T : INetworkSerializable, IEquatable<T>` 두 가지를 모두 요구한다.
`NetworkItemSlot` 생성 시 `INetworkSerializable`만 구현하고 `IEquatable<NetworkItemSlot>`을 누락했다.

## 수정 내용

`Assets/Scripts/Item/NetworkItemSlot.cs`:

```csharp
// 변경 전
public struct NetworkItemSlot : INetworkSerializable

// 변경 후
public struct NetworkItemSlot : INetworkSerializable, IEquatable<NetworkItemSlot>
```

`Equals` / `GetHashCode` 추가:

```csharp
public bool Equals(NetworkItemSlot other) => ItemId == other.ItemId;
public override int GetHashCode() => ItemId;
```

## 2차 오류 (연쇄)

```
Assets/Scripts/Item/NetworkItemSlot.cs(7,55): error CS0246:
The type or namespace name 'IEquatable<>' could not be found
(are you missing a using directive or an assembly reference?)
```

`IEquatable<>`은 `System` 네임스페이스에 속한다. `using System;`이 없어 타입을 찾지 못함.
Burst 컴파일러의 `Assembly-CSharp-Editor` 해석 실패는 C# 컴파일 오류의 연쇄 오류로 독립적 버그가 아니다.

추가 수정: `using System;` 삽입.

## 검증 결과

컴파일 오류 해소 예상. Unity 에디터 재컴파일 필요.
