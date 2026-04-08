# 59. WFC-01: Tile.cs isDangerous 플래그 추가

## 세션 목표
`Tile.cs`에 `isDangerous` bool 필드를 추가해 미니맵·UI에서 안전 구역과 위험 구역을 구분할 수 있는 기반을 마련한다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Assets/Scripts/Map/WFC/Tile.cs` | `isDangerous` 필드 추가, `OnValidate()` 자동 설정 로직 추가 |
| `feature_list.json` | WFC-01 status → `done` |

---

## 핵심 설계

### isDangerous 분류 기준

| isDangerous | TileType |
|---|---|
| `true` (위험) | NormalRoom, ObjectiveRoom, Corridor |
| `false` (안전) | StartRoom, SpecialRoom, ExitRoom, Air |

### OnValidate 자동 세팅
```csharp
#if UNITY_EDITOR
private void OnValidate()
{
    isDangerous = tileType == TileType.NormalRoom
               || tileType == TileType.ObjectiveRoom
               || tileType == TileType.Corridor;
}
#endif
```
Inspector에서 `tileType`을 변경하면 `isDangerous`가 자동으로 갱신된다.  
런타임에서는 프리팹에 저장된 값을 그대로 사용하므로 추가 연산 없음.

---

## 검증 절차

1. Unity 에디터에서 Tile 컴포넌트 부착된 프리팹 선택
2. `tileType`을 NormalRoom/ObjectiveRoom/Corridor로 변경 → `isDangerous`가 자동으로 `true` 확인
3. StartRoom/SpecialRoom/ExitRoom/Air로 변경 → `isDangerous`가 자동으로 `false` 확인
4. `unity-cli exec` 논리 검증: 7개 TileType 전부 기대값 일치 확인 (완료)

---

## 주의 사항
- `OnValidate`는 에디터 전용(`#if UNITY_EDITOR`). 런타임에서는 프리팹에 저장된 값을 사용하므로, **프리팹 저장 전 tileType을 올바르게 설정해야** isDangerous 값이 정확하다.
- 기존 프리팹이 있다면 Inspector에서 tileType을 한 번 재선택해 OnValidate를 트리거해야 isDangerous가 갱신된다.

---

## 다음 권장 태스크
- **WFC-02**: WFCGenerator ExitRoom 가장자리 배치 제약 구현
