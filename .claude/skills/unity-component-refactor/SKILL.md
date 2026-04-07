---
name: unity-component-refactor
description: Refactor an existing Unity MonoBehaviour or gameplay component with minimal behavioral change. Use when improving readability, responsibility boundaries, or maintainability without introducing a new subsystem or broad architecture rewrite.
argument-hint: "[component, file, or path]"
---

Use this Skill for a **small, behavior-preserving refactor** in an existing Unity codebase.

## Use when
- one component has too many mixed responsibilities
- a method is hard to read or follow
- duplication is obvious and stable
- gameplay logic and presentation are tangled
- naming or control flow blocks a nearby feature or bug fix

## Do not use for
- speculative architecture redesign
- framework introduction
- broad file moves or renames without strong reason
- large multi-system cleanup in one pass

## Refactor workflow
### 1. Read before changing
Inspect:
- the component itself
- direct collaborators
- call sites
- serialized fields, scene links, or prefab assumptions

### 2. Name the real problem
Classify it:
- too many responsibilities
- confusing control flow
- duplicated logic
- hidden dependency
- mixed authority/presentation logic
- poor naming
- lifecycle misuse

### 3. Choose the smallest useful change
Preferred order:
1. rename for clarity
2. extract small private helpers
3. group related logic
4. separate obvious presentation-only code
5. split responsibilities only when clearly justified

### 4. Preserve external behavior
Check:
- public method meaning stays the same
- serialized fields still map correctly
- lifecycle timing did not change accidentally
- inspector or prefab assumptions still hold

## Good refactor targets
- repeated guard clauses
- repeated state checks
- long methods with clear sub-steps
- UI/VFX mixed into gameplay mutation
- branches that differ mostly in presentation

## Bad refactor patterns
- splitting files only to satisfy line count
- adding interfaces nobody needs
- abstracting one-off logic
- renaming everything during a bug fix
- moving multiple systems at once
- changing `NetworkVariable` declaration order or visibility in a `NetworkBehaviour` — NGO serializes these by index, so reordering breaks existing saves and connected clients

## Response requirements
State the concrete refactor reason.
Explain what should remain behaviorally identical.

## Output format
Respond with:
1. Current problem
2. Refactor scope
3. Proposed small changes
4. Behavior expected to stay the same
5. Risk points
6. Confirmed vs unverified
