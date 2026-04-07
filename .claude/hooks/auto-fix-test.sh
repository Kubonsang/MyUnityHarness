#!/bin/bash
set -euo pipefail

if [ "${SKIP_TESTPLAY_HOOK:-}" = "1" ]; then
    exit 0
fi

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if [[ ! "$COMMAND" =~ "testplay run" ]]; then
    exit 0
fi

EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // empty')

if [ -z "$EXIT_CODE" ] || [ "$EXIT_CODE" = "0" ] || [ "$EXIT_CODE" = "null" ]; then
    exit 0
fi

if [[ "$EXIT_CODE" =~ ^(4|5|8|9)$ ]]; then
    exit 0
fi

ERROR_DUMP_PATH=$(mktemp /tmp/testplay_error_dump_XXXXXX.json)
trap 'rm -f "$ERROR_DUMP_PATH"' EXIT

echo "$INPUT" > "$ERROR_DUMP_PATH"

echo "🚨 [Hook Enforcement] testplay 실행이 Exit Code $EXIT_CODE 로 실패했습니다."
echo "현재 이 작업을 수행 중인 에이전트(QA)는 다음을 수행하십시오:"
echo "1. $ERROR_DUMP_PATH 파일을 읽어 에러의 원인(line, message)을 파악할 것."
echo "2. Edit 도구를 사용하여 원본 코드를 즉시 수정하고 다시 testplay run --shadow 를 돌릴 것."