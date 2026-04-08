---
name: inspect-prefab
description: 난해한 유니티 .prefab (YAML) 파일을 분석하여 포함된 게임 오브젝트 계층과 컴포넌트 목록을 사람이 읽기 쉽게 요약합니다.
argument-hint: "[프리팹 파일 경로]"
---

# Prefab Inspector
대상: `$ARGUMENTS`

이 스킬은 유니티를 켜지 않고 프리팹의 구조를 파악하기 위한 도구입니다.

1. `$ARGUMENTS` 파일을 읽으십시오.
2. YAML 구조에서 `--- !u!1 &...` 로 시작하는 GameObject와 `m_Name`을 매칭하여 계층 구조(Hierarchy)를 추론하십시오.
3. 각 GameObject에 붙어있는 핵심 Component(`m_Component` 리스트)가 무엇인지 매핑하여, 마치 유니티 Inspector 창을 보듯 트리 구조 텍스트로 요약해 보고하십시오.