module BetterNetrunning

import BetterNetrunning.Common.*
import BetterNetrunning.CustomHacking.*
import BetterNetrunning.Minigame.*
import BetterNetrunning.Progression.*
import BetterNetrunningConfig.*

// ==================== MODULE ARCHITECTURE ====================
//
// BETTER NETRUNNING - MODULAR ARCHITECTURE
//
// This file serves as the main entry point and coordination layer.
// Core functionality has been split into specialized modules:
//
// BREACH MINIGAME:
// - Minigame/ProgramFiltering.reds: Daemon filtering logic (ShouldRemove* functions)
// - Minigame/ProgramInjection.reds: Progressive unlock program injection
// - Breach/BreachProcessing.reds: RefreshSlaves() and breach completion handlers
// - Breach/BreachHelpers.reds: Network hierarchy and minigame status handlers
//
// DEVICE QUICKHACKS:
// - Devices/DeviceQuickhacks.reds: Progressive unlock, action finalization, remote actions
// - Devices/TurretExtensions.reds: Security turret quickhack extensions
// - Devices/CameraExtensions.reds: Surveillance camera quickhack extensions
//
// NPC QUICKHACKS:
// - NPCs/NPCQuickhacks.reds: Progressive unlock, permission calculation
// - NPCs/NPCLifecycle.reds: Incapacitation handling, unconscious breach
//
// PROGRESSION SYSTEM:
// - Progression/ProgressionSystem.reds: Cyberdeck, Intelligence, Enemy Rarity checks
//
// COMMON UTILITIES:
// - Common/Events.reds: Persistent field definitions, breach events
// - Common/DaemonUtils.reds: Daemon filtering utilities
// - Common/DeviceTypeUtils.reds: Device type detection
// - Common/RadialBreachGating.reds: Radial breach system (50m radius)
// - Common/RadialUnlockSystem.reds: Standalone device unlock tracking
// - Common/DNRGating.reds: Daemon Netrunning Revamp integration
// - Common/Logger.reds: Debug logging
//
// CUSTOM HACKING SYSTEM:
// - CustomHacking/*: RemoteBreach integration (9 files)
//
// DESIGN PHILOSOPHY:
// - Single Responsibility: Each module handles one aspect of functionality
// - Composed Method: Large functions broken into small, focused helpers
// - MOD COMPATIBILITY: Uses @wrapMethod where possible instead of @replaceMethod
// - Clear Dependencies: Import statements make module relationships explicit

// ==================== MAIN COORDINATION FUNCTION ====================
//
// Controls which breach programs (daemons) appear in the minigame
//
// VERSION HISTORY:
// - Release version: Used @replaceMethod
// - Latest version: Changed to @wrapMethod for better mod compatibility (intentional improvement)
//
// FUNCTIONALITY:
// - Adds new custom daemons (unlock programs for cameras, turrets, NPCs)
// - Optionally allows access to all daemons through access points
// - Optionally removes Datamine V1 and V2 daemons from access points
// - Filters programs based on network device types (cameras, turrets, NPCs)
// - DNR (Daemon Netrunning Revamp) compatibility layer
//
// MOD COMPATIBILITY: @wrapMethod allows other mods to also hook this function
@wrapMethod(MinigameGenerationRuleScalingPrograms)
public final func FilterPlayerPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {
  BNLog("[FilterPlayerPrograms] Starting daemon filtering");

  // Inject Better Netrunning specific programs into player's program list
  this.InjectBetterNetrunningPrograms(programs);
  // Store the hacking target entity in minigame blackboard (used for access point logic)
  this.m_blackboardSystem.Get(GetAllBlackboardDefs().HackingMinigame).SetVariant(GetAllBlackboardDefs().HackingMinigame.Entity, ToVariant(this.m_entity));

  // Call vanilla filtering logic FIRST to properly initialize program data
  // This populates actionID fields correctly
  wrappedMethod(programs);

  BNLog("[FilterPlayerPrograms] Initial program count: " + ToString(ArraySize(Deref(programs))));

  // CRITICAL: Remove already-breached programs AFTER wrappedMethod()
  // This ensures actionID fields are properly initialized by vanilla logic
  let i: Int32 = ArraySize(Deref(programs)) - 1;
  while i >= 0 {
    let actionID: TweakDBID = Deref(programs)[i].actionID;
    if ShouldRemoveBreachedPrograms(actionID, this.m_entity as GameObject) {
      ArrayErase(Deref(programs), i);
    }
    i -= 1;
  }

  // Apply Better Netrunning custom filtering rules
  let connectedToNetwork: Bool;
  let data: ConnectedClassTypes;
  let devPS: ref<SharedGameplayPS>; // Used for subnet breach tracking and DNR gating

  // Get network connection status and available device types
  if (this.m_entity as GameObject).IsPuppet() {
    connectedToNetwork = true;
    data = (this.m_entity as ScriptedPuppet).GetMasterConnectedClassTypes();
    devPS = (this.m_entity as ScriptedPuppet).GetPS().GetDeviceLink();
    BNLog("[FilterPlayerPrograms] Target: NPC (always connected)");
  } else {
    connectedToNetwork = (this.m_entity as Device).GetDevicePS().IsConnectedToPhysicalAccessPoint();
    data = (this.m_entity as Device).GetDevicePS().CheckMasterConnectedClassTypes();
    devPS = (this.m_entity as Device).GetDevicePS() as SharedGameplayPS;
    BNLog("[FilterPlayerPrograms] Target: Device (connected=" + ToString(connectedToNetwork) + ")");
  }

  // Filter programs in reverse order to safely remove elements
  let removedCount: Int32 = 0;
  i = ArraySize(Deref(programs)) - 1;
  while i >= 0 {
    let actionID: TweakDBID = Deref(programs)[i].actionID;
    let miniGameActionRecord: wref<MinigameAction_Record> = TweakDBInterface.GetMinigameActionRecord(actionID);

    // Remove programs that don't match current context
    if ShouldRemoveNetworkPrograms(actionID, connectedToNetwork)
        || ShouldRemoveDeviceBackdoorPrograms(actionID, this.m_entity as GameObject)
        || ShouldRemoveAccessPointPrograms(actionID, miniGameActionRecord, this.m_isRemoteBreach)
        || ShouldRemoveNonNetrunnerPrograms(actionID, miniGameActionRecord, this.m_isRemoteBreach, this.m_entity as GameObject)
        || ShouldRemoveDeviceTypePrograms(actionID, miniGameActionRecord, data)
        || ShouldRemoveDataminePrograms(actionID) {
      ArrayErase(Deref(programs), i);
      removedCount += 1;
    }
    i -= 1;
  };

  // Apply DNR (Daemon Netrunning Revamp) daemon gating
  // This integrates DNR's advanced daemon system with Better Netrunning's subnet-based progression
  ApplyDNRDaemonGating(programs, devPS, this.m_isRemoteBreach, this.m_player as PlayerPuppet, this.m_entity);

  BNLog("[FilterPlayerPrograms] Removed " + ToString(removedCount) + " programs, final count: " + ToString(ArraySize(Deref(programs))));
}

