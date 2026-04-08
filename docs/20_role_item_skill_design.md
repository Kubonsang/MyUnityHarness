# 20. 설계 문서: ROLE · WEAPON · ITEM · STATUS · SKILL 통합 아키텍처

작성일: 2026-03-12
범위: ROLE-01~05, WEAPON-01~03, ITEM-01~04, STATUS-01~04, SKILL-01~04
참조: `.antigravity/initial_role_plan.md`, `status_effects_plan.md`, `skill_system_plan.md`

---

## 1. 설계 목표 및 원칙

| 원칙 | 적용 방향 |
|------|-----------|
| 서버 권위 | 스탯 결정 · 효과 적용 · 조건 감지 모두 서버. 클라이언트는 시각 표현만 |
| 최소 결합 | 각 시스템은 인터페이스(`IStatusEffectable`, `IItemEffect`)를 통해서만 교차 참조 |
| 확장 우선 | 새 효과/조건/아이템은 기존 코드 수정 없이 데이터(SO) + 구현체 추가로 완성 |
| 기존 패턴 보존 | PlayerHealth / PlayerCombat / PlayerController 구조 유지, 최소 메서드 추가 |
| YAGNI 준수 | 현재 feature_list에 없는 시스템(예: 보스 전용 조건, 레이드 버프)은 설계에서 제외 |

---

## 2. 전체 파일 구조

```
Assets/Scripts/
│
├── Role/
│   ├── RoleType.cs                  # enum: Tank / DPS / Healer
│   ├── RoleData.cs                  # ScriptableObject: 역할 스탯 정의
│   └── PlayerRoleHandler.cs         # NetworkBehaviour: 역할 저장 + 스탯 초기화 + 레지스트리
│
├── Status/
│   ├── StatusEffectType.cs          # enum: Wound / Stun / Poison / Burn / Fatigue / Slow
│   │                                #        Invincible / Stealth / Valor / Haste / Fortify
│   ├── StatusEffectData.cs          # ScriptableObject: effectType, displayName, maxDuration, maxStacks
│   ├── ActiveEffect.cs              # INetworkSerializable struct: effectTypeId, remainingDuration, stacks
│   ├── IStatusEffectable.cs         # interface: ApplyEffect / RemoveEffect / HasEffect / GetStacks
│   ├── PlayerStatus.cs              # NetworkBehaviour: NetworkList<ActiveEffect>, 서버 API
│   └── MonsterStatus.cs             # NetworkBehaviour: 동일 구조, MonsterFSM 연동
│
├── Skill/
│   ├── ConditionType.cs             # enum: Time / HitAny / HitN / Damaged / Kill / HpLow / Dodge
│   ├── EffectType.cs                # enum: Damage + StatusEffectType 전체 + Projectile
│   ├── SkillEffectDef.cs            # [Serializable] class: EffectType, Duration, Magnitude
│   ├── SkillEntry.cs                # [Serializable] class: ConditionType, CondParam, Effects[], Cooldown
│   ├── ItemSkillData.cs             # ScriptableObject: SkillName, Description, Entries[]
│   ├── SkillConditionMonitor.cs     # NetworkBehaviour: 서버 이벤트 구독, 조건 감지, 효과 발동
│   └── SkillProjectile.cs           # NetworkBehaviour: Payload 주입형 투사체 (SKILL-04)
│
├── Item/
│   ├── ItemType.cs                  # enum: Passive / Active
│   ├── ItemData.cs                  # ScriptableObject: 기본 정보 + allowedRoles + skills[]
│   ├── IItemEffect.cs               # interface: OnEquipped / OnUnequipped / OnActivated
│   ├── PlayerContext.cs             # plain class: 플레이어 컴포넌트 묶음 (Health, Combat, Status...)
│   ├── NetworkItemSlot.cs           # INetworkSerializable struct: { int itemId }
│   ├── ItemRegistry.cs              # ScriptableObject: itemId → (ItemData, IItemEffect) 매핑
│   ├── PlayerInventory.cs           # NetworkBehaviour: NetworkList<NetworkItemSlot>, 서버 API
│   └── Effects/
│       └── HpBonusEffect.cs         # IItemEffect 구현체 예시 (ITEM-03 검증용 더미)
│
└── Player/  (기존 파일 수정)
    ├── PlayerHealth.cs              # + InitializeRole / + isInvincible 플래그 (ROLE-05) / + STATUS 쿼리
    ├── PlayerCombat.cs              # + SetWeapon / + OnHitTarget 이벤트 (SKILL-02 구독용)
    ├── PlayerController.cs          # + InitializeRole / + STATUS Stun/Slow/Haste 확인
    └── WeaponData.cs                # + attackDamage / + attackRange / + allowedRoles / + skills[]
```

