# Better Netrunning - Architecture Design Document

**Version:** 1.4
**Last Updated:** 2025-10-11

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Module Structure](#module-structure)
4. [Core Subsystems](#core-subsystems)
5. [Data Flow](#data-flow)
6. [Design Patterns](#design-patterns)
7. [Configuration System](#configuration-system)
8. [Extension Points](#extension-points)
9. [Performance Considerations](#performance-considerations)

---

## Overview

### Purpose

Better Netrunning is a comprehensive Cyberpunk 2077 mod that enhances the netrunning gameplay by introducing progressive subnet unlocking, remote breach capabilities, and granular device control.

### Key Features

- **Progressive Subnet System:** Unlock Camera/Turret/NPC subnets independently
- **Remote Breach:** Breach devices (Computer/Camera/Turret/Device/Vehicle) without physical Access Points
- **Unconscious NPC Breach:** Breach unconscious NPCs directly
- **RadialUnlock Integration:** 50m radius breach tracking for standalone devices
- **Granular Control:** Per-device-type RemoteBreach toggles
- **Auto-Daemon System:** Automatic PING and Datamine execution based on success count

### Technology Stack

- **Language:** REDscript (Cyberpunk 2077 scripting language)
- **Framework:** CustomHackingSystem (HackingExtensions) - Required for RemoteBreach functionality
- **Configuration:** CET (Cyber Engine Tweaks) + Native Settings UI
- **Localization:** WolvenKit JSON format

**IMPORTANT:** Better Netrunning requires the CustomHackingSystem mod (HackingExtensions). All RemoteBreach-related code is wrapped with `@if(ModuleExists("HackingExtensions"))` conditions and will not compile without this dependency.

---

## System Architecture

### Architectural Philosophy

Better Netrunning follows a **modular, layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface Layer                     │
│  (Native Settings UI, Quickhack Actions, Breach Minigame)  │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Coordination Layer                        │
│          (betterNetrunning.reds - Entry Point)              │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────┬──────────────┬──────────────┬───────────────┐
│  Breach      │  Quickhacks  │  Custom      │  RadialUnlock │
│  Protocol    │  System      │  Hacking     │  System       │
│  (Minigame)  │  (NPCs/Dev)  │  (Remote)    │  (50m radius) │
└──────────────┴──────────────┴──────────────┴───────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Common Utilities Layer                   │
│  (Device Type Detection, Daemon Utils, Progression, etc.)  │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Configuration Layer                       │
│             (config.reds + CET + Settings UI)               │
└─────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Single Responsibility Principle:** Each module handles one specific concern
2. **DRY (Don't Repeat Yourself):** Shared logic consolidated into utility modules
3. **Strategy Pattern:** Device-specific unlock strategies encapsulated in separate classes
4. **Composed Method Pattern:** Large functions decomposed into small, focused helpers
5. **Mod Compatibility:** Prioritize `@wrapMethod` over `@replaceMethod`
6. **Early Return Pattern:** Reduce nesting depth for better readability
7. **Template Method Pattern:** Consistent processing workflows across subsystems

---

## Module Structure

### Directory Layout

```
r6/scripts/BetterNetrunning/
│
├── betterNetrunning.reds              (195 lines) - Main entry point
├── config.reds                        (62 lines)  - Configuration settings
│
├── Breach/                            (340 lines total)
│   ├── BreachProcessing.reds          (218 lines) - Breach completion, RefreshSlaves
│   └── BreachHelpers.reds             (122 lines) - Network hierarchy, status checks
│
├── Common/                            (687 lines total)
│   ├── BonusDaemonUtils.reds          (119 lines) - Auto PING/Datamine
│   ├── DaemonUtils.reds               (194 lines) - Daemon type identification
│   ├── DeviceTypeUtils.reds           (178 lines) - Device type detection + Breach state management
│   ├── DNRGating.reds                 (87 lines)  - Daemon Netrunning Revamp integration
│   ├── Events.reds                    (93 lines)  - Breach event definitions
│   └── Logger.reds                    (16 lines)  - Debug logging (BNLog)
│
├── CustomHacking/                     (2,001 lines total)
│   ├── DaemonImplementation.reds      (184 lines) - Daemon execution logic
│   ├── DaemonRegistration.reds        (73 lines)  - TweakDB daemon registration
│   ├── DaemonUnlockStrategy.reds      (339 lines) - Strategy pattern implementations
│   ├── RemoteBreachAction_Computer.reds (86 lines) - Computer RemoteBreach
│   ├── RemoteBreachAction_Device.reds (103 lines) - Device RemoteBreach (Camera/Turret/Terminal/Other)
│   ├── RemoteBreachAction_Vehicle.reds (85 lines) - Vehicle RemoteBreach
│   ├── RemoteBreachProgram.reds       (141 lines) - Daemon program definitions
│   ├── RemoteBreachSystem.reds        (732 lines) - RemoteBreach state management (BaseRemoteBreachAction, StateSystems)
│   └── RemoteBreachVisibility.reds    (258 lines) - Visibility control + settings
│
├── Devices/                           (625 lines total)
│   ├── CameraExtensions.reds          (88 lines)  - Camera quickhack extensions
│   ├── DeviceNetworkAccess.reds       (70 lines)  - Network access relaxation
│   ├── DeviceQuickhacks.reds          (366 lines) - Progressive unlock, finalization, diagnostic logging
│   └── TurretExtensions.reds          (101 lines) - Turret quickhack extensions
│
├── Minigame/                          (309 lines total)
│   ├── ProgramFiltering.reds          (197 lines) - Daemon filtering logic
│   └── ProgramInjection.reds          (112 lines) - Subnet program injection
│
├── NPCs/                              (298 lines total)
│   ├── NPCQuickhacks.reds             (194 lines) - Progressive unlock, permissions
│   └── NPCLifecycle.reds              (104 lines) - Unconscious breach, lifecycle
│
├── Progression/                       (213 lines total)
│   └── ProgressionSystem.reds         (213 lines) - Cyberdeck, Intelligence, Rarity
│
└── RadialUnlock/                      (1,142 lines total)
    ├── RadialBreachGating.reds        (295 lines) - RadialBreach MOD integration
    ├── RadialUnlockSystem.reds        (283 lines) - Position-based breach tracking
    └── RemoteBreachNetworkUnlock.reds (564 lines) - Network unlock + Nearby device unlock

TOTAL: 31 files, ~5,870 lines
```

### Module Dependencies

```
betterNetrunning.reds (Entry Point)
    ├── imports Common.*
    ├── imports CustomHacking.*
    ├── imports Minigame.*
    ├── imports Progression.*
    ├── imports RadialUnlock.*
    └── imports BetterNetrunningConfig.*

Breach/ modules
    └── depends on Common.* (DeviceTypeUtils, Events)

CustomHacking/ modules
    ├── depends on Common.* (DaemonUtils, DeviceTypeUtils, BonusDaemonUtils)
    └── depends on config.reds (Settings)

Devices/ modules
    ├── depends on Common.* (DeviceTypeUtils, DaemonUtils)
    └── depends on Progression.* (ProgressionSystem)

Minigame/ modules
    └── depends on Common.* (DaemonUtils, DNRGating)

NPCs/ modules
    ├── depends on Common.* (DeviceTypeUtils, BonusDaemonUtils)
    └── depends on Progression.* (ProgressionSystem)

RadialUnlock/ modules
    └── depends on Common.* (BonusDaemonUtils, DeviceTypeUtils)
```

---

## Core Subsystems

### 1. Breach Protocol System (Minigame)

**Purpose:** Controls daemon availability and filtering in Breach Protocol minigames

**Key Components:**
- `ProgramInjection.reds`: Inject subnet daemons based on breach point type
- `ProgramFiltering.reds`: Filter daemons based on user settings and breach state
- `BreachProcessing.reds`: Handle breach completion and network unlocking
- `BreachHelpers.reds`: Network hierarchy traversal and status checks

**Breach Point Types:**

| Type | Daemon Injection | Features |
|------|------------------|----------|
| **Access Point** | Turret + Camera + NPC + Basic | Full network access |
| **Computer** | Camera + Basic | Limited network access |
| **Backdoor Device** | Camera + Basic | Camera subnet + basics only |
| **Unconscious NPC (Regular)** | NPC + Basic | Limited access |
| **Unconscious NPC (Netrunner)** | Turret + Camera + NPC + Basic | Full network access |
| **Remote Breach (Computer)** | Camera + Basic | Device-specific daemons |
| **Remote Breach (Camera)** | Camera + Basic | Device-specific daemons |
| **Remote Breach (Turret)** | Turret + Basic | Device-specific daemons |
| **Remote Breach (Terminal)** | NPC + Basic | Device-specific daemons |
| **Remote Breach (Other)** | Basic only | Minimum access |
| **Remote Breach (Vehicle)** | Basic only | Minimum access |

**Filtering Pipeline:**

```
1. ProgramInjection (Injection-time control)
   ├─ Breach point type detection (AccessPoint/Computer/Backdoor/NPC)
   ├─ Device type availability check (UnlockIfNoAccessPoint setting)
   └─ Progressive unlock state check (m_betterNetrunningBreached* flags)

2. ProgramFiltering (Filter-time control)
   ├─ ShouldRemoveBreachedPrograms() - Remove already breached daemons
   ├─ ShouldRemoveDataminePrograms() - Datamine removal (AutoDatamineBySuccessCount)
   └─ ShouldRemoveNonAccessPointPrograms() - Non-AP programs (AllowAllDaemonsOnAccessPoints)

3. RadialBreach (Physical range control)
   └─ Re-add only devices within 50m radius (UnlockIfNoAccessPoint = false)
```

### 2. Remote Breach System (CustomHacking)

**Purpose:** Enable breaching devices remotely without physical Access Points

**DEPENDENCY:** All RemoteBreach functionality requires CustomHackingSystem (HackingExtensions mod). Code is wrapped with `@if(ModuleExists("HackingExtensions"))` conditions.

**Key Components:**
- `RemoteBreachAction_Computer.reds`: Computer RemoteBreach (ComputerControllerPS)
- `RemoteBreachAction_Device.reds`: Device RemoteBreach (Camera/Turret/Terminal/Other, excludes Computer/Vehicle)
- `RemoteBreachAction_Vehicle.reds`: Vehicle RemoteBreach (VehicleComponentPS)
- `RemoteBreachSystem.reds`: State management + BaseRemoteBreachAction base class
  - `RemoteBreachStateSystem`: Computer breach state
  - `DeviceRemoteBreachStateSystem`: Device breach state
  - `VehicleRemoteBreachStateSystem`: Vehicle breach state
- `RemoteBreachVisibility.reds`: Visibility control + settings-based toggles
- `RemoteBreachProgram.reds`: Daemon program definitions
- `DaemonRegistration.reds`: Register 8 daemon actions with CustomHackingSystem
- `DaemonImplementation.reds`: Daemon execution logic (4 Device + 4 Vehicle daemons)
- `RemoteBreachNetworkUnlock.reds`: Network unlock after breach success

**RemoteBreach Action Architecture:**

```
BaseRemoteBreachAction (RemoteBreachSystem.reds)
  extends CustomAccessBreach (HackingExtensions)
  ├─ RemoteBreachAction (Computer)    → ComputerControllerPS
  ├─ DeviceRemoteBreachAction          → Camera/Turret/Terminal/Other
  └─ VehicleRemoteBreachAction         → VehicleComponentPS
```

**Device-Specific Daemon Injection:**

```redscript
// Computer (RemoteBreachAction_Computer.reds)
Computer  → "basic,camera"  (Camera + Basic daemons)

// Device (RemoteBreachAction_Device.reds: GetAvailableDaemonsForDevice())
Camera    → "basic,camera"  (Camera + Basic daemons)
Turret    → "basic,turret"  (Turret + Basic daemons)
Terminal  → "basic,npc"     (NPC + Basic daemons)
Other     → "basic"         (Basic daemon only)

// Vehicle (RemoteBreachAction_Vehicle.reds)
Vehicle   → "basic"         (Basic daemon only)
```

**Visibility Control (Two-Layer Defense):**

1. **Prevention Layer:** `RemoteBreachVisibility.reds` - `TryAddCustomRemoteBreach()`
   - Early return if RemoteBreachEnabled setting = false
   - Early return if UnlockIfNoAccessPoint = true (auto-unlock mode)

2. **Enforcement Layer:** `RemoteBreachAction_*.reds` - `GetQuickHackActions()` @wrapMethod
   - Check device-specific RemoteBreachEnabled setting
   - Check UnlockIfNoAccessPoint setting (OR condition)

**State Management:**

- `DeviceRemoteBreachStateSystem`: Manages Device RemoteBreach state
  - Tracks current target device
  - Stores available daemon list per device type
  - Handles device-specific minigame definitions

- `VehicleRemoteBreachStateSystem`: Manages Vehicle RemoteBreach state
  - Separate state system for vehicles
  - Always "basic" daemon only

### 3. Device Management & Network Access

**Purpose:** Control device quickhack availability and network access

**Key Components:**
- `DeviceQuickhacks.reds`: Progressive unlock, action finalization, diagnostic logging
- `DeviceNetworkAccess.reds`: Network access relaxation
- `TurretExtensions.reds`: Turret-specific extensions
- `CameraExtensions.reds`: Camera-specific extensions

**Network Access Relaxation (DeviceNetworkAccess.reds):**

Removes vanilla network topology restrictions:

1. **Door QuickHack Menu:** All doors show menu (not just AP-connected)
2. **Standalone RemoteBreach:** Standalone devices can use RemoteBreach
3. **Universal Ping:** Ping works on all devices for reconnaissance

**Implementation:**
- `ExposeQuickHakcsIfNotConnnectedToAP()` - Returns true for non-AP doors (@wrapMethod)
- `IsConnectedToBackdoorDevice()` - Returns true for standalone devices (@wrapMethod)
- `HasNetworkBackdoor()` - Always returns true (@replaceMethod)

**Philosophy:** Player-driven gameplay without arbitrary network limitations

### 4. Quickhack System (Progressive Unlock)

**Purpose:** Control quickhack availability based on subnet breach state

**Key Components:**
- `DeviceQuickhacks.reds`: Camera/Turret progressive unlock, remote action execution
- `TurretExtensions.reds`: Turret-specific quickhack extensions
- `CameraExtensions.reds`: Camera-specific quickhack extensions
- `NPCQuickhacks.reds`: NPC quickhack progressive unlock, permission calculation
- `NPCLifecycle.reds`: Unconscious NPC breach, lifecycle management

**Progressive Unlock Logic:**

```
Device Quickhacks:
  Cameras   → Unlocked when Camera Subnet breached
  Turrets   → Unlocked when Turret Subnet breached
  Doors     → Unlocked when Basic Subnet breached
  Terminals → Unlocked when Basic Subnet breached

NPC Quickhacks:
  Covert    → Unlocked when NPC Subnet breached (low-risk hacks)
  Combat    → Unlocked when NPC Subnet breached (combat hacks)
  Control   → Unlocked when NPC Subnet breached (control hacks)
  Ultimate  → Unlocked when NPC Subnet breached (ultimate hacks)
```

**Breach State Flags (Shared across all breach types):**

```redscript
// SharedGameplayPS extension fields (Events.reds)

m_betterNetrunningBreachedBasic   : Bool  // Basic subnet breached
m_betterNetrunningBreachedCameras : Bool  // Camera subnet breached
m_betterNetrunningBreachedTurrets : Bool  // Turret subnet breached
m_betterNetrunningBreachedNPCs    : Bool  // NPC subnet breached
```

### 5. RadialUnlock System

**Purpose:** Track breach positions and unlock standalone devices within 50m radius

**Key Components:**
- `RadialUnlockSystem.reds`: Position-based breach tracking system
- `RadialBreachGating.reds`: RadialBreach MOD integration
- `RemoteBreachNetworkUnlock.reds`: Network unlock + Nearby device unlock

**Functionality:**

1. **Breach Position Tracking:**
   - Store breach coordinates when minigame succeeds
   - Track breached Access Point entity references
   - Prevent duplicate RemoteBreach on unlocked devices

2. **50m Radius Unlock:**
   - Check distance from breach position to target device
   - Unlock standalone devices (no AP connection) within radius
   - Filter daemons to show only physically reachable devices

3. **RadialBreach MOD Integration:**
   - Detect RadialBreach MOD presence via `@if(ModuleExists("RadialBreach"))`
   - Delegate physical distance calculations to RadialBreach
   - Fallback to internal logic if not installed

4. **Nearby Standalone Device Unlock:**
   - Auto-unlock nearby standalone devices after RemoteBreach success
   - Architecture (Extract Method pattern):
     ```
     UnlockNearbyStandaloneDevices()  ← Main orchestration
     ├─ FindNearbyDevices()            ← TargetingSystem search (50m)
     ├─ UnlockStandaloneDevices()      ← Filter + bulk unlock
     └─ UnlockSingleDevice()           ← Type-specific flag setting
     ```
   - Benefits: Shallow nesting (max 3 levels), high maintainability
   - Device types: Camera → `m_betterNetrunningBreachedCameras`, Turret → `m_betterNetrunningBreachedTurrets`, Other → `m_betterNetrunningBreachedBasic`
   - Delegate standalone device unlock to RadialBreach when available
   - Fallback to internal logic if RadialBreach not installed

**Activation Condition:**

```
UnlockIfNoAccessPoint = false (default):
  → RadialUnlock Mode ENABLED
  → RadialBreach controls device unlocking via physical proximity
  → RemoteBreach enabled

UnlockIfNoAccessPoint = true:
  → RadialUnlock Mode DISABLED
  → Standalone devices auto-unlock (no breach required)
  → RemoteBreach disabled
```

### 6. Common Utilities

**Purpose:** Provide shared functionality across all subsystems

**Key Modules:**

#### DeviceTypeUtils (178 lines)
- Device type classification (Camera/Turret/Computer/Basic)
- Breach flag management (IsBreached, SetBreached, GetBreachFlag)
- Device unlock logic (ApplyDeviceTypeUnlock)
- Permission calculation helpers
- Data structures (DeviceBreachInfo, DevicePermissions, NPCHackPermissions, BreachUnlockFlags)

#### DaemonUtils (194 lines)
- Daemon type identification (IsCameraDaemon, IsTurretDaemon, IsNPCDaemon, IsBasicDaemon)
- RemoteBreach setting resolver (GetRemoteBreachSettingForDevice)
- Network connection checks (IsConnectedToNetwork, IsConnectedToAccessPoint)
- Internally uses DeviceTypeUtils for device type detection

#### BonusDaemonUtils (119 lines)
- Auto-execute PING on daemon success (AutoExecutePingOnSuccess setting)
- Auto-apply Datamine based on success count (AutoDatamineBySuccessCount setting):
  - 1 daemon → Datamine V1 (Basic)
  - 2 daemons → Datamine V2 (Advanced)
  - 3+ daemons → Datamine V3 (Master)
- Shared by all breach types (AP Breach, Remote Breach, Unconscious NPC Breach)
- Global functions (ApplyBonusDaemons, HasProgram, HasAnyDatamineProgram, CountNonDataminePrograms)

#### RadialUnlockSystem (283 lines)
- Position-based breach tracking (RecordNetworkBreachPosition)
- 50m radius breach tracking for standalone devices
- Integration with RadialBreach MOD

#### ProgressionSystem (213 lines)
- Cyberdeck requirement checks (IsCyberdeckEquipped)
- Intelligence attribute checks (GetIntelligenceLevel)
- Enemy rarity checks (GetEnemyRarity)
- Progressive unlock validation

#### DNRGating (87 lines)
- Daemon Netrunning Revamp MOD integration
- Compatibility layer for DNR daemon checks
- Fallback to vanilla behavior if DNR not installed

---

## Data Flow

### 1. Access Point Breach Flow

```
User Interaction (Access Point)
    ↓
NetworkBlackboard Setup
    ├─ RemoteBreach = false
    └─ OfficerBreach = false
    ↓
ProgramInjection (betterNetrunning.reds)
    ├─ Detect: isAccessPoint = true
    ├─ Inject: Turret + Camera + NPC + Basic daemons
    └─ Check: Progressive unlock state (m_betterNetrunningBreached*)
    ↓
ProgramFiltering (ProgramFiltering.reds)
    ├─ Remove: Already breached daemons
    ├─ Remove: Datamine V1/V2/V3 (if AutoDatamineBySuccessCount = true)
    ├─ Remove: Non-AccessPoint programs (if AllowAllDaemonsOnAccessPoints = false)
    └─ Filter: Device type availability (network scan results)
    ↓
RadialBreach Filtering (RadialBreachGating.reds)
    └─ Re-add: Only devices within 50m radius (if UnlockIfNoAccessPoint = false)
    ↓
Minigame Start (Vanilla system)
    └─ Timer: 1.0x (standard)
    ↓
Player Operation (Daemon upload)
    ↓
Breach Success
    ↓
BonusDaemonUtils.ApplyBonusDaemons() (BreachProcessing.reds)
    ├─ Auto-execute PING (if AutoExecutePingOnSuccess = true)
    └─ Auto-apply Datamine (if AutoDatamineBySuccessCount = true)
    ↓
Network Unlock (BreachProcessing.reds: RefreshSlaves)
    ├─ Update breach flags: m_betterNetrunningBreached*
    ├─ Unlock quickhacks: Camera/Turret/NPC/Basic
    └─ Execute daemon effects: Device control
```

### 2. Remote Breach Flow

```
User Quickhack (Computer/Camera/Turret/Device/Vehicle)
    ↓
Visibility Check (RemoteBreachVisibility.reds)
    ├─ Check: Device-specific RemoteBreachEnabled setting
    ├─ Check: UnlockIfNoAccessPoint = false (RadialUnlock Mode)
    └─ Early return if disabled
    ↓
RemoteBreach Action (RemoteBreachAction_*.reds)
    ├─ Enforce: RemoteBreachEnabled setting
    ├─ Enforce: UnlockIfNoAccessPoint setting
    ├─ Determine: Available daemons (GetAvailableDaemonsForDevice)
    └─ Register: DeviceRemoteBreachStateSystem / VehicleRemoteBreachStateSystem
    ↓
NetworkBlackboard Setup
    ├─ RemoteBreach = true
    └─ OfficerBreach = false
    ↓
ProgramInjection (betterNetrunning.reds)
    ├─ Detect: Device type (Computer/Camera/Turret/Terminal/Other)
    ├─ Inject: Device-specific daemons
    └─ Check: Progressive unlock state
    ↓
ProgramFiltering (ProgramFiltering.reds)
    ├─ Remove: Already breached daemons
    ├─ Remove: Datamine V1/V2/V3 (no practical effect - not defined)
    └─ Skip: Non-AccessPoint program filter (isRemoteBreach = true)
    ↓
RadialBreach Filtering
    └─ Skip: isRemoteBreach = true → Early return
    ↓
Minigame Start (CustomHackingSystem)
    ├─ Timer: 1.0x (standard)
    └─ RAM Cost: RemoteBreachRAMCostPercent × Max RAM (default 35%)
    ↓
Player Operation (Daemon upload)
    ↓
Breach Success
    ↓
BonusDaemonUtils.ApplyBonusDaemons() (RemoteBreachNetworkUnlock.reds)
    ├─ Auto-execute PING
    └─ Auto-apply Datamine V1/V2/V3
    ↓
Network Unlock (RemoteBreachNetworkUnlock.reds)
    ├─ Update breach flags
    ├─ Unlock quickhacks
    └─ Execute daemon effects
```

### 3. Unconscious NPC Breach Flow

```
User Interaction (Unconscious NPC)
    ↓
Activation Check (NPCLifecycle.reds)
    ├─ Check: AllowBreachingUnconsciousNPCs = true
    ├─ Check: IsConnectedToAccessPoint() = true
    ├─ Check: RadialUnlock Mode enabled OR physical AP connection
    └─ Check: Not directly breached (m_betterNetrunningWasDirectlyBreached = false)
    ↓
NetworkBlackboard Setup
    ├─ RemoteBreach = false
    └─ OfficerBreach = true
    ↓
ProgramInjection (betterNetrunning.reds)
    ├─ Detect: isUnconsciousNPC = true
    ├─ Detect: isNetrunner = IsNetrunnerPuppet()
    ├─ Inject (Regular NPC): NPC + Basic daemons
    └─ Inject (Netrunner NPC): Turret + Camera + NPC + Basic daemons
    ↓
ProgramFiltering (ProgramFiltering.reds)
    ├─ Remove: Already breached daemons
    ├─ Remove: Datamine V1/V2/V3
    └─ Remove: Non-AccessPoint programs (except subnet programs)
    ↓
RadialBreach Filtering
    └─ Re-add: Only devices within 50m radius
    ↓
Minigame Start
    └─ Timer: 1.5x (50% increase - time leeway with direct connection)
    ↓
Player Operation (Daemon upload)
    ↓
Breach Success
    ↓
BonusDaemonUtils.ApplyBonusDaemons() (NPCLifecycle.reds)
    ├─ Auto-execute PING
    └─ Auto-apply Datamine V1/V2/V3
    ↓
Network Unlock
```

---

## Design Patterns

### 1. Strategy Pattern (DaemonUnlockStrategy.reds)

**Problem:** Different device types require different unlock behavior

**Solution:** Encapsulate device-specific unlock logic in separate strategy classes

```redscript
// Interface
public abstract class IDaemonUnlockStrategy {
    public func Execute(devicePS: ref<SharedGameplayPS>, unlockFlags: BreachUnlockFlags) -> Void;
    public func GetStrategyName() -> String;
}

// Concrete Strategies
public class ComputerUnlockStrategy extends IDaemonUnlockStrategy {
    // Computer/AccessPoint unlock logic
}

public class DeviceUnlockStrategy extends IDaemonUnlockStrategy {
    // Camera/Turret unlock logic
}

public class VehicleUnlockStrategy extends IDaemonUnlockStrategy {
    // Vehicle unlock logic
}
```

**Characteristics:**
- ✅ Device-specific logic encapsulation
- ✅ Easy to add new device types
- ✅ Clear separation of concerns
- ✅ Testable in isolation

### 2. Template Method Pattern

**Problem:** Processing workflows are similar but with device-specific steps

**Solution:** Define workflow template in base class, override specific steps in subclasses

```redscript
// Template in DaemonImplementation.reds
public func ProcessDaemonWithStrategy(
    program: MinigameProgramData,
    devicePS: ref<SharedGameplayPS>,
    unlockFlags: BreachUnlockFlags
) -> Void {
    // 1. Get strategy (device-specific)
    let strategy: ref<IDaemonUnlockStrategy> = this.GetStrategyForDevice(devicePS);

    // 2. Execute strategy (device-specific logic)
    strategy.Execute(devicePS, unlockFlags);

    // 3. Mark device as breached (common logic)
    this.MarkBreached(devicePS, unlockFlags);
}
```

**Characteristics:**
- ✅ Consistent processing workflow
- ✅ Device-specific customization points
- ✅ Minimal code duplication

### 3. Composed Method Pattern

**Problem:** Large functions are difficult to understand and maintain

**Solution:** Break down large functions into small, focused helper methods

**Example:** `RefreshSlaves()` implementation (BreachProcessing.reds)

```
RefreshSlaves()  ← Main coordinator (30 lines)
  ├─ ProcessDaemonsAndLoot()           ← Process daemon effects + loot
  ├─ ProcessDaemonWithStrategy()       ← Execute daemon via strategy
  ├─ CollectLootResults()              ← Collect loot from daemons
  ├─ ProcessLootResults()              ← Process collected loot
  ├─ ProcessUnlockedDevices()          ← Unlock devices on network
  └─ FinalizeBreachCleanup()           ← Clean up and finalize
```

**Characteristics:**
- ✅ Small, focused methods (max 30 lines)
- ✅ Shallow nesting depth (max 2 levels)
- ✅ High readability and testability

### 4. Early Return Pattern

**Problem:** Deeply nested conditionals reduce readability

**Solution:** Return early when preconditions fail

```redscript
// Early return pattern
if !condition1 { return; }
if !condition2 { return; }
if !condition3 { return; }
// actual logic
```

**Characteristics:**
- ✅ Shallow nesting depth
- ✅ High readability
- ✅ Clear precondition validation

### 5. Dependency Injection

**Problem:** Hard-coded dependencies make testing difficult

**Solution:** Pass dependencies as parameters

```redscript
// Strategy passed as parameter (not hard-coded)
public func ProcessDaemonWithStrategy(
    program: MinigameProgramData,
    devicePS: ref<SharedGameplayPS>,
    unlockFlags: BreachUnlockFlags,
    strategy: ref<IDaemonUnlockStrategy>  ← Injected dependency
) -> Void {
    strategy.Execute(devicePS, unlockFlags);
}
```

---

## Configuration System

### Layer Architecture

```
┌────────────────────────────────────────────────────┐
│  Native Settings UI (In-Game Menu)                │
│  - User-friendly toggles and sliders              │
│  - Real-time configuration changes                │
└────────────────────────────────────────────────────┘
                      ▼
┌────────────────────────────────────────────────────┐
│  CET (Cyber Engine Tweaks)                        │
│  - settingsManager.lua (defaults + overrides)     │
│  - nativeSettingsUI.lua (UI integration)          │
└────────────────────────────────────────────────────┘
                      ▼
┌────────────────────────────────────────────────────┐
│  config.reds (REDscript)                          │
│  - BetterNetrunningSettings class                 │
│  - Default values (fallback if CET not available) │
└────────────────────────────────────────────────────┘
```

### Configuration Options

| Category | Setting | Type | Default | Description |
|----------|---------|------|---------|-------------|
| **Controls** | BreachingHotkey | String | "Choice3" | Hotkey for manual breach initiation |
| **Breaching** | EnableClassicMode | Bool | false | Disable Better Netrunning features (vanilla behavior) |
| | AllowBreachingUnconsciousNPCs | Bool | true | Enable breaching unconscious NPCs |
| **RemoteBreach** | RemoteBreachEnabledComputer | Bool | true | Enable Computer RemoteBreach |
| | RemoteBreachEnabledCamera | Bool | true | Enable Camera RemoteBreach |
| | RemoteBreachEnabledTurret | Bool | true | Enable Turret RemoteBreach |
| | RemoteBreachEnabledDevice | Bool | true | Enable Device RemoteBreach |
| | RemoteBreachEnabledVehicle | Bool | true | Enable Vehicle RemoteBreach |
| | RemoteBreachRAMCostPercent | Int32 | 35 | RAM cost as percentage of max RAM (0-100) |
| **Access Points** | UnlockIfNoAccessPoint | Bool | false | RadialUnlock Mode control (false=enabled, true=disabled) |
| | AutoDatamineBySuccessCount | Bool | true | Auto-apply Datamine based on daemon count |
| | AutoExecutePingOnSuccess | Bool | true | Auto-execute PING on any daemon success |
| | AllowAllDaemonsOnAccessPoints | Bool | false | Display all programs in AP breach |
| **Quickhacks** | BlockCameraDisableQuickhack | Bool | false | Block Camera Disable quickhack |
| | BlockTurretDisableQuickhack | Bool | false | Block Turret Disable quickhack |
| | AlwaysAllowPing | Bool | true | PING always available (no breach required) |
| | AlwaysAllowWhistle | Bool | false | Whistle always available |
| | AlwaysAllowDistract | Bool | false | Distract Enemies always available |
| | AlwaysBasicDevices | Bool | false | Basic device quickhacks always available |
| | AlwaysCameras | Bool | false | Camera quickhacks always available |
| | AlwaysTurrets | Bool | false | Turret quickhacks always available |
| | AlwaysNPCsCovert | Bool | false | NPC covert quickhacks always available |
| | AlwaysNPCsCombat | Bool | false | NPC combat quickhacks always available |
| | AlwaysNPCsControl | Bool | false | NPC control quickhacks always available |

### Setting Effects

#### EnableClassicMode
```
false (default): Progressive Mode
  - Better Netrunning's daemon injection system enabled
  - Subnet progression system enabled
  - All BetterNetrunning features active

true: Classic Mode
  - Vanilla Cyberpunk 2077 behavior
  - No daemon injection
  - No progressive unlocking
```

#### UnlockIfNoAccessPoint
```
false (default): RadialUnlock Mode ENABLED
  - RadialBreach controls device unlocking via physical proximity (50m radius)
  - RemoteBreach enabled (requires RadialUnlock Mode)
  - Standalone devices require breach

true: RadialUnlock Mode DISABLED
  - RadialBreach disabled
  - RemoteBreach disabled
  - Standalone devices auto-unlock (no breach required)
```

#### AutoDatamineBySuccessCount
```
true (default):
  All breach types:
    - During minigame: Datamine programs hidden
    - After breach success: Auto-add Datamine based on daemon count
      * 1 daemon → Datamine V1 (Basic)
      * 2 daemons → Datamine V2 (Advanced)
      * 3+ daemons → Datamine V3 (Master)
    - Priority over AllowAllDaemonsOnAccessPoints

false:
  - During minigame: Display Datamine programs (vanilla behavior)
  - After breach success: No auto-add
```

#### RemoteBreachEnabled* Settings
```
Computer/Camera/Turret/Device/Vehicle:
  true (default): RemoteBreach quickhack visible and functional
  false: RemoteBreach quickhack hidden, action blocked

Implementation: Two-layer defense
  1. Prevention: RemoteBreachVisibility.reds (early return)
  2. Enforcement: RemoteBreachAction_*.reds (setting check)
```

---

## Extension Points

### Adding New Device Types

1. **Extend DeviceTypeUtils.reds:**
```redscript
public static func IsNewDeviceType(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
    return IsDefined(devicePS as NewDeviceControllerPS);
}
```

2. **Add daemon filter in DaemonUtils.reds:**
```redscript
public static func IsNewDeviceDaemon(actionID: TweakDBID) -> Bool {
    return Equals(TDBID.ToStringDEBUG(actionID), "MinigameAction.NetworkNewDevice");
}
```

3. **Extend ProgramInjection.reds:**
```redscript
// Add new device daemon injection logic
if !device.m_betterNetrunningBreachedNewDevice {
    ArrayPush(programList, MinigameProgramData.Create("MinigameAction.NetworkNewDevice"));
}
```

4. **Add unlock strategy (DaemonUnlockStrategy.reds):**
```redscript
public class NewDeviceUnlockStrategy extends IDaemonUnlockStrategy {
    public func Execute(devicePS: ref<SharedGameplayPS>, unlockFlags: BreachUnlockFlags) -> Void {
        // Device-specific unlock logic
    }
}
```

### Adding New Breach Types

1. **Define new blackboard flags:**
```redscript
// In CustomHacking system initialization
blackboard.SetBool(GetAllBlackboardDefs().HackingMinigame.RemoteBreach, false);
blackboard.SetBool(GetAllBlackboardDefs().HackingMinigame.NewBreachType, true);
```

2. **Add injection logic in ProgramInjection.reds:**
```redscript
let isNewBreachType: Bool = blackboard.GetBool(GetAllBlackboardDefs().HackingMinigame.NewBreachType);
if isNewBreachType {
    // Inject specific daemons for new breach type
}
```

3. **Add filtering logic in ProgramFiltering.reds:**
```redscript
if isNewBreachType {
    // Custom filtering rules
}
```

### MOD Compatibility

**Priority:** Use `@wrapMethod` instead of `@replaceMethod`

```redscript
// ✅ GOOD: Allows other mods to hook same function
@wrapMethod(MinigameGenerationRuleScalingPrograms)
public final func FilterPlayerPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {
    wrappedMethod(programs);  // Call vanilla logic first
    // Custom logic
}

// ❌ BAD: Blocks other mods from hooking
@replaceMethod(MinigameGenerationRuleScalingPrograms)
public final func FilterPlayerPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {
    // Custom logic (vanilla logic lost)
}
```

**Integration Points:**

- **RadialBreach MOD:** `@if(ModuleExists("RadialBreach"))` conditional compilation
- **Daemon Netrunning Revamp:** DNRGating.reds compatibility layer
- **CustomHackingSystem:** `@if(ModuleExists("HackingExtensions"))` conditional compilation

---

## Performance Considerations

### Optimization Strategies

1. **Code Deduplication:**
   - Strategy Pattern: Device-specific unlock strategies
   - BonusDaemonUtils: Centralized bonus daemon logic
   - DeviceTypeUtils: Unified device type detection

2. **Early Returns:**
   - Visibility checks: Block RemoteBreach before action creation
   - Setting checks: Skip processing if disabled
   - State checks: Skip already-breached devices

3. **Lazy Evaluation:**
   - Device type detection: Only when needed
   - Network scans: Only for connected devices
   - Daemon injection: Only for un-breached subnets

4. **Cached Results:**
   - Device type: Stored in local variables
   - Breach state: Persistent flags (m_betterNetrunningBreached*)
   - Network topology: Cached during breach

5. **Efficient Data Structures:**
   - BreachUnlockFlags struct: Pass multiple flags as single object
   - DeviceBreachInfo struct: Bundle related device info
   - Arrays instead of individual flags

### Code Quality Metrics

| Metric | Current Value | Notes |
|--------|---------------|-------|
| **Total Codebase** | ~5,870 lines | 31 files across 8 directories |
| **betterNetrunning.reds** | 195 lines | Main entry point and coordination |
| **Max Function Size** | 30 lines | Composed Method pattern applied |
| **Nesting Depth** | 2 levels | Early return pattern applied |
| **Code Duplication** | Minimal | DRY principle, Strategy Pattern |
| **Module Count** | 31 files | Modular architecture |

---

## Related Documents

- **BREACH_SYSTEM_REFERENCE.md**: Complete breach system technical reference
- **TODO.md**: Planned features and known issues

---

**Document Version:** 1.4
**Last Updated:** 2025-10-11