// ==================== DESIGN DOCUMENTATION ====================
//
// DESIGN NOTE: Progressive Unlock Implementation
//
// VERSION HISTORY:
// - Release version: Used @replaceMethod to override QuickHacksExposedByDefault()
// - Current version: Removed menu visibility overrides (intentional design change)
//
// ARCHITECTURE:
// Better Netrunning maintains vanilla menu visibility behavior while implementing
// progressive unlock through action-level restrictions:
//
// DEVICES (Devices/DeviceQuickhacks.reds):
// - GetRemoteActions(): Main entry point for device quickhacks
// - SetActionsInactiveUnbreached(): Applies progressive restrictions before breach
// - Checks: Cyberdeck tier, Intelligence stat, device type (camera/turret/basic)
//
// NPCs (NPCs/NPCQuickhacks.reds):
// - GetAllChoices(): Main entry point for NPC quickhacks
// - CalculateNPCHackPermissions(): Calculates category-based permissions
// - Checks: Cyberdeck tier, Intelligence stat, Enemy Rarity, hack category
//
// RATIONALE:
// - Menu visibility: Always show quickhack wheel (vanilla behavior)
// - Action availability: Progressively unlock based on player progression
// - Better mod compatibility: Doesn't override menu visibility functions
// - Cleaner separation: Menu display vs action availability are independent
//
// SPECIAL CASES:
// - Tutorial NPCs: Whitelisted (always unlocked for proper tutorial flow)
// - Isolated NPCs: Auto-unlocked (not connected to any network)
// - Unsecured networks: Auto-unlocked (no access points found)
// - Radial breach: Standalone devices within 50m radius auto-unlocked

//
// MODULE REFERENCE GUIDE
//
// FINDING SPECIFIC FUNCTIONALITY:
//
// Breach Minigame Programs:
// - Minigame/ProgramFiltering.reds: Which daemons appear in minigame
// - Minigame/ProgramInjection.reds: Adding custom unlock daemons
//
// Device Quickhacks (Before/After Breach):
// - Devices/DeviceQuickhacks.reds: Main logic
// - Devices/TurretExtensions.reds: Turret-specific extensions
// - Devices/CameraExtensions.reds: Camera-specific extensions
//
// NPC Quickhacks (Before/After Breach):
// - NPCs/NPCQuickhacks.reds: Main logic
// - NPCs/NPCLifecycle.reds: Incapacitation/death handling
//
// Breach Completion:
// - Breach/BreachProcessing.reds: What happens when breach succeeds
// - Breach/BreachHelpers.reds: Network hierarchy and status handlers
//
// Progression Checks:
// - Progression/ProgressionSystem.reds: Cyberdeck/Intelligence/Rarity evaluation
//
// Radial Breach System:
// - Common/RadialBreachGating.reds: 50m radius breach tracking
// - Common/RadialUnlockSystem.reds: Standalone device unlock records
//
// Persistent State:
// - Common/Events.reds: Breach state fields and events
//
// MOD INTEGRATIONS:
// - Common/DNRGating.reds: Daemon Netrunning Revamp compatibility
// - CustomHacking/*: RemoteBreach action integration (9 files)