---

## 3. 시스템별 컴포넌트 설계

### 3.1 Role System (ROLE-01~05)

#### RoleData (ScriptableObject)

```
RoleData
├── RoleType roleType
├── string   displayName
├── int      maxHpBonus                 # 절대값 덧셈 (기본 HP에 더함)
├── float    attackDamageMultiplier     # PlayerCombat 데미지 × 이 값
├── float    moveSpeedMultiplier        # PlayerController 이동속도 × 이 값
├── float    aggroMultiplier            # AggroSystem 데미지 어그로에 곱함
└── float    healPotencyMultiplier      # 힐러 전용 힐량 보정 (향후 힐 스킬용)
```

> maxHpBonus를 곱이 아닌 덧셈으로 선택:
> "Tank HP +50"처럼 절대 보너스를 상정. 곱셈은 기본 HP 조정 시 의도치 않은 변동 발생.

#### PlayerRoleHandler (NetworkBehaviour, Player 프리팹)

```
PlayerRoleHandler
├── NetworkVariable<byte> RoleTypeIndex   # 전 클라이언트 동기화 (UI 표시용)
├── RoleData RoleData { get; }            # 서버 전용
│
├── static Dictionary<ulong, PlayerRoleHandler> _registry
│     OnNetworkSpawn  → _registry[OwnerClientId] = this
│     OnNetworkDespawn → _registry.Remove(OwnerClientId)
│
├── static float ServerGetAggroMultiplier(ulong clientId)
│     # AggroSystem.OnDamageDealt에서 호출 (ROLE-04)
│
└── [서버] ServerSetRole(RoleData data)
      → RoleTypeIndex.Value = (byte)data.roleType
      → PlayerHealth.InitializeRole(data)       # maxHp 적용
      → PlayerController.InitializeRole(data)   # moveSpeed 적용
```

#### 기존 컴포넌트 최소 수정

```csharp
// PlayerHealth (ROLE-03 추가)
private int _baseMaxHp;   // Awake에서 _maxHp 복사 → Inspector 원본값 보존

public void InitializeRole(RoleData data)
{
    if (!IsServer) return;
    _maxHp = _baseMaxHp + data.maxHpBonus;
    _currentHp.Value = _maxHp;
}

// PlayerController (ROLE-03 추가)
private float _baseMoveSpeed;   // Awake에서 _moveSpeed 복사

public void InitializeRole(RoleData data)
{
    if (!IsServer) return;
    _moveSpeed = _baseMoveSpeed * data.moveSpeedMultiplier;
}
```

#### ROLE-05: Invincibility Frame (DPS 전용)

```csharp
// PlayerHealth에 플래그 추가 (STATUS-04에서 STATUS 시스템으로 통합 예정)
public bool IsInvincible { get; private set; }

public void ApplyDamage(int amount, ulong attackerClientId)
{
    if (!IsServer) return;
    if (IsInvincible) { Debug.Log("[PlayerHealth] Invincible, ignored"); return; }
    // ...
}

// 서버에서 코루틴으로 0.5초 후 IsInvincible = false
[ServerRpc] public void ActivateInvincibilityServerRpc() { ... }
```

---

### 3.2 Status System (STATUS-01~04)

#### ActiveEffect (INetworkSerializable struct)

```csharp
public struct ActiveEffect : INetworkSerializable
{
    public byte  EffectTypeId;       // (byte)StatusEffectType
    public float RemainingDuration;  // 지속 시간 남은 양
    public byte  Stacks;             // 현재 중첩 수 (중첩 없는 효과는 1)
}
```

> **왜 float RemainingDuration을 NetworkList에 포함하는가:**
> 늦게 접속한 클라이언트가 "현재 남은 시간"을 즉시 알 수 있어야 UI 표시 가능.
> 단, 서버만 값을 변경하고 클라이언트는 읽기 전용으로 사용.

