#!/bin/bash
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Assets 폴더 내에서 파일 이동(mv)이나 삭제(rm)를 시도하는지 감지
if [[ "$COMMAND" =~ mv[[:space:]]+.*Assets/ || "$COMMAND" =~ rm[[:space:]]+.*Assets/ || "$COMMAND" =~ git[[:space:]]rm[[:space:]]+.*Assets/ ]]; then
    # 명령어에 '.meta' 문자열이 포함되어 있지 않으면 차단
    if [[ ! "$COMMAND" =~ \.meta ]]; then
        echo "❌ [System Reject] Unity 에셋을 이동(mv)하거나 삭제(rm)할 때 .meta 파일이 포함되지 않았습니다." >&2
        echo "유니티 시스템 규정상 에셋과 .meta 파일은 항상 쌍으로 처리되어야 합니다. (예: rm file.cs && rm file.cs.meta)" >&2
        exit 1
    fi
fi
exit 0