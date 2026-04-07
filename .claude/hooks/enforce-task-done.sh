#!/bin/bash
set -euo pipefail

INPUT=$(cat)
TARGET_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$TARGET_FILE" =~ "feature_list.json" ]]; then
    NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    
    if echo "$NEW_CONTENT" | grep -q '"status": "done"'; then
        if ! find .testplay/runs -type f -name "stdout.log" -mmin -5 -exec grep -q '"exit_code": 0' {} +; then
            echo "❌ [System Reject] 최근 5분 내 성공한 testplay (Exit 0) 증거가 없습니다." >&2
            echo "테스트를 통과하지 않은 상태에서 'done' 처리는 시스템에 의해 강제 차단됩니다." >&2
            exit 1
        fi
    fi
fi
exit 0