#### IStatusEffectable

```csharp
public interface IStatusEffectable
{
    void  ApplyEffect(StatusEffectData data, int stacks = 1);
    void  RemoveEffect(StatusEffectType effectType);
    bool  HasEffect(StatusEffectType effectType);
    int   GetStacks(StatusEffectType effectType);
}
```

#### PlayerStatus / MonsterStatus (NetworkBehaviour)

```
PlayerStatus (NetworkBehaviour, Player 프리팹에 추가)
│
├── NetworkList<ActiveEffect> _activeEffects     # 전 클라이언트 동기화
├── [SerializeField] StatusEffectData[] _catalog  # Inspector에서 모든 효과 에셋 연결
│
├── [서버] ApplyEffect(StatusEffectData data, int stacks)
│     → 중첩 규칙 적용 (maxStacks 초과 시 클램핑)
│     → 이미 있으면 Duration 갱신 or Stacks 증가
│     → _activeEffects에 추가/갱신
│
├── [서버] RemoveEffect(StatusEffectType type)
│     → _activeEffects에서 제거
│
├── [서버] Update() or FixedUpdate()
│     → 서버에서만 남은 Duration 감산
│     → Duration ≤ 0 이면 RemoveEffect 호출
│
└── 쿼리 API (서버 + 클라이언트 모두 가능)
    HasEffect(type) → _activeEffects 순회
    GetStacks(type) → 스택 수 반환
```

> MonsterStatus는 PlayerStatus와 동일한 구조.
> MonsterFSM.Tick()에서 `_status.HasEffect(StatusEffectType.Stun)` 으로 틱 스킵.

#### STATUS → 기존 코드 연동 (STATUS-03/04 수정 대상)

| 수정 대상 | 추가 내용 | 관련 효과 |
|-----------|-----------|-----------|
| `PlayerHealth.ApplyDamage` | `IsInvincible` → Invincible 효과 확인으로 교체 (STATUS-04) | Invincible |
| `PlayerHealth.ApplyDamage` | Fatigue 효과 시 데미지 ×(1 + magnitude) | Fatigue |
| `PlayerHealth.ApplyDamage` | Fortify 효과 시 데미지 ×(1 - magnitude) | Fortify |
| `PlayerHealth.ApplyHeal` | Wound 효과 시 힐량 ×(1 - magnitude) | Wound |
| `PlayerHealth.ApplyHeal` | Burn 효과 시 힐량 = 0 | Burn |
| `PlayerController.ApplyMovement` | Stun 효과 시 moveInput = Vector2.zero + 공격 차단 | Stun |
| `PlayerController.ApplyMovement` | Slow/Haste 효과 시 speed × multiplier | Slow, Haste |
| `MonsterFSM.Tick` | Stun 효과 시 Tick 조기 종료 | Stun |
| `MonsterFSM` (NavMeshAgent) | Slow/Haste 효과 시 _agent.speed 재계산 | Slow, Haste |
| `AggroSystem` (OverlapSphere) | Stealth 플레이어 필터링 | Stealth |

---

### 3.3 Skill System (SKILL-01~04)

#### 데이터 계층 (SKILL-01)

```csharp
// ConditionType: 감지 방법
public enum ConditionType
{
    Time,       // N초마다 (CondParam = 주기)
    HitAny,     // 공격 명중 (PlayerCombat.OnHitTarget)
    HitN,       // 동일 대상 N번 명중 (CondParam = N)
    Damaged,    // 피격 (PlayerHealth.OnTakeDamage 이벤트)
    Kill,       // 처치 (MonsterHealth 사망 이벤트)
    HpLow,      // 자신 HP X% 이하 (CondParam = 0.0~1.0)
    Dodge,      // 무적 프레임 중 피격 감지 (ROLE-05 + STATUS-04 구현 후)
}

// EffectType: STATUS 효과 전체 + 특수 효과
public enum EffectType
{
    Damage,       // 즉발 데미지 (IDamageable.ApplyDamage)
    Wound, Stun, Poison, Burn, Fatigue, Slow,           // 디버프
    Invincible, Stealth, Valor, Haste, Fortify,         // 버프
    Projectile,   // 투사체 발사 (SKILL-04)
}

[Serializable]
public class SkillEffectDef
{
    public EffectType Type;
    public float Duration;    // 즉발은 0
    public int   Magnitude;   // 데미지량, 스택 한도, 퍼센트(0~100) 등
}

[Serializable]
public class SkillEntry
{
    [Header("Condition")]
    public ConditionType CondType;
    public float         CondParam;   // 3타 조건이면 3, 5초마다면 5.0f

    [Header("Effects")]
    public List<SkillEffectDef> Effects;

    [Header("Cooldown")]
    public float Cooldown;   // 이 Entry의 내부 쿨다운
}

[CreateAssetMenu(fileName = "SkillData", menuName = "GNF/Skill Data")]
public class ItemSkillData : ScriptableObject
{
    public string          SkillName;
    public string          Description;
    public List<SkillEntry> Entries;
}
```

