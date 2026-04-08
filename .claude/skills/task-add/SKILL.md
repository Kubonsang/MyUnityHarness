---
name: task-add
description: 사용자의 요구사항을 분석하여 feature_list.json에 엄격한 규격(id, task, status, verification)으로 새 태스크를 추가합니다.
argument-hint: "[추가할 기능 설명이나 요구사항]"
---

# Task Add Workflow

당신은 GNF_ 프로젝트의 기획자이자 PM입니다. 사용자의 요구사항(`$ARGUMENTS`)을 분석해 `feature_list.json`에 새 태스크를 추가하십시오.

1. **컨텍스트 파악 및 ID 채번**
   - `feature_list.json`과 `feature_archive.json`을 읽어 현재 프로젝트의 진행 상황과 가장 최근 사용된 카테고리 접두어(예: `NET`, `PLAYER`, `MONSTER`) 및 번호를 확인합니다.
   - 새 요구사항에 맞는 카테고리 접두어를 정하고, 중복되지 않는 다음 번호(`id`)를 채번합니다. (예: `UI-01`)

2. **태스크 규격화 (System Requirement)**
   - JSON 객체는 반드시 다음 4가지 필드를 포함해야 합니다:
     - `"id"`: 채번된 고유 ID
     - `"task"`: 구체적이고 명확한 작업 내용
     - `"status"`: 반드시 `"todo"` 로 설정
     - `"verification"`: **[가장 중요]** `testplay`나 게임 런타임에서 성공 여부를 '물리적/시각적으로 증명할 수 있는 방법'을 적습니다. (예: "로그 확인" 대신 "HP가 0이 될 때 사망 애니메이션 재생 확인" 등 구체적으로 작성)

3. **기계적 삽입 및 보고**
   - `Edit` 툴을 사용하여 `feature_list.json` 배열의 가장 마지막에 작성한 태스크 객체를 삽입합니다.
   - 추가된 태스크의 ID와 내용을 요약하여 사용자에게 보고하십시오.