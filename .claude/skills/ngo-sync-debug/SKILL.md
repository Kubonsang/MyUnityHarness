---
name: ngo-sync-debug
description: Debug Unity Netcode for GameObjects sync bugs such as HP or status desync, ownership mistakes, duplicate RPC effects, stale NetworkVariables, host-only behavior, and late-join mismatches. Use when server and client state differ or multiplayer behavior is inconsistent.
argument-hint: "[symptom, file, or path]"
---

Use this Skill to debug an **existing NGO sync bug** with the smallest correct fix.

## Use when
- server and client see different HP, state, or interaction results
- a bug appears only for remote clients, non-owners, or late joiners
- an effect happens twice, never happens, or only works on host
- you suspect a bad `NetworkVariable`, RPC, or authority boundary

## Do not use when
- you are designing a new interaction from scratch
- the problem is mainly local presentation with no multiplayer state impact
- you need broad architecture redesign instead of a targeted bug fix

## First classify the symptom
1. What differs exactly?
2. Which side is wrong: server, owner client, non-owner client, or late join client?
3. Is the problem:
   - persistent gameplay state
   - one-time event
   - local-only presentation

## Trace the authority path
For the failing action, identify:
1. who starts it
2. who validates it
3. who writes the authoritative result
4. who reads and applies the result

## Inspect in this order
1. input / caller path
2. `ServerRpc` / `Rpc` path
3. authoritative state write location
4. `NetworkVariable` declaration and write permissions
5. client read / apply path
6. visual side effects triggered by state changes

## Common root-cause buckets
- local-only mutation
- wrong-side write
- missing server validation
- duplicate event path
- bad `NetworkVariable` usage
- wrong RPC direction
- ownership assumption
- late-join state gap

## Decision rules
- Persistent gameplay state must resolve to one authoritative server-owned truth.
- One-time events should not replace persistent state.
- If only remote clients fail, inspect `IsOwner`, `IsServer`, `IsClient`, and owner-only branches.
- If only late join fails, inspect whether the current state is stored or only implied by past RPCs.

## Avoid these mistakes
- client writes gameplay truth and treats it as final
- `NetworkVariable` used as event spam
- RPC used to replace lasting state
- same effect triggered by both state change and RPC
- visual-only code mutates gameplay state
- host-mode success treated as proof that client mode is correct

## Response requirements
Keep answers concrete.
Separate:
- confirmed observations
- likely inference
- unverified assumptions

## Output format
Respond with:
1. Symptom
2. Likely broken sync boundary
3. Files or paths to inspect
4. Root cause hypothesis
5. Smallest safe fix
6. Why this fix
7. Confirmed vs unverified

If a fix is needed after diagnosis, continue with the `debug-fix` skill.