#### SkillConditionMonitor (NetworkBehaviour, SKILL-02)

```
SkillConditionMonitor (서버 전용, Player 프리팹에 추가)
│
├── List<SkillEntry>        _activeEntries      # 장착된 아이템/무기의 모든 SkillEntry
├── Dictionary<int, float>  _cooldownTimers     # entryHash → 남은 쿨다운
├── Dictionary<(ulong target, int entryHash), int> _hitCounters  # HitN 조건용
│
├── OnNetworkSpawn [서버]
│     → PlayerCombat.OnHitTarget  += HandleHitAny/HitN
│     → PlayerHealth.OnTakeDamage += HandleDamaged
│     → PlayerHealth.OnKill       += HandleKill      (SKILL-03)
│
├── AddEntries(ItemSkillData skillData)    # 아이템 장착 시 PlayerInventory가 호출
├── RemoveEntries(ItemSkillData skillData) # 아이템 해제 시
│
├── [서버] HandleHitAny(ulong targetClientId)
│     → HitAny/HitN 조건 Entry 순회
│     → 쿨다운 통과 시 ApplyEffects(entry, targetClientId)
│
├── [서버] HandleDamaged(int amount, ulong attackerClientId)
│     → Damaged 조건 Entry 순회 → 자신에게 Effects 적용
│
├── [서버] Update()
│     → Time 조건 타이머 누산 → 달성 시 ApplyEffects
│     → _cooldownTimers 감산
│
└── [서버] ApplyEffects(SkillEntry entry, ulong targetClientId)
      → IStatusEffectable (target/self)에 각 EffectDef 전달
      → EffectType.Damage → IDamageable.ApplyDamage
      → EffectType.Projectile → SkillProjectile 스폰 (SKILL-04)
      → 나머지 → statusTarget.ApplyEffect(effectData)
```

#### SkillProjectile (NetworkBehaviour, SKILL-04)

```
SkillProjectile
├── SkillEntry _payload         # 피격 시 발동할 효과 묶음 (Chaining)
├── ulong      _ownerClientId
│
├── Initialize(SkillEntry payload, ulong ownerClientId)
│
└── OnTriggerEnter [서버]
      → _payload.Effects 순회
      → IStatusEffectable/IDamageable에 적용
      → Despawn
```

#### Skill ↔ Item 연결 방식

`IItemEffect.OnEquipped` / `PlayerInventory.AddItem` 시:
1. `IItemEffect.OnEquipped(ctx)` → 프로그래매틱 효과 (HP 보너스 등) 적용
2. `SkillConditionMonitor.AddEntries(itemData.skills)` → 조건 감시 등록

분리 이유: 프로그래매틱 효과(즉시 적용)와 조건 기반 스킬(이벤트 감시)은 생명주기와 동작 방식이 다름.

---

### 3.4 Item System (ITEM-01~04)

#### ItemData (ScriptableObject, ITEM-01 확장)

```
ItemData
├── int      itemId                  # NetworkItemSlot에 저장하는 식별자
├── string   itemName
├── string   itemDescription
├── ItemType itemType                # Passive / Active
├── float    cooldown                # Active 전용 (ITEM-04)
├── RoleType[] allowedRoles          # 빈 배열 = 제한 없음
└── ItemSkillData[] skills           # 조건 기반 스킬 (SKILL-01 이후 연동)
```

#### PlayerContext (plain class)

