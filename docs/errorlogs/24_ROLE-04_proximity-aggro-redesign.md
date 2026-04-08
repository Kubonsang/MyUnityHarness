# ROLE-04: proximity aggro 누적 방식 → 거리 보정치(snapshot) 방식으로 재설계

## 증상
이전 수정(Mathf.Max(1f, dist))으로도 proximity aggro 누적이 계속되어
장시간 근거리에 있는 플레이어가 데미지 어그로를 압도하는 구조적 문제 잔존.

## Root Cause
proximity aggro를 매 틱 `_aggroTable`에 더하는 누적 방식은
시간이 지날수록 근거리 플레이어 어그로가 무한정 증가하는 구조.
데미지 어그로와 근접 어그로가 같은 버킷에 섞여 분리가 불가능.

## 수정 내용
`Assets/Scripts/Monster/AggroSystem.cs` 전면 재설계.

**변경 전**: 근접 어그로를 `_aggroTable`에 누적 (시간 × 거리 반비례)
**변경 후**: 근접 보정치(`_proximityModifier`)를 별도 딕셔너리로 분리, 매 틱 현재 거리로 덮어씀

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 근접 어그로 방식 | 누적 (쌓임) | snapshot (현재 거리만 반영) |
| 공식 | `+= proximityPerSec / dist × dt` | `= proximityAggro × (1 - dist/range)` |
| 저장소 | `_aggroTable` (데미지와 혼합) | `_proximityModifier` (분리) |
| 유효 어그로 계산 | `_aggroTable[id]` | `_aggroTable[id] + _proximityModifier[id]` |
| Inspector 필드 | `_proximityAggroPerSecond` | `_proximityAggro` (최댓값, 기본 5f) |

## 검증 결과
재검증 필요 (ROLE-04 status → in_progress 유지).
Tank 공격 1회(30 aggro) 시, DPS가 0m에 있어도 proximity bonus는 최대 5.
Tank 어그로(30) > DPS 유효 어그로(0 + 5 = 5) → 즉각 타겟 전환 예상.
