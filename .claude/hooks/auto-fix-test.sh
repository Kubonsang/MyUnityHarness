#!/bin/bash
# testplay 에러 자동 복구 훅 (바이브 코딩 최적화 버전)

# (선택) Bash 엄격 모드 활성화: 선언되지 않은 변수 사용이나 파이프라인 에러를 엄격하게 차단
set -euo pipefail

# 1. 무한 루프 방지: 서브 에이전트 컨텍스트에서는 훅을 건너뜁니다.
# 엄격 모드(set -u) 하에서도 환경변수 미선언 에러가 나지 않도록 방어(:- 구문)합니다.
if [ "${SKIP_TESTPLAY_HOOK:-}" = "1" ]; then
    exit 0
fi

# 2. 필수 의존성 검사
if ! command -v jq &> /dev/null; then
    echo "[Hook Warning] jq가 설치되어 있지 않아 testplay 에러 감지 훅을 실행할 수 없습니다." >&2
    exit 0
fi

# 3. Claude Code가 넘겨주는 JSON 데이터 전체 읽기
INPUT=$(cat)

# 4. Exit Code 추출 (없거나 null일 경우 empty로 처리)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // empty')

# Exit Code가 비어있거나 0(성공)이면 즉시 종료
if [ -z "$EXIT_CODE" ] || [ "$EXIT_CODE" = "0" ] || [ "$EXIT_CODE" = "null" ]; then
    exit 0
fi

# 5. 코드를 수정해서 해결할 수 없는 시스템 에러(4:타임아웃, 5:설정, 8:인터럽트, 9:인프라) 필터링
if [[ "$EXIT_CODE" =~ ^(4|5|8|9)$ ]]; then
    echo "[Hook Info] 시스템/설정 에러 (Exit Code: $EXIT_CODE) 감지됨. 코드 자동 수정을 건너뜁니다." >&2
    exit 0
fi

# 6. 임시 파일 생성 및 안전한 삭제(trap) 보장
ERROR_DUMP_PATH=$(mktemp /tmp/testplay_error_dump_XXXXXX.json)

# 스크립트가 종료될 때(정상/에러/Ctrl+C 등) 무조건 파일을 삭제하도록 OS에 예약합니다.
trap 'rm -f "$ERROR_DUMP_PATH"' EXIT

# 에러 데이터를 임시 파일에 기록
echo "$INPUT" > "$ERROR_DUMP_PATH"

echo "[Hook Trigger] testplay 로직 에러 (Exit Code: $EXIT_CODE) 감지됨. 서브 에이전트(testplay-parser)를 가동합니다..." >&2

# 7. 서브 에이전트 실행
# 서브 에이전트 안에서 또 훅이 돌지 않도록 환경변수 주입
export SKIP_TESTPLAY_HOOK=1
claude --agent testplay-parser -p "방금 실행한 testplay run이 Exit Code $EXIT_CODE 로 실패했습니다. 첨부된 에러 덤프 파일($ERROR_DUMP_PATH)의 JSON 결과를 분석하여 원본 소스 코드의 에러를 즉시 수정해 주십시오."