```csharp
public class PlayerContext
{
    public PlayerHealth     Health;
    public PlayerCombat     Combat;
    public PlayerController Controller;
    public PlayerInventory  Inventory;
    public PlayerStatus     Status;    // STATUS-01 이후 추가
    public ulong            OwnerClientId;
}
```

#### PlayerInventory (NetworkBehaviour, ITEM-02)

```
PlayerInventory
│
├── [SerializeField] int _maxSlots
├── NetworkList<NetworkItemSlot> _slots      # 전 클라이언트 동기화
├── Dictionary<int, float> _cooldownTimers  # 서버 전용, ITEM-04
│
├── [서버] AddItem(int itemId)
│     → 슬롯 초과 방지
│     → _slots.Add(new NetworkItemSlot { itemId })
│     → ItemRegistry.GetEffect(itemId)?.OnEquipped(ctx)
│     → SkillConditionMonitor.AddEntries(data.skills)    # SKILL-02 이후
│
├── [서버] RemoveItem(int itemId)
│     → _slots에서 제거
│     → ItemRegistry.GetEffect(itemId)?.OnUnequipped(ctx)
│     → SkillConditionMonitor.RemoveEntries(data.skills)  # SKILL-02 이후
│
├── [서버] UseItem(int itemId)              # ITEM-04
│     → 슬롯에 존재 확인
│     → 쿨다운 확인
│     → ItemRegistry.GetEffect(itemId)?.OnActivated(ctx)
│     → _cooldownTimers[itemId] = data.cooldown
│
└── [서버] Update()                         # ITEM-04
      → _cooldownTimers 값 감산
```

---

### 3.5 Weapon System (WEAPON-01~03)

#### WeaponData 확장 (WEAPON-01)

```
WeaponData (기존 유지)
├── string attackAnimStateName
├── float  attackDuration
// WEAPON-01 추가
├── int          attackDamage
├── float        attackRange
├── RoleType[]   allowedRoles       # 빈 배열 = 제한 없음
└── ItemSkillData[] skills          # 무기 전용 스킬 (SKILL-01 이후 연동)
```

#### PlayerCombat 수정 (WEAPON-01~02)

```csharp
// 추가 필드
private WeaponData _equippedWeapon;

// 추가 이벤트 (SKILL-02에서 SkillConditionMonitor가 구독)
public event Action<ulong> OnHitTarget;     // (targetClientId)
public event Action<int>   OnKill;          // (killedNetworkObjectId) — 향후

// SetWeapon (서버 전용, WEAPON-02)
public void SetWeapon(WeaponData weapon)
{
    if (!IsServer) return;
    _equippedWeapon = weapon;
    // NetworkVariable<int> _weaponId 갱신 → 클라이언트 애니메이션 동기화
    // SkillConditionMonitor 스킬 교체
}

// PerformAttack 수정 (WEAPON-01)
public void PerformAttack()
{
    int   damage = _equippedWeapon != null ? _equippedWeapon.attackDamage : _attackDamage;
    float range  = _equippedWeapon != null ? _equippedWeapon.attackRange  : _attackRange;

    Collider[] hits = Physics.OverlapSphere(transform.position, range);
    foreach (var hit in hits)
    {
        if (hit.gameObject == gameObject) continue;
        if (hit.TryGetComponent(out IDamageable target))
        {
            target.ApplyDamage(damage, attackerClientId);
            OnHitTarget?.Invoke(hit.GetComponent<NetworkObject>()?.OwnerClientId ?? 0);
        }
    }
}
```

#### WEAPON-03: 역할 제한 검증

```csharp
// PlayerCombat.EquipWeaponServerRpc 내부 (서버)
if (weapon.allowedRoles.Length > 0)
{
    RoleType myRole = GetComponent<PlayerRoleHandler>()?.RoleData?.roleType ?? default;
    if (!System.Array.Contains(weapon.allowedRoles, myRole))
    {
        EquipWeaponFailedClientRpc(OwnerClientId);
        return;
    }
}
```

---

## 4. 시스템 간 의존 관계 (전체)

