#!/bin/bash
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# git commit 명령어를 실행하려고 할 때만 개입
if [[ "$COMMAND" =~ "git commit" ]]; then
    
    # 정규식: (feat|fix|docs|style|refactor|test|chore): \[태스크ID\] 메시지
    # 예: feat: [ROOM-01] Added boss room
    if ! echo "$COMMAND" | grep -qE "git commit.*-m.*(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: \[.*\]"; then
        echo "❌ [System Reject] 커밋 메시지가 시스템 규격(Conventional Commits + Task ID)에 맞지 않습니다." >&2
        echo "올바른 포맷 예시: git commit -m \"feat: [ROOM-01] 작업 내용 요약\"" >&2
        echo "타입(feat, fix 등)과 대괄호로 묶인 [태스크ID]가 반드시 포함되어야 합니다. 명령어를 수정하여 다시 실행하십시오." >&2
        exit 1
    fi
fi
exit 0