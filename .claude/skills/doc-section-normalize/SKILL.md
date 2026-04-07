---
name: doc-section-normalize
description: Normalize double sharp section headers in GNF_ session docs to the 6 Korean standard headers. Use when creating or fixing session docs under docs/. Do not apply to design docs (01_project_blueprint.md etc) or errorlogs.
argument-hint: "[file path or doc number]"
---

새 세션 문서를 작성하거나 기존 문서의 섹션 헤더를 교정할 때 사용한다.

## 표준 섹션 헤더 (## 레벨)

아래 6개가 GNF_ 프로젝트의 공식 섹션 헤더다.
문서에 해당 내용이 있다면 반드시 이 이름을 사용한다.

| 표준 이름 | 대체해야 할 비표준 변형 예시 |
|-----------|------------------------------|
| `## 세션 목표` | `## Goal`, `## 목표` |
| `## 변경된 파일` | `## Changes Made`, `## Files Changed` |
| `## 핵심 설계` | `## 구현 내용`, `## 구현 상세`, `## 아키텍처 및 흐름`, `## 구현 상세 및 설계` |
| `## 검증 절차` | `## 검증 절차 (사용자 실행)`, `## 검증 절차 (에디터 설정 완료 후)`, `## Verification` |
| `## 주의 사항` | `## ⚠️ 알려진 리스크`, `## ⚠️ 주의사항`, `## 알려진 제약`, `## 리스크`, `## ⚠️ 미해결 이슈 (다음 태스크)`, `## Risks / Unverified` |
| `## 다음 권장 태스크` | `## Next Tracked Task`, `## 다음 태스크` |

## 건드리지 않는 것

- `###` 하위 헤더는 변경하지 않는다.
- `에디터 설정`, `에디터 오류 기록` 등 위 6개에 해당하지 않는 고유 섹션은 그대로 둔다.
- 본문 텍스트 안에 등장하는 섹션 이름 언급은 변경하지 않는다.
- `01_project_blueprint.md`, `20_role_item_skill_design.md` 같은 설계/기획 문서는 세션 문서가 아니므로 적용하지 않는다.

## 표준 문서 구조 (새 문서 작성 시 참고)

```markdown
# NN. TASK-ID: 제목

## 세션 목표
한두 줄로 이 세션이 달성하는 것을 기술.

---

## 변경된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `경로/파일명` | **신규** 또는 변경 내용 요약 |

---

## 핵심 설계

### 소제목
내용.

---

## 에디터 설정       ← 필요한 경우만
내용.

---

## 검증 절차

1. 단계별 확인 항목.
2. ...
3. 완료 → feature_list.json TASK-ID → `done`

---

## 주의 사항        ← 리스크나 미해결 사항이 있는 경우만
- 항목.

---

## 다음 권장 태스크
- **NEXT-ID**: 설명
```

## 적용 방법

대상 파일을 Read → 비표준 `## ` 헤더 식별 → Edit으로 교정.
새 문서 작성 시에는 위 구조를 그대로 사용한다.