```
[스폰] LobbyRoleSelector
    └─[SelectRoleServerRpc]─► PlayerRoleHandler.ServerSetRole(RoleData)
                                ├─► PlayerHealth.InitializeRole(data)
                                ├─► PlayerController.InitializeRole(data)
                                └─► static _registry 등록

[어그로] AggroSystem.OnDamageDealt(amount, clientId)
    └─► PlayerRoleHandler.ServerGetAggroMultiplier(clientId)    ← ROLE-04
            └─► _registry[clientId].RoleData.aggroMultiplier

[피격] PlayerHealth.ApplyDamage(amount, clientId)
    ├─► PlayerStatus.HasEffect(Invincible) → 무시               ← STATUS-04
    ├─► PlayerStatus.GetStacks(Fatigue)   → 증폭                ← STATUS-03
    └─► PlayerStatus.HasEffect(Fortify)  → 감소                 ← STATUS-04

[힐] PlayerHealth.ApplyHeal(amount)
    ├─► PlayerStatus.HasEffect(Burn)     → 힐 차단              ← STATUS-03
    └─► PlayerStatus.GetStacks(Wound)    → 힐 감소              ← STATUS-03

[이동] PlayerController.ApplyMovement()
    ├─► PlayerStatus.HasEffect(Stun)     → 이동/공격 차단       ← STATUS-03
    └─► PlayerStatus.HasEffect(Slow/Haste) → speed 보정         ← STATUS-03/04

[AI 틱] MonsterFSM.Tick(deltaTime)
    └─► MonsterStatus.HasEffect(Stun)    → Tick 스킵            ← STATUS-03

[어그로 탐지] AggroSystem + MonsterFSM.FindNearestPlayer()
    └─► 대상 PlayerStatus.HasEffect(Stealth) → 필터링           ← STATUS-04

[인벤토리] PlayerInventory.AddItem(itemId)
    ├─► IItemEffect.OnEquipped(ctx)      → 프로그래매틱 효과    ← ITEM-03
    └─► SkillConditionMonitor.AddEntries(data.skills)            ← SKILL-02

[스킬 조건] SkillConditionMonitor
    ├─ PlayerCombat.OnHitTarget  구독    → HitAny/HitN 조건 감지 ← SKILL-02
    ├─ PlayerHealth.OnTakeDamage 구독   → Damaged 조건 감지      ← SKILL-02
    └─ ApplyEffects(entry, targetId)
         ├─► IDamageable.ApplyDamage                             ← 즉발 Damage
         ├─► IStatusEffectable.ApplyEffect(statusData)          ← 버프/디버프
         └─► SkillProjectile Spawn + Initialize(payload)        ← SKILL-04

[투사체] SkillProjectile.OnTriggerEnter()
    └─► _payload.Effects → IStatusEffectable / IDamageable      ← SKILL-04
```

---

## 5. 네트워크 동기화 설계 결정

| 데이터 | 분류 | 동기화 방식 | 이유 |
|--------|------|-------------|------|
| 플레이어 RoleType | 지속 상태 | `NetworkVariable<byte>` | 늦게 합류한 클라이언트가 역할 UI 표시 필요 |
| 장착 무기 ID | 지속 상태 | `NetworkVariable<int>` | 늦게 합류한 클라이언트가 애니메이션 동기화 필요 |
| 인벤토리 슬롯 | 지속 상태 | `NetworkList<NetworkItemSlot>` | 늦게 합류한 클라이언트가 아이템 목록 필요 |
| 활성 상태 효과 | 지속 상태 | `NetworkList<ActiveEffect>` | 늦게 합류한 클라이언트가 버프/디버프 UI 표시 필요 |
| 스킬 HitN 카운터 | 서버 전용 임시 상태 | 없음 | 결과(효과 발동)만 동기화하면 충분 |
| 스킬 쿨다운 타이머 | 서버 전용 임시 상태 | 없음 | 클라이언트 UI는 로컬 예측으로 표시 |
| 효과 발동 VFX | 일회성 이벤트 | `ClientRpc` | 영속 상태 불필요, 한 번만 발생 |
| 역할 선택 실패 알림 | 일회성 이벤트 | `ClientRpc` | 서버 거부를 클라이언트에 1회 통보 |
| 무기 장착 실패 알림 | 일회성 이벤트 | `ClientRpc` | 서버 거부를 클라이언트에 1회 통보 |

---

## 6. 구현 순서 및 태스크별 파일 범위

### 권장 구현 순서 (선행 의존성 기준)

