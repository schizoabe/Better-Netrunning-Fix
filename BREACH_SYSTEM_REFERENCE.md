# Better Netrunning - Breach System Technical Reference

**Last Updated:** 2025-10-11
**Purpose:** Technical reference for Breach System implementation

**IMPORTANT DEPENDENCY:** Remote Breach functionality requires CustomHackingSystem (HackingExtensions mod). All RemoteBreach-related code is wrapped with `@if(ModuleExists("HackingExtensions"))`.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Breach Initialization Methods](#breach-initialization-methods)
3. [Daemon Injection](#daemon-injection)
4. [Program Filtering](#program-filtering)
5. [Minigame Parameters](#minigame-parameters)
6. [Post-Breach Processing](#post-breach-processing)
7. [Settings Control](#settings-control)
8. [Processing Flow Comparison](#processing-flow-comparison)
9. [Processing Timing Details](#processing-timing-details)
10. [Key Functional Differences Summary](#key-functional-differences-summary)

---

## Overview

Better Netrunning supports three breach types with distinct characteristics:

- **AP Breach:** Traditional breach via Access Points
- **Unconscious NPC Breach:** Direct breach on unconscious NPCs
- **Remote Breach:** Remote breach on devices (Computer/Camera/Turret/Device/Vehicle)

### Network Access Relaxation

**Implementation:** `DeviceNetworkAccess.reds`

Better Netrunning includes network access relaxation features that enhance player freedom:

1. **Door QuickHack Menu:** All doors show QuickHack menu regardless of AP connection
2. **Standalone Device RemoteBreach:** All devices can use RemoteBreach (not just networked ones)
3. **Universal Ping:** Ping works on all devices for reconnaissance

**Purpose:** Remove arbitrary network topology limitations and provide consistent player experience.

---

## Breach Initialization Methods

### Comparison Table

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Entity & Interaction** | AccessPoint entity interaction | Unconscious NPC interaction<br>("Breach Unconscious Officer") | CustomHackingSystem API<br>(Quickhack on Computer/Device/Camera/etc.) |
| **Blackboard Flags** | `RemoteBreach = false`<br>`OfficerBreach = false` | `RemoteBreach = false`<br>`OfficerBreach = true` | `RemoteBreach = true`<br>`OfficerBreach = false` |
| **Target Entity** | AccessPoint | ScriptedPuppet (unconscious state) | Device, Computer, Camera, Turret, Vehicle, ScriptedPuppet |
| **Network Connection Requirement** | ❌ Not required (AP itself is hub) | ✅ Required via `IsConnectedToBackdoorDevice()` | ⚠️ Relaxed via `DeviceNetworkAccess.reds`<br>(Always returns true for standalone devices) |

### Detailed Activation Conditions

#### AP Breach
```
✅ AccessPoint entity exists
✅ Interaction available
```

#### Unconscious NPC Breach
```
✅ AllowBreachingUnconsciousNPCs = true
✅ NPC is unconscious
✅ IsConnectedToBackdoorDevice() = true
   (Relaxed by DeviceNetworkAccess.reds - always true for standalone)
✅ RadialUnlock Mode enabled (UnlockIfNoAccessPoint = false)
   OR physically connected to AP
✅ Not directly breached (m_betterNetrunningWasDirectlyBreached = false)
```

**Implementation:** `NPCLifecycle.reds`

#### Remote Breach
```
✅ Corresponding RemoteBreachEnabled setting = true
   - RemoteBreachEnabledComputer (Computer)
   - RemoteBreachEnabledCamera (Camera)
   - RemoteBreachEnabledTurret (Turret)
   - RemoteBreachEnabledDevice (Device)
   - RemoteBreachEnabledVehicle (Vehicle)
✅ RadialUnlock Mode enabled (UnlockIfNoAccessPoint = false)
✅ Target available (network connection relaxed by DeviceNetworkAccess.reds)
✅ Not breached (checked by RemoteBreachStateSystem)
```

**Implementation:** `RemoteBreachAction_*.reds`, `DeviceNetworkAccess.reds`

---

## Daemon Injection

### Injected Subnet Daemons

**Note:** Remote Breach has three action types (Computer/Device/Vehicle) based on target device type
- **Computer RemoteBreach:** For ComputerControllerPS (always `camera,basic` daemons)
- **Device RemoteBreach:** For Camera/Turret/Terminal/Other devices (daemons dynamically determined by device type)
  - Camera: `camera,basic` daemons
  - Turret: `turret,basic` daemons
  - Terminal: `npc,basic` daemons
  - Other: `basic` daemon only
- **Vehicle RemoteBreach:** Vehicle-specific (always `basic` daemon only)

**Architecture:**
- Computer: Managed by `RemoteBreachStateSystem` (RemoteBreachAction_Computer.reds)
- Device: Managed by `DeviceRemoteBreachStateSystem` (RemoteBreachAction_Device.reds)
- Vehicle: Managed by `VehicleRemoteBreachStateSystem` (RemoteBreachAction_Vehicle.reds)
- Daemon determination: Computer uses fixed "camera,basic", Device uses `GetAvailableDaemonsForDevice()`

| Daemon Type | AP Breach | Unconscious NPC Breach<br>(Regular NPC) | Unconscious NPC Breach<br>(Netrunner) | Remote Breach<br>(Device - Computer) | Remote Breach<br>(Device - Camera) | Remote Breach<br>(Device - Turret) | Remote Breach<br>(Device - Terminal) | Remote Breach<br>(Device - Other) | Remote Breach<br>(Vehicle) |
|------------|-----------|--------------------------|------------------------------|-------------------------------|------------------------|------------------------|---------------------------|------------------------|-------------------------|
| **Turret Subnet** | ✅ Injected | ❌ | ✅ Injected | ❌ | ❌ | ✅ Injected | ❌ | ❌ | ❌ |
| **Camera Subnet** | ✅ Injected | ❌ | ✅ Injected | ✅ Injected | ✅ Injected | ❌ | ❌ | ❌ | ❌ |
| **NPC Subnet** | ✅ Injected | ✅ Injected | ✅ Injected | ❌ | ❌ | ❌ | ✅ Injected | ❌ | ❌ |
| **Basic Subnet** | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected | ✅ Injected |

### Injection Logic (AP Breach / Unconscious NPC Breach)

**Implementation:** `ProgramInjection.reds` Line 73-175

```redscript
// Breach point type detection
isAccessPoint  = IsDefined(this.m_entity as AccessPoint)
isUnconsciousNPC = IsDefined(this.m_entity as ScriptedPuppet)
isNetrunner    = isUnconsciousNPC && IsNetrunnerPuppet()
isComputer     = !isAccessPoint && DaemonFilterUtils.IsComputer(devicePS)
isBackdoor     = !isAccessPoint && !isComputer && DaemonFilterUtils.IsRegularDevice(entity)

// Injection conditions (injected if included in conditional expression)
TURRETS: (isAccessPoint || isNetrunner)
  → Injected only during AP Breach or Netrunner NPC Breach

CAMERAS: (isAccessPoint || isComputer || isBackdoor || isNetrunner)
  → Injected during AP Breach, Computer RemoteBreach, Backdoor device, Netrunner NPC Breach

NPCs: (isAccessPoint || isUnconsciousNPC || isNetrunner)
  → Injected during AP Breach, Unconscious NPC Breach, Netrunner NPC Breach

BASIC: Always injected
```

**Important Implementation Constraints:**
- **`isComputer` is used for AP Breach from Computer devices** (reachable)
- **`isBackdoor` is used for AP Breach from regular devices** (reachable)
- In-game, you can interact directly with Computer/Terminal devices to initiate AP Breach
- AP Breach is also possible from regular devices like Camera/Door/Vending
- `isBackdoor` judgment uses different detection methods depending on implementation location:
  - **ProgramInjection**: `IsRegularDevice()` - Type-based detection (regular device like Camera/Door?)
  - **RadialBreach**: `IsConnectedToBackdoorDevice()` - Network connection state detection (actually via Backdoor?)
  - This difference is **intentional design** (different purposes and performance requirements)

**Conclusion:** `isComputer` and `isBackdoor` code are **normal code used in regular gameplay**

**Important:** Not all injected daemons are **necessarily displayed**
- Filtered based on network scan results according to `UnlockIfNoAccessPoint` setting
- Example: After Camera Subnet injection, it may be removed if no Cameras exist in the network

### Injection Logic (Remote Breach)

**Implementation:** `RemoteBreachAction_Device.reds`, `RemoteBreachAction_Vehicle.reds`

```redscript
// Remote Breach daemon injection is determined by target device type and RemoteBreach action class

Computer RemoteBreach (RemoteBreachAction_Computer.reds):
  → Computer → Camera/Basic injection (fixed: "camera,basic")

Device RemoteBreach (RemoteBreachAction_Device.reds):
  → Camera → Camera/Basic injection
  → Turret → Turret/Basic injection
  → Terminal → NPC/Basic injection
  → Other → Basic only injection

Vehicle RemoteBreach (RemoteBreachAction_Vehicle.reds):
  → Vehicle → Basic only injection
```

**Implementation Details:**
- **Computer RemoteBreach**: Dedicated class `RemoteBreachAction` for ComputerControllerPS (fixed daemon list)
- **Device RemoteBreach**: Dedicated class `DeviceRemoteBreachAction` for non-Computer/non-Vehicle devices (dynamic daemon detection via `GetAvailableDaemonsForDevice()`)
- **Vehicle RemoteBreach**: Dedicated class `VehicleRemoteBreachAction` for VehicleComponentPS

**Important:** Remote Breach does not use `isBackdoor` flag (direct device type detection via three separate action classes)

### Daemon Injection Design Philosophy

- **AP Breach:** Access rights to all subnets as network gateway
- **Unconscious NPC (Regular):** Limited access (NPC Subnet + Basic Subnet)
- **Unconscious NPC (Netrunner):** Full subnet access with Netrunner privileges
- **Computer RemoteBreach:** Fixed access (Camera Subnet + Basic Subnet)
- **Device RemoteBreach:** Restricted access based on target device type
  - Camera: Camera Subnet + Basic Subnet
  - Turret: Turret Subnet + Basic Subnet
  - Terminal: NPC Subnet + Basic Subnet
  - Other: Basic Subnet only
- **Vehicle RemoteBreach:** Minimum access (Basic Subnet only)

**Note:** `isBackdoor` judgment is implemented in ProgramInjection.reds and functions normally for AP Breach from Backdoor devices

---

## Program Filtering

### Filtering Application Order

**Injection-time Control (ProgramInjection.reds):**
- Backdoor device detection (Camera + Basic only injection)
- Device type availability check (injection control based on UnlockIfNoAccessPoint setting)
- Breach point type detection (AccessPoint/Computer/NPC/Netrunner)

**Filter-time Control (betterNetrunning.reds & ProgramFiltering.reds):**
```
1. ShouldRemoveBreachedPrograms() - Remove already breached daemons
2. ShouldRemoveNetworkPrograms() - Network connectivity filter
3. ShouldRemoveDeviceBackdoorPrograms() - Backdoor device restrictions
4. ShouldRemoveAccessPointPrograms() - Non-AccessPoint type program filter
5. ShouldRemoveNonNetrunnerPrograms() - Non-netrunner NPC restrictions
6. ShouldRemoveDeviceTypePrograms() - Device type availability filter
```

**Current Architecture:**
- **Injection-time control:** Backdoor device detection, device type availability detection, breach point type detection
- **Filter-time control:** Network state, user settings, breach state, device type filters
- **Benefits:** Performance improvement, code consistency, RadialBreach normal operation

**AccessPoint Type Programs:**
- All have `type = "MinigameAction.AccessPoint"` + `category = "MinigameAction.DataAccess"`
- NetworkLootShard (Shard)
- NetworkLootMaterials (Materials)
- NetworkLootMoney (Money)
- NetworkDataMineLootAll/Advanced/Master (Datamine V1/V2/V3) ← Added post-breach by BonusDaemonUtils
- NetworkLootQ003/MQ024/MQ015 etc. (Quest-specific)

### 1. Already-Breached Program Filter

**Implementation:** `betterNetrunning.reds` Line 86-91 / `ProgramFiltering.reds` `ShouldRemoveBreachedPrograms()`

**Description:** Removes programs for device types that have already been breached on the current network.

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Applied** | ✅ | ✅ | ✅ |
| **Removal Condition** | Device type already breached | Same | Same |
| **Removal Target** | Unlock programs for breached subnets | Same | Same |
| **Timing** | After vanilla `wrappedMethod()` | Same | Same |

**Breached State Flags:**
- `m_betterNetrunningBreachedBasic` - Basic subnet unlocked
- `m_betterNetrunningBreachedCameras` - Camera subnet unlocked
- `m_betterNetrunningBreachedTurrets` - Turret subnet unlocked
- `m_betterNetrunningBreachedNPCs` - NPC subnet unlocked

**Purpose:** Prevent duplicate unlock programs from appearing in subsequent breaches on the same network.

---

### 2. Non-AccessPoint Type Program Filter

**Implementation:** `ProgramFiltering.reds` `ShouldRemoveAccessPointPrograms()` Line 76

**Description:** Removes non-AccessPoint type programs (except Subnet type programs).

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Applied** | ✅ | ✅ | ❌ Always skipped |
| **Removal Condition** | `AllowAllDaemonsOnAccessPoints = false` | Same | `isRemoteBreach = true` → Always skipped |
| **Removal Target** | **Non-AccessPoint type programs**<br>(Subnet type programs are exception and displayed) | Same | - |

**Implementation Code:**
```redscript
// Remove non-access-point programs and non-subnet programs
return NotEquals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.AccessPoint)
    && !IsUnlockQuickhackAction(actionID);
```

**Important 1:** Remote Breach **completely bypasses** this filter due to `isRemoteBreach = true`

**Important 2:** Programs defined in Remote Breach are **all Subnet type programs**, so even if the filter were applied, the result would be the same (Subnet type programs are not removal targets)

**Setting Effects:**
```
AllowAllDaemonsOnAccessPoints = false (default):
  ✅ AccessPoint type programs: Displayed (Shard, Materials, Money, Quest-specific etc.)
  ❌ Non-AccessPoint type programs: Removed (except Subnet type programs)
  ✅ Subnet type programs: Always displayed

AllowAllDaemonsOnAccessPoints = true:
  ✅ All programs: Displayed (including AccessPoint type programs and non-AccessPoint type programs)
  ✅ Subnet type programs: Always displayed
```

---

### 3. RadialBreach Physical Range Filter

**Implementation:** `RadialBreach.reds` Line 169-196 / `ProgramInjection.reds` Line 98-106

**Operation:**
- **Injection-time control:** Control injection based on UnlockIfNoAccessPoint setting
- **RadialBreach integration:** Unlock devices within physical range based on injected programs

| Item | AP Breach | Unconscious NPC Breach<br>(Regular NPC) | Unconscious NPC Breach<br>(Netrunner) | Remote Breach<br>(Regular) | Remote Breach<br>(Netrunner NPC) |
|------|-----------|--------------------------|------------------------------|---------------------|------------------------------|
| **Applied** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Injection Strategy** | Depends on UnlockIfNoAccessPoint setting | Same | Same | - | Same |
| **RadialBreach** | Unlock physical range with successful programs | Same | Same | - | Same |

**Injection Strategy (ProgramInjection.reds):**
```
UnlockIfNoAccessPoint = true (Network priority):
  → Inject based on network scan results
  → Don't inject Camera Subnet if no Cameras exist

UnlockIfNoAccessPoint = false (RadialBreach priority):
  → Always inject (delegate physical range control to RadialBreach)
  → Inject Camera Subnet even if no Cameras exist
```

**RadialBreach Operation (RadialBreach.reds):**
1. After minigame success, retrieve successful programs
2. Unlock devices within physical range based on successful programs
3. Devices not on network can be controlled if within physical range

**Important:** Remote Breach basically **skips** physical range filter, except for **Netrunner NPC targets**

**Result:** Only devices within physical range can be breached

---

## Minigame Parameters

### Timer Multiplier

**Implementation:** `hackingMinigameUtils.script` Line 589

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Timer Multiplier** | 1.0x (standard) | **1.5x (50% increase)** | 1.0x (standard) |
| **Reason** | Normal breach | Time leeway with physical direct connection | Same difficulty even remotely |

**Implementation:** `hackingMinigameUtils.script` Line 589-591
```redscript
timerNotRemoteMultiplier = 1.5;
if( !( m_isRemoteBreach ) && m_isOfficerBreach ) {
    time *= timerNotRemoteMultiplier;  // Increase by 1.5x
}
```

### Minigame Configuration Source

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Configuration Source** | NetworkTDBID | Character Record<br>`characterRecord.MinigameInstance()` | NetworkTDBID<br>(Registered in TweakDB via remoteBreach.lua) |
| **Difficulty** | Target's PowerLevel | Target NPC's record definition | Target's PowerLevel |

### RAM Cost

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **RAM Cost** | ❌ None | ❌ None | ✅ Yes (configurable) |
| **Cost Calculation** | - | - | `RemoteBreachRAMCostPercent` × Max RAM |
| **Default** | - | - | 35% |

---

## Post-Breach Processing

### Bonus Daemon Auto-Add

**Implementation:** `BonusDaemonUtils.reds` `ApplyBonusDaemons()`

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Auto PING** | ✅ Implemented | ✅ Implemented | ✅ Implemented |
| **Auto Datamine** | ✅ Implemented | ✅ Implemented | ✅ Implemented |
| **Application Conditions** | `AutoExecutePingOnSuccess = true`<br>`AutoDatamineBySuccessCount = true` | Same | Same |

**Implementation Locations:**
- ✅ `BreachProcessing.reds` (AP Breach) - Calls BonusDaemonUtils.ApplyBonusDaemons()
- ✅ `NPCLifecycle.reds` (Unconscious NPC Breach) - Calls BonusDaemonUtils.ApplyBonusDaemons()
- ✅ `RemoteBreachNetworkUnlock.reds` (Remote Breach) - Calls BonusDaemonUtils.ApplyBonusDaemons()

### Auto PING Operation

```
Condition: AutoExecutePingOnSuccess = true
Operation:
  - Any daemon succeeds
  - PING not yet uploaded
  → Automatically add and execute PING (silent execution)
```

### Auto Datamine Operation

**Implementation:** `BonusDaemonUtils.reds` `ApplyDatamineBasedOnSuccessCount()`

```
Condition: AutoDatamineBySuccessCount = true
Operation:
  - Count successful daemons (excluding Datamine itself)
  - Datamine not yet uploaded
  → Automatically add and execute based on success count
    - 1 success → Datamine V1 (NetworkDataMineLootAll)
    - 2 successes → Datamine V2 (NetworkDataMineLootAdvanced)
    - 3+ successes → Datamine V3 (NetworkDataMineLootMaster)
```

**Important:** Datamine programs are NOT displayed during minigame. They are added POST-breach based on success count.

**Setting Effects:**
```
AutoDatamineBySuccessCount = true (default):
  - Datamine NOT visible during minigame
  - Auto-added after breach based on success count

AutoDatamineBySuccessCount = false:
  - Datamine NOT visible during minigame (TweakDB not defined)
  - No auto-add after breach
```

### Network Unlock

| Item | AP Breach | Unconscious NPC Breach | Remote Breach |
|------|-----------|------------------------|---------------|
| **Unlock Range** | Entire network | Entire network | Entire network + Nearby standalone devices |
| **Subnet Progression** | ✅ Individual management of Turret/Camera/NPC subnets | ✅ Same | ✅ Same |
| **Breached State Sharing** | ✅ | ✅ | ✅ |
| **Nearby Device Unlock** | ❌ | ❌ | ✅ Auto-unlock standalone devices within 50m |

**Shared Flags:**
- `m_betterNetrunningBreachedBasic`
- `m_betterNetrunningBreachedCameras`
- `m_betterNetrunningBreachedTurrets`
- `m_betterNetrunningBreachedNPCs`

**Remote Breach Enhancement:**

After Remote Breach success, nearby standalone devices are automatically unlocked:

```
Implementation: RemoteBreachNetworkUnlock.reds
  ├─ UnlockNearbyStandaloneDevices() - Main logic
  ├─ FindNearbyDevices() - Search within 50m radius
  ├─ UnlockStandaloneDevices() - Filter standalone + unlock
  └─ UnlockSingleDevice() - Device-type-specific unlock
```

**Unlock Criteria:**
- Device within 50m radius of breach position
- No AccessPoints (standalone device)
- Device type determines breach flag:
  - Camera → `m_betterNetrunningBreachedCameras`
  - Turret → `m_betterNetrunningBreachedTurrets`
  - Other → `m_betterNetrunningBreachedBasic`

**Important:** AP Breach, Remote Breach, and Unconscious NPC Breach **share the same network's breached state**

---

## Settings Control

### Settings Affecting Each Breach Type

| Setting | AP Breach | Unconscious NPC Breach | Remote Breach | Default Value |
|---------|-----------|------------------------|---------------|---------------|
| **EnableClassicMode** | ✅ No injection when Classic enabled | ✅ Same | ✅ Same | `false` |
| **AllowBreachingUnconsciousNPCs** | ❌ | ✅ Disable with false | ❌ | `true` |
| **UnlockIfNoAccessPoint** | ✅ RadialBreach enabled with false | ✅ Affects activation conditions | ✅ Enabled with false | `false` |
| **AutoDatamineBySuccessCount** | ✅ Remove Datamine + auto-add with true | ✅ Same | ✅ Same | `true` |
| **AutoExecutePingOnSuccess** | ✅ Auto-add PING with true | ✅ Same | ✅ Same | `true` |
| **AllowAllDaemonsOnAccessPoints** | ✅ Display all programs with true | ✅ Same | ⚠️ No practical effect (all Subnet type programs) | `false` |
| **RemoteBreachEnabledComputer** | ❌ | ❌ | ✅ Control Computer Device RemoteBreach | `true` |
| **RemoteBreachEnabledCamera** | ❌ | ❌ | ✅ Control Camera Device RemoteBreach | `true` |
| **RemoteBreachEnabledTurret** | ❌ | ❌ | ✅ Control Turret Device RemoteBreach | `true` |
| **RemoteBreachEnabledDevice** | ❌ | ❌ | ✅ Control non-Computer/Camera/Turret Device RemoteBreach | `true` |
| **RemoteBreachEnabledVehicle** | ❌ | ❌ | ✅ Control Vehicle RemoteBreach | `true` |
| **RemoteBreachRAMCostPercent** | ❌ | ❌ | ✅ Control RAM cost | `35` |

### Detailed Settings Explanation

#### EnableClassicMode
```
false (default): Progressive Mode
  - Better Netrunning's daemon injection system enabled
  - Subnet progression system enabled

true: Classic Mode
  - Vanilla behavior
  - No Better Netrunning injection
```

#### AllowBreachingUnconsciousNPCs
```
true (default): Unconscious NPC Breach enabled
false: Unconscious NPC Breach disabled
```

#### UnlockIfNoAccessPoint
```
false (default): RadialUnlock Mode enabled
  - RadialBreach: Enabled (physical range-based)
  - RemoteBreach: Enabled
  - Standalone devices: Breach required

true: RadialUnlock Mode disabled
  - RadialBreach: Disabled
  - RemoteBreach: Disabled
  - Standalone devices: Auto-unlock
```

#### AutoDatamineBySuccessCount
```
true (default):
  All breach types:
    - During minigame: Datamine programs NOT visible (not defined in TweakDB)
    - After breach success: Auto-add based on daemon success count
      * 1 success → Datamine V1
      * 2 successes → Datamine V2
      * 3+ successes → Datamine V3

false:
  - During minigame: Datamine programs NOT visible (not defined in TweakDB)
  - After breach success: No auto-add

Note: Datamine is NEVER displayed during minigame regardless of this setting.
      This setting only controls POST-breach auto-add behavior.
```

#### AutoExecutePingOnSuccess

```
true (default):
  All breach types:
    - On daemon success: Auto-add and execute PING

false:
  - No auto-add
```

#### AllowAllDaemonsOnAccessPoints

```
false (default):
  AP Breach / Unconscious NPC Breach:
    - AccessPoint type programs: Displayed (Shard, Materials, Money, Quest-specific)
    - Non-AccessPoint type programs: Removed (except Subnet type programs)
    - Subnet type programs: Always displayed

  Remote Breach:
    - Filter is bypassed (isRemoteBreach = true)
    - All programs are Subnet type, so no practical effect

true:
  AP Breach / Unconscious NPC Breach:
    - All programs: Displayed (including AccessPoint and non-AccessPoint types)
    - Subnet type programs: Always displayed

  Remote Breach:
    - No change (already all displayed)
```
```

---

## Processing Flow Comparison

### AP Breach

```
1. AccessPoint Interaction
   ↓
2. NetworkBlackboard Setup
   - RemoteBreach = false
   - OfficerBreach = false
   ↓
3. InjectBetterNetrunningPrograms()
   - isAccessPoint = true
   - Inject Turret/Camera/NPC/Basic
   ↓
4. FilterPlayerPrograms()
   ├─ Already breached filter
   ├─ Network connection filter
   ├─ Backdoor filter (skip)
   ├─ AccessPoint type program filter
   │   └─ AutoDatamineBySuccessCount = true → Remove V1/V2/V3
   ├─ Non-AccessPoint type program filter
   │   └─ AllowAllDaemonsOnAccessPoints = false
   │       → Remove non-AccessPoint type programs (except Subnet type programs)
   ├─ Non-Netrunner NPC filter (skip)
   └─ Device type filter
       └─ Check network device existence
   ↓
5. RadialBreach.FilterPlayerPrograms()
   └─ UnlockIfNoAccessPoint = false
       → Re-add only devices within physical range
   ↓
6. Start Minigame (standard timer)
   ↓
7. Player Operation (daemon upload)
   ↓
8. Breach Success
   ↓
9. BonusDaemonUtils.ApplyBonusDaemons()
   ├─ AutoExecutePingOnSuccess = true → Add PING
   └─ AutoDatamineBySuccessCount = true → Add Datamine V1/V2/V3
   ↓
10. Network Unlock
```

---

### Unconscious NPC Breach (Regular NPC)

```
1. Unconscious NPC Interaction
   ↓
2. Activation Condition Check
   - AllowBreachingUnconsciousNPCs = true
   - IsConnectedToAccessPoint() = true
   - RadialUnlock Mode enabled OR physical AP connection
   - Not directly breached
   ↓
3. NetworkBlackboard Setup
   - RemoteBreach = false
   - OfficerBreach = true
   ↓
4. InjectBetterNetrunningPrograms()
   - isUnconsciousNPC = true
   - isNetrunner = false
   - Inject NPC/Basic only
   ↓
5. FilterPlayerPrograms()
   ├─ Already breached filter
   ├─ Network connection filter
   ├─ Backdoor filter (skip)
   ├─ AccessPoint type program filter
   │   └─ AutoDatamineBySuccessCount = true → Remove V1/V2/V3
   ├─ Non-AccessPoint type program filter
   │   └─ AllowAllDaemonsOnAccessPoints = false
   │       → Remove non-AccessPoint type programs (except Subnet type programs)
   ├─ Non-Netrunner NPC filter (skip)
   └─ Device type filter
       └─ Check network device existence
   ↓
6. RadialBreach.FilterPlayerPrograms()
   └─ UnlockIfNoAccessPoint = false
       → Re-add only devices within physical range
   ↓
7. Start Minigame (timer increase: timerNotRemoteMultiplier)
   ↓
8. Player Operation (daemon upload)
   ↓
9. Breach Success
   ↓
10. BonusDaemonUtils.ApplyBonusDaemons()
   ├─ AutoExecutePingOnSuccess = true → Add PING
   └─ AutoDatamineBySuccessCount = true → Add Datamine V1/V2/V3
   ↓
11. Network Unlock
```

---

### Remote Breach (Device)

```
1. RemoteBreach Quickhack on Device
   ↓
2. Activation Condition Check (setting branches by device type)
   - Computer: RemoteBreachEnabledComputer = true
   - Camera: RemoteBreachEnabledCamera = true
   - Turret: RemoteBreachEnabledTurret = true
   - Other: RemoteBreachEnabledDevice = true
   - RadialUnlock Mode enabled (UnlockIfNoAccessPoint = false)
   - Target connected to network
   - Not breached
   ↓
3. remoteBreach.lua
   - Register static program list to TweakDB
   ↓
4. NetworkBlackboard Setup
   - RemoteBreach = true
   - OfficerBreach = false
   ↓
5. InjectBetterNetrunningPrograms()
   - Determine daemon injection pattern by device type detection
   - Inject Turret/Camera/NPC/Basic
   ↓
6. FilterPlayerPrograms()
   ├─ Already breached filter
   ├─ Network connection filter
   ├─ Backdoor filter (skip)
   ├─ AccessPoint type program filter
   │   └─ AutoDatamineBySuccessCount = true → Remove V1/V2/V3
   ├─ Non-AccessPoint type program filter (skip)
   │   └─ isRemoteBreach = true → Always display all
   ├─ Non-Netrunner NPC filter (skip - Computer target)
   └─ Device type filter
       └─ Check network device existence
   ↓
7. RadialBreach.FilterPlayerPrograms()
   └─ isRemoteBreach = true → Early return (skip)
   ↓
8. Start Minigame (standard timer)
   ↓
9. Player Operation (daemon upload)
   ↓
10. Breach Success
   ↓
11. BonusDaemonUtils.ApplyBonusDaemons()
   ├─ AutoExecutePingOnSuccess = true → Add PING
   └─ AutoDatamineBySuccessCount = true → Add Datamine V1/V2/V3
   ↓
12. Network Unlock
```

---

## Processing Timing Details

### Filter Processing Stages

Better Netrunning Mod filters programs at **three stages**:

#### Stage 1: Injection-time Control (ProgramInjection.reds)
```
Timing: When injecting programs into network
Control:
  - Backdoor device detection
  - Device type availability check
  - Breach point type detection
Purpose: Optimize injected daemons, minimize filtering overhead
```

#### Stage 2: Filter-time Control (betterNetrunning.reds & ProgramFiltering.reds)
```
Timing: Before minigame start (after vanilla wrappedMethod)
Control:
  1. Already breached daemon removal (ShouldRemoveBreachedPrograms)
  2. Network connectivity filter (ShouldRemoveNetworkPrograms)
  3. Backdoor device restrictions (ShouldRemoveDeviceBackdoorPrograms)
  4. Non-AccessPoint type program filter (ShouldRemoveAccessPointPrograms)
  5. Non-netrunner NPC restrictions (ShouldRemoveNonNetrunnerPrograms)
  6. Device type availability filter (ShouldRemoveDeviceTypePrograms)
Purpose: Filter based on user settings, network state, and breach state
```

#### Stage 3: RadialBreach Control (RadialBreach.reds)
```
Timing: Before minigame start (after Stage 2)
Control:
  - Physical range-based filtering
  - Re-add only devices within physical range
Purpose: Control based on physical distance (UnlockIfNoAccessPoint setting)
```

---

## Key Functional Differences Summary

### 1. Activation Conditions

| Breach Type | Requirement | Special Conditions |
|-------------|-------------|-------------------|
| **AP Breach** | AccessPoint entity | None |
| **Unconscious NPC Breach** | Unconscious NPC + Network connection (relaxed) | `AllowBreachingUnconsciousNPCs = true`<br>RadialUnlock Mode enabled |
| **Remote Breach** | Any scannable device (network relaxed) | Device-specific RemoteBreachEnabled settings<br>RadialUnlock Mode enabled<br>`DeviceNetworkAccess.reds` provides universal access |

**Network Access Relaxation:**
- `DeviceNetworkAccess.reds` removes network topology restrictions
- `IsConnectedToBackdoorDevice()` always returns true for standalone devices
- `HasNetworkBackdoor()` always returns true for all devices
- This enables RemoteBreach and QuickHack access regardless of AP connection

---

### 2. Daemon Injection Patterns

| Breach Type | Turret Subnet | Camera Subnet | NPC Subnet | Basic Subnet |
|-------------|--------------|--------------|-----------|-------------|
| **AP Breach** | ✅ | ✅ | ✅ | ✅ |
| **Unconscious NPC (Regular)** | ❌ | ❌ | ✅ | ✅ |
| **Unconscious NPC (Netrunner)** | ✅ | ✅ | ✅ | ✅ |
| **Remote (Computer)** | ❌ | ✅ | ❌ | ✅ |
| **Remote (Camera)** | ❌ | ✅ | ❌ | ✅ |
| **Remote (Turret)** | ✅ | ❌ | ❌ | ✅ |
| **Remote (Terminal)** | ❌ | ❌ | ✅ | ✅ |
| **Remote (Other Device)** | ❌ | ❌ | ❌ | ✅ |
| **Remote (Vehicle)** | ❌ | ❌ | ❌ | ✅ |

---

### 3. Filter Application

| Filter Type | AP Breach | Unconscious NPC Breach | Remote Breach |
|------------|-----------|------------------------|---------------|
| **Already-Breached Filter** | ✅ Applied | ✅ Applied | ✅ Applied |
| **Network Connectivity Filter** | ✅ Applied | ✅ Applied | ✅ Applied |
| **Backdoor Device Filter** | ✅ Applied | ✅ Applied | ✅ Applied |
| **Non-AccessPoint Program Filter** | ✅ Applied | ✅ Applied | ❌ Skipped |
| **Non-Netrunner NPC Filter** | ❌ N/A | ⚠️ Applied (if remote) | ⚠️ Applied (if NPC target) |
| **Device Type Filter** | ✅ Applied | ✅ Applied | ✅ Applied |
| **RadialBreach Physical Range Filter** | ✅ Applied | ✅ Applied | ❌ Skipped (except Netrunner NPC) |

**Note on Datamine:** Datamine programs are NOT filtered because they are NOT present during minigame. They are added POST-breach by `BonusDaemonUtils.reds`.

---

### 4. Minigame Parameters

| Parameter | AP Breach | Unconscious NPC Breach | Remote Breach |
|-----------|-----------|------------------------|---------------|
| **Timer** | 1.0x | **1.5x** | 1.0x |
| **RAM Cost** | ❌ None | ❌ None | ✅ Yes (35% default) |
| **Configuration Source** | NetworkTDBID | Character Record | TweakDB (remoteBreach.lua) |

---

### 5. Post-Breach Processing

All breach types support:
- ✅ Auto PING (`AutoExecutePingOnSuccess = true`)
- ✅ Auto Datamine (`AutoDatamineBySuccessCount = true`)
- ✅ Network unlock
- ✅ Breached state sharing

**Remote Breach Enhancement:**
- ✅ Auto-unlock nearby standalone devices within 50m radius
- ✅ Device-type-specific breach flag assignment
- ✅ Integration with RadialUnlock system

**Implementation:**
- `RemoteBreachNetworkUnlock.reds` - Extract Method pattern with shallow nesting
- Nesting depth: Maximum 3 levels
- Modular design: 4 separate helper methods for maintainability

---

## Related Documents

- `ARCHITECTURE_DESIGN.md` - Better Netrunning overall architecture
- Source files:
  - `DeviceNetworkAccess.reds` - Network access relaxation
  - `RemoteBreachNetworkUnlock.reds` - Network unlock with nearby device support
  - `BonusDaemonUtils.reds` - Auto PING/Datamine
  - `DeviceQuickhacks.reds` - Progressive unlock with diagnostic logging
  - `NPCLifecycle.reds` - Unconscious NPC breach
  - `ProgramInjection.reds` - Daemon injection logic
  - `ProgramFiltering.reds` - Daemon filtering logic

---

**Last Updated:** 2025-10-11