```
ROLE-01 → ROLE-02 → ROLE-03
                         ↓
WEAPON-01 → WEAPON-02 → WEAPON-03
                         ↓
ITEM-01 → ITEM-02
              ↓
STATUS-01 → STATUS-02 → STATUS-03 → STATUS-04
                ↓
ITEM-03 → ITEM-04
              ↓
SKILL-01 → SKILL-02 → SKILL-03 → SKILL-04
                                      ↓
                               ROLE-04 → ROLE-05 (STATUS 통합)
```

### 태스크별 신규/수정 파일

| 태스크 | 신규 파일 | 수정 파일 |
|--------|-----------|-----------|
| ROLE-01 | `RoleType.cs`, `RoleData.cs` | — |
| ROLE-02 | `LobbyRoleSelector.cs` | — |
| ROLE-03 | `PlayerRoleHandler.cs` | `PlayerHealth.cs`, `PlayerController.cs` |
| ROLE-04 | — | `AggroSystem.cs`, `PlayerRoleHandler.cs` |
| ROLE-05 | — | `PlayerHealth.cs`, `PlayerInputHandler.cs` |
| WEAPON-01 | — | `WeaponData.cs`, `PlayerCombat.cs` |
| WEAPON-02 | — | `PlayerCombat.cs` (SetWeapon + ServerRpc + `NetworkVariable<int> _weaponId`) |
| WEAPON-03 | — | `PlayerCombat.cs` (allowedRoles 검증 + FailedClientRpc) |
| ITEM-01 | `ItemType.cs`, `ItemData.cs`, `IItemEffect.cs`, `PlayerContext.cs` | — |
| ITEM-02 | `NetworkItemSlot.cs`, `PlayerInventory.cs`, `ItemRegistry.cs` | — |
| ITEM-03 | `Effects/HpBonusEffect.cs` | `PlayerInventory.cs`, `PlayerHealth.cs` (ApplyBonusHp) |
| ITEM-04 | — | `PlayerInventory.cs` (UseItem + cooldown), `PlayerInputHandler.cs` |
| STATUS-01 | `StatusEffectType.cs`, `StatusEffectData.cs`, `ActiveEffect.cs`, `IStatusEffectable.cs` | — |
| STATUS-02 | `PlayerStatus.cs`, `MonsterStatus.cs` | — |
| STATUS-03 | — | `PlayerStatus.cs` (효과 로직), `PlayerHealth.cs`, `PlayerController.cs`, `MonsterFSM.cs` |
| STATUS-04 | — | `PlayerStatus.cs` (버프 로직), `PlayerHealth.cs`, `AggroSystem.cs`, `PlayerRoleHandler.cs` (Invincible 이관) |
| SKILL-01 | `ConditionType.cs`, `EffectType.cs`, `SkillEffectDef.cs`, `SkillEntry.cs`, `ItemSkillData.cs` | — |
| SKILL-02 | `SkillConditionMonitor.cs` | `PlayerCombat.cs` (OnHitTarget 이벤트), `PlayerHealth.cs` (OnTakeDamage 이벤트) |
| SKILL-03 | — | `SkillConditionMonitor.cs` (ApplyEffects → IStatusEffectable 연결) |
| SKILL-04 | `SkillProjectile.cs` | `SkillConditionMonitor.cs` (Projectile 효과 처리) |

---

## 7. 핵심 설계 결정 요약

### PlayerRoleHandler에 static registry를 두는 이유
AggroSystem이 공격자의 역할 데이터를 조회할 때 `FindObjectOfType` 대신 O(1) 딕셔너리 접근.
MonsterManager의 static Instance 패턴과 동일한 접근 방식으로 일관성 유지.

### IStatusEffectable 분리 이유
PlayerStatus(플레이어)와 MonsterStatus(몬스터) 둘 다 동일 인터페이스를 구현하여,
SkillConditionMonitor.ApplyEffects가 대상 타입에 무관하게 효과를 부여 가능.
이미 IDamageable이 같은 역할을 하고 있으므로 기존 패턴의 연장.

### ItemSkillData를 IItemEffect와 분리하는 이유
- `IItemEffect` = 즉시 적용되는 프로그래매틱 효과 (HP +20)
- `ItemSkillData` = 조건 충족 시 발동하는 이벤트 기반 효과 (3타 → 기절)
- 생명주기가 다름: IItemEffect는 OnEquipped에 즉시 적용, SkillEntry는 ConditionMonitor에 등록 후 이벤트 수신

### NetworkItemSlot을 int itemId만 가진 struct로 만드는 이유
NGO NetworkList는 INetworkSerializable 구현 필요.
ScriptableObject 참조는 네트워크 전송 불가 → itemId만 전송, 클라이언트는 ItemRegistry로 로컬 룩업.

### ActiveEffect에 RemainingDuration을 포함하는 이유
늦게 접속한 클라이언트가 "현재 버프/디버프 남은 시간"을 즉시 알 수 있어야 함.
Duration 업데이트 빈도가 높아 대역폭이 우려되지만, NetworkList는 변경된 항목만 전송하므로
서버가 Duration 감산을 1초 단위로만 수행하면 실용적 수준.

### SkillEntry.Cooldown이 ItemSkillData가 아닌 SkillEntry 단위인 이유
같은 ItemSkillData 안에서도 Entry별로 다른 쿨다운을 가질 수 있음.
(예: 3타 → 기절은 3초 쿨, 5초마다 신속 부여는 독립 쿨)

---

## 8. 결정 사항 및 미결 사항

### ✅ 확정된 사항

#### 역할 중복 허용 안 함
동일 역할은 파티 내 1명으로 제한.
**LobbyRoleSelector 영향**: `SelectRoleServerRpc` 처리 시 서버가 `_selectedRoles.ContainsValue(requestedRole)`로 중복 검사.
이미 선택된 역할 요청 시 `SelectRoleFailedClientRpc`로 거부 응답.

```csharp
// LobbyRoleSelector.SelectRoleServerRpc 내부 (서버)
if (_selectedRoles.ContainsValue(requestedRole))
{
    SelectRoleFailedClientRpc(/* 이미 선택된 역할 */);
    return;
}
_selectedRoles[OwnerClientId] = requestedRole;
SelectRoleConfirmedClientRpc(requestedRole);
```

#### 씬 구조: 로비/게임 분리 예정, 현재는 테스트 씬에서 통합 운용
- **최종 목표**: 로비 씬(역할 선택) → 게임 씬(전투) 분리
- **현재 구현 방침**: 테스트 편의상 단일 씬(기존 SampleScene 또는 테스트 씬)에서 `LobbyRoleSelector`를 씬 오브젝트로 배치하여 동작
- **LobbyRoleSelector 배치**: 씬 오브젝트(NetworkObject). 게임 시작 전 역할 선택 UI를 활성화하고, 모든 플레이어가 선택 완료 후 플레이어 스폰 순서로 진행

```
[현재 테스트 씬 구성]
SampleScene
├── NetworkManager
├── MonsterManager
├── LobbyRoleSelector    ← NetworkObject, 역할 선택 완료 시 PlayerSpawn 트리거
├── MonsterSpawner
└── (기존 오브젝트들)
```

> 로비/게임 씬 분리 시 `LobbyRoleSelector`는 로비 씬으로 이동하고,
> 역할 정보는 씬 전환 이후에도 유지되도록 `NetworkManager.DontDestroyOnLoad` 또는
> 서버 측 별도 저장소(예: `GameSessionData`)로 이관 예정. 이 시점에 추가 태스크 등록.

---

### ❓ 미결 사항

- [x] ~~ROLE-05 DPS 이동기의 방향/거리 기획 확정~~ → **결정됨**: 스킬 아이디어는 언제든 변경될 수 있으므로, 현재 단계에서는 개발 및 검증을 위한 **단순 전방 대쉬(Dummy Dash)** 형태로 뼈대만 구현합니다.
- [ ] PlayerHealth.OnTakeDamage 이벤트가 현재 미존재 → SKILL-02 착수 전 COMBAT-01에 추가 필요
- [ ] PlayerCombat.OnHitTarget 이벤트가 현재 미존재 → SKILL-02 착수 전 추가 필요
- [ ] ItemRegistry 방식 결정: ScriptableObject(에디터 연결) vs Singleton MonoBehaviour(코드 등록) → ITEM-02 착수 전 확정
- [ ] StatusEffectData 에셋 관리 방식: PlayerStatus._catalog(로컬)로 충분한가, 중앙 StatusRegistry가 필요한가
