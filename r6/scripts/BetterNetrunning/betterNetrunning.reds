module BetterNetrunning

import BetterNetrunning.RadialUnlock.*
import BetterNetrunning.Logger.*
import BetterNetrunning.Config.*

/*
 * Controls which breach programs (daemons) appear in the minigame
 *
 * VERSION HISTORY:
 * - Release version: Used @replaceMethod
 * - Latest version: Changed to @wrapMethod for better mod compatibility (intentional improvement)
 *
 * FUNCTIONALITY:
 * - Adds new custom daemons (unlock programs for cameras, turrets, NPCs)
 * - Optionally allows access to all daemons through access points
 * - Optionally removes Datamine V1 and V2 daemons from access points
 * - Filters programs based on network device types (cameras, turrets, NPCs)
 * - DNR (Daemon Netrunning Revamp) compatibility layer
 *
 * MOD COMPATIBILITY: @wrapMethod allows other mods to also hook this function
 */
@wrapMethod(MinigameGenerationRuleScalingPrograms)
public final func FilterPlayerPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {
  // Inject Better Netrunning specific programs into player's program list
  this.InjectBetterNetrunningPrograms(programs);
  // Store the hacking target entity in minigame blackboard (used for access point logic)
  this.m_blackboardSystem.Get(GetAllBlackboardDefs().HackingMinigame).SetVariant(GetAllBlackboardDefs().HackingMinigame.Entity, ToVariant(this.m_entity));
  // Call vanilla filtering logic
  wrappedMethod(programs);

  // Apply Better Netrunning custom filtering rules
  let connectedToNetwork: Bool;
  let data: ConnectedClassTypes;

  // Get network connection status and available device types
  if (this.m_entity as GameObject).IsPuppet() {
    connectedToNetwork = true;
    data = (this.m_entity as ScriptedPuppet).GetMasterConnectedClassTypes();
  } else {
    connectedToNetwork = (this.m_entity as Device).GetDevicePS().IsConnectedToPhysicalAccessPoint();
    data = (this.m_entity as Device).GetDevicePS().CheckMasterConnectedClassTypes();
  }

  // Filter programs in reverse order to safely remove elements
  let i: Int32 = ArraySize(Deref(programs)) - 1;
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
    }
    i -= 1;
  };
}

// ==================== Program Filtering Functions ====================
// These module-level functions are called from FilterPlayerPrograms to determine
// which breach programs should be available in the current context

// Returns true if unlock programs should be removed (when target is not connected to network)
public func ShouldRemoveNetworkPrograms(actionID: TweakDBID, connectedToNetwork: Bool) -> Bool {
  if connectedToNetwork {
    return false;
  }
  return IsUnlockQuickhackAction(actionID);
}

// Returns true if device-specific programs should be removed (for non-access-point devices)
public func ShouldRemoveDeviceBackdoorPrograms(actionID: TweakDBID, entity: wref<GameObject>) -> Bool {
  // Only applies to non-access-point devices
  if !(IsDefined(entity as Device) && !IsDefined(entity as AccessPoint)) {
    return false;
  }
  return actionID == t"MinigameAction.NetworkDataMineLootAllMaster"
      || actionID == t"MinigameAction.UnlockNPCQuickhacks"
      || actionID == t"MinigameAction.UnlockTurretQuickhacks";
}

// Returns true if access point programs should be restricted (based on user settings)
public func ShouldRemoveAccessPointPrograms(actionID: TweakDBID, miniGameActionRecord: wref<MinigameAction_Record>, isRemoteBreach: Bool) -> Bool {
  // Allow all programs if configured or if remote breach
  if BN_Settings.AllowAllDaemonsOnAccessPoints() || isRemoteBreach {
    return false;
  }
  // Remove non-access-point programs and non-unlock programs
  return NotEquals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.AccessPoint)
      && !IsUnlockQuickhackAction(actionID);
}

// Returns true if programs should be restricted for non-netrunner NPCs
public func ShouldRemoveNonNetrunnerPrograms(actionID: TweakDBID, miniGameActionRecord: wref<MinigameAction_Record>, isRemoteBreach: Bool, entity: wref<GameObject>) -> Bool {
  // Only applies to remote breach on non-netrunner NPCs
  if !IsRemoteNonNetrunner(isRemoteBreach, entity) {
    return false;
  }
  // Remove DNR-specific programs if applicable
  if ShouldRemoveDNRNonNetrunnerPrograms(actionID) {
    return true;
  }
  // Remove access point programs and device unlock programs
  return Equals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.AccessPoint)
      || actionID == t"MinigameAction.UnlockCameraQuickhacks"
      || actionID == t"MinigameAction.UnlockTurretQuickhacks";
}

// Returns true if target is a remote breach on a non-netrunner NPC
public func IsRemoteNonNetrunner(isRemoteBreach: Bool, entity: wref<GameObject>) -> Bool {
  if !isRemoteBreach {
    return false;
  }
  let puppet: wref<ScriptedPuppet> = entity as ScriptedPuppet;
  return IsDefined(puppet) && !puppet.IsNetrunnerPuppet();
}

// Returns true if action is any type of unlock quickhack program
private func IsUnlockQuickhackAction(actionID: TweakDBID) -> Bool {
  return actionID == t"MinigameAction.UnlockQuickhacks"
      || actionID == t"MinigameAction.UnlockNPCQuickhacks"
      || actionID == t"MinigameAction.UnlockCameraQuickhacks"
      || actionID == t"MinigameAction.UnlockTurretQuickhacks";
}

// Returns true if ultimate hack programs should be removed when DNR mod is installed
// DNR (Daemon Netrunning Revamp) compatibility layer
@if(ModuleExists("DNR.Replace"))
public func ShouldRemoveDNRNonNetrunnerPrograms(actionID: TweakDBID) -> Bool {
  return actionID == t"MinigameAction.RemoteCyberpsychosis"
      || actionID == t"MinigameAction.Cyberpsychosis_AP"
      || actionID == t"MinigameAction.RemoteSuicide"
      || actionID == t"MinigameAction.Suicide_AP"
      || actionID == t"MinigameAction.RemoteSystemReset"
      || actionID == t"MinigameAction.SystemReset_AP"
      || actionID == t"MinigameAction.RemoteDetonateGrenade"
      || actionID == t"MinigameAction.DetonateGrenade_AP"
      || actionID == t"MinigameAction.RemoteNetworkOverload"
      || actionID == t"MinigameAction.NetworkOverload_AP"
      || actionID == t"MinigameAction.RemoteNetworkContagion"
      || actionID == t"MinigameAction.NetworkContagion_AP";
}

// Stub implementation when DNR mod is not installed (always returns false)
@if(!ModuleExists("DNR.Replace"))
public func ShouldRemoveDNRNonNetrunnerPrograms(actionID: TweakDBID) -> Bool {
  return false;
}

// Returns true if programs should be removed based on device type availability
public func ShouldRemoveDeviceTypePrograms(actionID: TweakDBID, miniGameActionRecord: wref<MinigameAction_Record>, data: ConnectedClassTypes) -> Bool {
  // In RadialUnlock mode, delegate filtering to RadialBreach's physical proximity-based system if installed
  // If RadialBreach is not installed, disable network-based filtering to reduce UI noise
  if !BN_Settings.UnlockIfNoAccessPoint() {
    return false;
  }

  // In Classic mode, use traditional network connectivity-based filtering
  // Remove camera programs if no cameras connected
  if (Equals(miniGameActionRecord.Category().Type(), gamedataMinigameCategory.CameraAccess) || actionID == t"MinigameAction.UnlockCameraQuickhacks") && !data.surveillanceCamera {
    return true;
  }
  // Remove turret programs if no turrets connected
  if (Equals(miniGameActionRecord.Category().Type(), gamedataMinigameCategory.TurretAccess) || actionID == t"MinigameAction.UnlockTurretQuickhacks") && !data.securityTurret {
    return true;
  }
  // Remove NPC programs if no NPCs connected
  if (Equals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.NPC) || actionID == t"MinigameAction.UnlockNPCQuickhacks") && !data.puppet {
    return true;
  }
  return false;
}

// Returns true if Datamine V1/V2 programs should be removed (based on user settings)
public func ShouldRemoveDataminePrograms(actionID: TweakDBID) -> Bool {
  if !BN_Settings.DisableDatamineOneTwo() {
    return false;
  }
  return Equals(actionID, t"MinigameAction.NetworkDataMineLootAllAdvanced")
      || Equals(actionID, t"MinigameAction.NetworkDataMineLootAll");
}

// ==================== Design Notes ====================

/*
 * DESIGN NOTE: QuickHacksExposedByDefault is NOT overridden
 *
 * VERSION HISTORY:
 * - Release version: Used @replaceMethod to override QuickHacksExposedByDefault() and IsQuickHacksExposed()
 * - Latest version: Removed these overrides entirely (intentional design change)
 *
 * RATIONALE:
 * Better Netrunning now maintains vanilla behavior where quickhack menu is always visible.
 * Progressive unlock is implemented through separate mechanisms:
 * - GetRemoteActions() + SetActionsInactiveUnbreached() for devices
 * - GetAllChoices() + ShouldQuickhackBeInactive() for NPCs
 *
 * This approach provides better mod compatibility and cleaner separation of concerns.
 * Overriding QuickHacksExposedByDefault() to return false would prevent the menu
 * from appearing entirely, breaking the user experience.
 */

/*
 * Extends turret quickhack actions with custom behaviors
 * Optionally blocks turret disable quickhacks based on user settings
 *
 * CRITICAL FIX (Scenario 5): wrappedMethod() is called OUTSIDE the if-condition
 * to ensure FinalizeGetQuickHackActions() executes for ALL device states (NOMINAL,
 * DAMAGED, DESTROYED, UNPOWERED). This preserves vanilla behavior where RPG checks,
 * equipment requirements, and illegality marking are always applied.
 */
@wrapMethod(SecurityTurretControllerPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
  // Execute vanilla logic first (including Finalize regardless of device state)
  wrappedMethod(actions, context);

  // Add Better Netrunning custom actions only if device is in nominal state
  if Equals(this.GetDurabilityState(), EDeviceDurabilityState.NOMINAL) {
    // Add turret attitude override quickhacks
    this.AddTurretAttitudeAction(actions, t"DeviceAction.TurretOverrideAttitudeClassLvl5Hack");
    this.AddTurretAttitudeAction(actions, t"DeviceAction.TurretOverrideAttitudeClassHack");
    // Add take control quickhack
    this.AddTurretTakeControlAction(actions);
    // Add tag kill mode quickhack
    this.AddTurretTagKillModeAction(actions);
    // Add toggle quickhacks (if not blocked by settings)
    if !BN_Settings.BlockTurretDisableQuickhack() {
      this.AddTurretToggleAction(actions, t"DeviceAction.TurretToggleStateClassHack");
      this.AddTurretToggleAction(actions, t"DeviceAction.TurretToggleStateClassLvl2Hack");
      this.AddTurretToggleAction(actions, t"DeviceAction.TurretToggleStateClassLvl3Hack");
      this.AddTurretToggleAction(actions, t"DeviceAction.TurretToggleStateClassLvl4Hack");
      this.AddTurretToggleAction(actions, t"DeviceAction.TurretToggleStateClassLvl5Hack");
    }
  }
}

// Helper: Add turret attitude override action
@addMethod(SecurityTurretControllerPS)
private final func AddTurretAttitudeAction(actions: script_ref<array<ref<DeviceAction>>>, actionID: TweakDBID) -> Void {
  let action: ref<ScriptableDeviceAction> = this.ActionSetDeviceAttitude();
  action.SetObjectActionID(actionID);
  action.SetExecutor(GetPlayer(this.GetGameInstance()));
  action.SetDurationValue(action.GetDurationTime());
  action.SetInactiveWithReason(this.IsON(), "LocKey#7005");
  action.SetInactiveWithReason(this.IsAttitudeFromContextHostile(), "LocKey#7010");
  ArrayPush(Deref(actions), action);
}

// Helper: Add turret take control action
@addMethod(SecurityTurretControllerPS)
private final func AddTurretTakeControlAction(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let action: ref<ScriptableDeviceAction> = this.ActionToggleTakeOverControl();
  action.SetObjectActionID(t"DeviceAction.TakeControlClassHack");
  action.SetInactiveWithReason(this.m_canPlayerTakeOverControl, "LocKey#7006");
  action.SetInactiveWithReason(this.IsON(), "LocKey#7005");
  action.SetInactiveWithReason(!PlayerPuppet.IsSwimming(GetPlayer(this.GetGameInstance())), "LocKey#7003");
  action.SetInactiveWithReason(PlayerPuppet.GetSceneTier(GetPlayer(this.GetGameInstance())) <= 1, "LocKey#7003");
  ArrayPush(Deref(actions), action);
}

// Helper: Add turret tag kill mode action
@addMethod(SecurityTurretControllerPS)
private final func AddTurretTagKillModeAction(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let action: ref<ScriptableDeviceAction> = this.ActionSetDeviceTagKillMode();
  action.SetObjectActionID(t"DeviceAction.SetDeviceTagKillMode");
  action.SetInactiveWithReason(!this.IsInTagKillMode(), "LocKey#7004");
  ArrayPush(Deref(actions), action);
}

// Helper: Add turret toggle action
@addMethod(SecurityTurretControllerPS)
private final func AddTurretToggleAction(actions: script_ref<array<ref<DeviceAction>>>, actionID: TweakDBID) -> Void {
  let action: ref<ScriptableDeviceAction> = this.ActionQuickHackToggleON();
  action.SetObjectActionID(actionID);
  action.SetExecutor(GetPlayer(this.GetGameInstance()));
  action.SetDurationValue(action.GetDurationTime());
  action.SetInactiveWithReason(this.IsOFFTimed(), "LocKey#7005");
  ArrayPush(Deref(actions), action);
}

/*
 * Extends camera quickhack actions with custom behaviors
 * Optionally blocks camera disable quickhacks based on user settings
 *
 * CRITICAL FIX (Scenario 5): wrappedMethod() is called OUTSIDE the if-condition
 * to ensure FinalizeGetQuickHackActions() executes for ALL device states (NOMINAL,
 * DAMAGED, DESTROYED, UNPOWERED). This preserves vanilla behavior where RPG checks,
 * equipment requirements, and illegality marking are always applied.
 */
@wrapMethod(SurveillanceCameraControllerPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
  // Execute vanilla logic first (including Finalize regardless of device state)
  wrappedMethod(actions, context);

  // Add Better Netrunning custom actions only if device is in nominal state
  if Equals(this.GetDurabilityState(), EDeviceDurabilityState.NOMINAL) {
    // Add take control quickhack
    this.AddCameraTakeControlAction(actions);
    // Add camera attitude override quickhacks
    this.AddCameraAttitudeAction(actions, t"DeviceAction.OverrideAttitudeClassHack");
    this.AddCameraAttitudeAction(actions, t"DeviceAction.OverrideAttitudeClassLvl3Hack");
    this.AddCameraAttitudeAction(actions, t"DeviceAction.OverrideAttitudeClassLvl4Hack");
    this.AddCameraAttitudeAction(actions, t"DeviceAction.OverrideAttitudeClassLvl5Hack");
    // Add toggle quickhack (if not blocked by settings)
    if !BN_Settings.BlockCameraDisableQuickhack() {
      this.AddCameraToggleAction(actions);
    }
  }
}

// Helper: Add camera take control action
@addMethod(SurveillanceCameraControllerPS)
private final func AddCameraTakeControlAction(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let action: ref<ScriptableDeviceAction> = this.ActionToggleTakeOverControl();
  action.SetObjectActionID(t"DeviceAction.TakeControlCameraClassHack");
  action.SetExecutor(GetPlayer(this.GetGameInstance()));
  action.SetDurationValue(action.GetDurationTime());
  action.SetInactiveWithReason(this.m_canPlayerTakeOverControl && Equals(this.GetDurabilityState(), EDeviceDurabilityState.NOMINAL), "LocKey#7004");
  action.SetInactiveWithReason(!PlayerPuppet.IsSwimming(GetPlayer(this.GetGameInstance())), "LocKey#7003");
  action.SetInactiveWithReason(PlayerPuppet.GetSceneTier(GetPlayer(this.GetGameInstance())) <= 1, "LocKey#7003");
  ArrayPush(Deref(actions), action);
}

// Helper: Add camera attitude override action
@addMethod(SurveillanceCameraControllerPS)
private final func AddCameraAttitudeAction(actions: script_ref<array<ref<DeviceAction>>>, actionID: TweakDBID) -> Void {
  let action: ref<ScriptableDeviceAction> = this.ActionForceIgnoreTargets();
  action.SetObjectActionID(actionID);
  action.SetExecutor(GetPlayer(this.GetGameInstance()));
  action.SetDurationValue(action.GetDurationTime());
  action.SetInactiveWithReason(this.IsON(), "LocKey#7005");
  action.SetInactiveWithReason(this.GetBehaviourCanDetectIntruders(), "LocKey#7007");
  action.SetInactiveWithReason(this.IsAttitudeFromContextHostile(), "LocKey#7008");
  ArrayPush(Deref(actions), action);
}

// Helper: Add camera toggle action
@addMethod(SurveillanceCameraControllerPS)
private final func AddCameraToggleAction(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let action: ref<ScriptableDeviceAction> = this.ActionQuickHackToggleON();
  action.SetObjectActionID(t"DeviceAction.ToggleStateClassHack");
  action.SetExecutor(GetPlayer(this.GetGameInstance()));
  action.SetDurationValue(action.GetDurationTime());
  ArrayPush(Deref(actions), action);
}

/*
 * Applies progressive unlock restrictions to device quickhacks before breach
 * Checks player progression (Cyberdeck tier, Intelligence stat) and device type
 * to determine which quickhacks should be available before successful breach
 */
@addMethod(ScriptableDeviceComponentPS)
public final func SetActionsInactiveUnbreached(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let sAction: ref<ScriptableDeviceAction>;
  let i: Int32 = 0;
  let isCamera: Bool = IsDefined(this as SurveillanceCameraControllerPS);
  let isTurret: Bool = IsDefined(this as SecurityTurretControllerPS);

  // Check if this is a standalone device (no AccessPoint)
  let sharedPS: ref<SharedGameplayPS> = this;
  let isStandaloneDevice: Bool = false;
  let apCount: Int32 = 0;
  if IsDefined(sharedPS) {
    let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
    apCount = ArraySize(apControllers);
    isStandaloneDevice = apCount == 0;
  }

  // Log device info including entity name for debugging
  let deviceEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
  let deviceName: String = IsDefined(deviceEntity) ? ToString(deviceEntity.GetClassName()) : "Unknown";

  BNLog("SetActionsInactiveUnbreached: Device=" + deviceName + ", isStandaloneDevice=" + ToString(isStandaloneDevice) + ", apCount=" + ToString(apCount) + ", breachedBasic=" + ToString(this.m_betterNetrunningBreachedBasic));

  // For standalone devices: check radial breach state (within radius of breached AP)
  // CRITICAL: ShouldUnlockStandaloneDevice returns TRUE in two cases:
  // 1. UnlockIfNoAccessPoint==true -> Always unlock (no AP required)
  // 2. UnlockIfNoAccessPoint==false -> Only unlock if within radius of breached AP
  // When unlocked via radial breach, treat as if the device was directly breached
  if isStandaloneDevice && ShouldUnlockStandaloneDevice(this, this.GetGameInstance()) {
    BNLog("SetActionsInactiveUnbreached: Standalone device unlocked via ShouldUnlockStandaloneDevice");

    // PERSISTENCE FIX: Mark device as permanently breached to survive save/load
    // This ensures standalone devices remain unlocked after game reload
    if !this.m_betterNetrunningBreachedBasic {
      this.m_betterNetrunningBreachedBasic = true;
      BNLog("SetActionsInactiveUnbreached: PERSISTED breachedBasic=true to device");
    }
    if isCamera && !this.m_betterNetrunningBreachedCameras {
      this.m_betterNetrunningBreachedCameras = true;
    }
    if isTurret && !this.m_betterNetrunningBreachedTurrets {
      this.m_betterNetrunningBreachedTurrets = true;
    }
  }

  BNLog("SetActionsInactiveUnbreached: After standalone check - breachedBasic=" + ToString(this.m_betterNetrunningBreachedBasic));

  // Check progression requirements for each device type
  // LOGIC: (Device is breached) OR (Player has sufficient progression)
  // - If breached -> Allow regardless of progression (breach reward)
  // - If not breached -> Allow only if progression requirements met
  let allowCameras: Bool = this.m_betterNetrunningBreachedCameras || ShouldUnlockHackDevice(this.GetGameInstance(), BN_Settings.AlwaysCameras(), BN_Settings.ProgressionCyberdeckCameras(), BN_Settings.ProgressionIntelligenceCameras());
  let allowTurrets: Bool = this.m_betterNetrunningBreachedTurrets || ShouldUnlockHackDevice(this.GetGameInstance(), BN_Settings.AlwaysTurrets(), BN_Settings.ProgressionCyberdeckTurrets(), BN_Settings.ProgressionIntelligenceTurrets());
  let allowBasicDevices: Bool = this.m_betterNetrunningBreachedBasic || ShouldUnlockHackDevice(this.GetGameInstance(), BN_Settings.AlwaysBasicDevices(), BN_Settings.ProgressionCyberdeckBasicDevices(), BN_Settings.ProgressionIntelligenceBasicDevices());

  BNLog("SetActionsInactiveUnbreached: allowBasicDevices=" + ToString(allowBasicDevices) + ", allowCameras=" + ToString(allowCameras) + ", allowTurrets=" + ToString(allowTurrets));

  // Check special always-allowed quickhacks
  let allowPing: Bool = BN_Settings.AlwaysAllowPing();
  let allowDistraction: Bool = BN_Settings.AlwaysAllowDistract();

  // Set quickhacks inactive if progression requirements not met
  while i < ArraySize(Deref(actions)) {
    sAction = (Deref(actions)[i] as ScriptableDeviceAction);

    // Determine if this action should be allowed based on device type and progression
    let shouldAllow: Bool = false;

    // Check special quickhacks that bypass device type checks
    let isPing: Bool = Equals(sAction.GetClassName(), n"PingDevice");
    let isDistract: Bool = Equals(sAction.GetClassName(), n"QuickHackDistraction");

    // CRITICAL: Use independent if statements, not else-if chain
    // This ensures device-type checks are evaluated regardless of quickhack type

    // Always-allowed quickhacks
    if isPing && allowPing {
      shouldAllow = true;
    }
    if isDistract && allowDistraction {
      shouldAllow = true;
    }

    // Device-type-specific permissions (checked independently)
    if isCamera && allowCameras {
      shouldAllow = true;
    }
    if isTurret && allowTurrets {
      shouldAllow = true;
    }
    if !isCamera && !isTurret && allowBasicDevices {
      // Basic devices (Speaker, Radio, Computer, etc.)
      // Only allow if progression requirements met OR already breached
      shouldAllow = true;
    }

    // Set inactive if not allowed
    if !shouldAllow {
      sAction.SetInactive();
      sAction.SetInactiveReason("LocKey#7021");
    }

    i += 1;
  };
}

/*
 * Finalizes device quickhack actions before presenting to player
 * VANILLA DIFF: Removes IsBreached() check on ActionRemoteBreach() to allow breach action when not yet breached
 * Handles backdoor actions, power state checks, and RPG availability (including equipment check)
 */
@replaceMethod(ScriptableDeviceComponentPS)
protected final func FinalizeGetQuickHackActions(outActions: script_ref<array<ref<DeviceAction>>>, const context: script_ref<GetActionsContext>) -> Void {
  // Early exit if device is not in nominal state
  if NotEquals(this.GetDurabilityState(), EDeviceDurabilityState.NOMINAL) {
    return;
  }
  // Early exit if quickhacks are disabled
  if this.m_disableQuickHacks {
    if ArraySize(Deref(outActions)) > 0 {
      ArrayClear(Deref(outActions));
    }
    return;
  }

  // Add backdoor breach and ping actions
  if this.IsConnectedToBackdoorDevice() {
    let currentAction: ref<ScriptableDeviceAction>;
    currentAction = this.ActionRemoteBreach();
    ArrayPush(Deref(outActions), currentAction);
    currentAction = this.ActionPing();
    currentAction.SetInactiveWithReason(!this.GetNetworkSystem().HasActivePing(this.GetMyEntityID()), "LocKey#49279");
    ArrayPush(Deref(outActions), currentAction);
  } else if this.HasNetworkBackdoor() {
    let currentAction: ref<ScriptableDeviceAction> = this.ActionPing();
    currentAction.SetInactiveWithReason(!this.GetNetworkSystem().HasActivePing(this.GetMyEntityID()), "LocKey#49279");
    ArrayPush(Deref(outActions), currentAction);
  }

  // Disable all actions if device is unpowered
  if this.IsUnpowered() {
    ScriptableDeviceComponentPS.SetActionsInactiveAll(outActions, "LocKey#7013");
  }

  // Apply RPG system restrictions (skill checks, illegality, equipment check, etc.)
  this.EvaluateActionsRPGAvailabilty(outActions, context);
  this.SetActionIllegality(outActions, this.m_illegalActions.quickHacks);
  this.MarkActionsAsQuickHacks(outActions);
  this.SetActionsQuickHacksExecutioner(outActions);
}

/*
 * Provides device quickhack actions based on breach status and player progression
 *
 * VERSION HISTORY:
 * - Release version: Used @replaceMethod with IsQuickHacksExposed() logic
 * - Latest version: Simplified to @replaceMethod without IsQuickHacksExposed() dependency
 *
 * VANILLA DIFF: Replaces SetActionsInactiveAll() with SetActionsInactiveUnbreached() for progressive unlock
 * FIXED: Always apply progressive unlock restrictions in Progressive Mode (don't rely on IsQuickHacksExposed)
 * FIXED: Auto-unlock networks without access points when UnlockIfNoAccessPoint is false
 *
 * ARCHITECTURE:
 * - Progressive unlock via SetActionsInactiveUnbreached() (checks Cyberdeck tier, Intelligence)
 * - Standalone device support via radial breach system (50m radius)
 * - Network centroid calculation for isolated NPC auto-unlock
 */
@replaceMethod(ScriptableDeviceComponentPS)
public final func GetRemoteActions(out outActions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
  // Early exit if quickhacks are disabled or device is not functional
  if this.m_disableQuickHacks || this.IsDisabled() {
    return;
  }

  // Get quickhack actions from device
  this.GetQuickHackActions(outActions, context);

  // Check if network has no access points (unsecured network)
  let sharedPS: ref<SharedGameplayPS> = this;
  let hasAccessPoint: Bool = true;
  let apCount: Int32 = 0;
  if IsDefined(sharedPS) {
    let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
    apCount = ArraySize(apControllers);
    hasAccessPoint = apCount > 0;
  }

  // CRITICAL FIX: Correct logic for unsecured network
  // UnlockIfNoAccessPoint = true -> Devices without AP are always unlocked (no restrictions)
  // UnlockIfNoAccessPoint = false -> Devices without AP require breach (restrictions apply)
  let isUnsecuredNetwork: Bool = !hasAccessPoint && BN_Settings.UnlockIfNoAccessPoint();

  let deviceEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
  let deviceName: String = IsDefined(deviceEntity) ? ToString(deviceEntity.GetClassName()) : "Unknown";
  BNLog("GetRemoteActions: Device=" + deviceName + ", hasAccessPoint=" + ToString(hasAccessPoint) + ", apCount=" + ToString(apCount) + ", UnlockIfNoAccessPoint=" + ToString(BN_Settings.UnlockIfNoAccessPoint()) + ", isUnsecuredNetwork=" + ToString(isUnsecuredNetwork));

  // Handle sequencer lock or breach state
  if this.IsLockedViaSequencer() {
    // Sequencer locked: only allow RemoteBreach action
    ScriptableDeviceComponentPS.SetActionsInactiveAll(outActions, "LocKey#7021", n"RemoteBreach");
    BNLog("GetRemoteActions: Sequencer locked");
  } else if !BN_Settings.EnableClassicMode() && !isUnsecuredNetwork {
    // Progressive Mode: apply device-type-specific unlock restrictions (unless unsecured network)
    BNLog("GetRemoteActions: Applying progressive unlock restrictions");
    this.SetActionsInactiveUnbreached(outActions);
  } else {
    BNLog("GetRemoteActions: No restrictions (ClassicMode=" + ToString(BN_Settings.EnableClassicMode()) + ", isUnsecuredNetwork=" + ToString(isUnsecuredNetwork) + ")");
  }
  // If isUnsecuredNetwork == true, all quickhacks remain active (no restrictions applied)
}

/*
 * Allows quickhack menu to open when devices are not connected to an access point
 * VANILLA DIFF: Simplified from branching logic - equivalent to vanilla when QuickHacksExposedByDefault() is true
 * Removes the IsConnectedToBackdoorDevice() check that vanilla uses when QuickHacksExposedByDefault() is false
 */
@replaceMethod(Device)
public const func CanRevealRemoteActionsWheel() -> Bool {
  return this.ShouldRegisterToHUD() && !this.GetDevicePS().IsDisabled() && this.GetDevicePS().HasPlaystyle(EPlaystyle.NETRUNNER);
}

/*
 * Controls NPC quickhack availability based on breach status and progression
 *
 * VERSION HISTORY:
 * - Release version: Used EnemyLevel for progression checks
 * - Latest version: Changed to EnemyRarity for more nuanced progression (intentional design change)
 *
 * VANILLA DIFF: Complete rewrite to implement progressive unlock system
 * Applies category-based restrictions (Covert, Combat, Control, Ultimate)
 * FIXED: Auto-unlock NPCs not connected to any network (isolated enemies)
 *
 * ARCHITECTURE:
 * - Progressive unlock via ShouldUnlockHackNPC() (checks Cyberdeck tier, Intelligence, Enemy Rarity)
 * - Network isolation detection -> auto-unlock for isolated NPCs
 * - Category-based restrictions (Covert, Combat, Control, Ultimate, Ping, Whistle)
 */
@replaceMethod(ScriptedPuppetPS)
public final const func GetAllChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>, puppetActions: script_ref<array<ref<PuppetAction>>>) -> Void {
  let attiudeTowardsPlayer: EAIAttitude = this.GetOwnerEntity().GetAttitudeTowards(GetPlayer(this.GetGameInstance()));
  let isPuppetActive: Bool = ScriptedPuppet.IsActive(this.GetOwnerEntity());
  let instigator: wref<GameObject> = Deref(context).processInitiatorObject;

  // Check breach status (m_quickHacksExposed is breach state, not menu visibility)
  let isBreached: Bool = this.m_quickHacksExposed;

  // Check if NPC is connected to any network
  let isConnectedToNetwork: Bool = this.IsConnectedToAccessPoint();

  // Auto-unlock if not connected to any network (isolated enemies)
  if !isConnectedToNetwork {
    isBreached = true;
  }

  // Evaluate progression-based unlock conditions for hack categories
  let allowCovert: Bool = ShouldUnlockHackNPC(this.GetGameInstance(), this.GetOwnerEntityWeak(), BN_Settings.AlwaysNPCsCovert(), BN_Settings.ProgressionCyberdeckNPCsCovert(), BN_Settings.ProgressionIntelligenceNPCsCovert(), BN_Settings.ProgressionEnemyRarityNPCsCovert());
  let allowCombat: Bool = ShouldUnlockHackNPC(this.GetGameInstance(), this.GetOwnerEntityWeak(), BN_Settings.AlwaysNPCsCombat(), BN_Settings.ProgressionCyberdeckNPCsCombat(), BN_Settings.ProgressionIntelligenceNPCsCombat(), BN_Settings.ProgressionEnemyRarityNPCsCombat());
  let allowControl: Bool = ShouldUnlockHackNPC(this.GetGameInstance(), this.GetOwnerEntityWeak(), BN_Settings.AlwaysNPCsControl(), BN_Settings.ProgressionCyberdeckNPCsControl(), BN_Settings.ProgressionIntelligenceNPCsControl(), BN_Settings.ProgressionEnemyRarityNPCsControl());
  let allowUltimate: Bool = ShouldUnlockHackNPC(this.GetGameInstance(), this.GetOwnerEntityWeak(), BN_Settings.AlwaysNPCsUltimate(), BN_Settings.ProgressionCyberdeckNPCsUltimate(), BN_Settings.ProgressionIntelligenceNPCsUltimate(), BN_Settings.ProgressionEnemyRarityNPCsUltimate());
  let allowPing: Bool = BN_Settings.AlwaysAllowPing() || allowCovert;
  let allowWhistle: Bool = BN_Settings.AlwaysAllowWhistle() || allowCovert;

  let i: Int32 = 0;
  while i < ArraySize(Deref(actions)) {
    if this.IsRemoteQuickHackAction(Deref(actions)[i], context) {
      let puppetAction: ref<PuppetAction> = this.CreatePuppetAction(Deref(actions)[i], instigator);

      if puppetAction.IsQuickHack() {
        // Apply progressive unlock restrictions
        if this.ShouldQuickhackBeInactive(puppetAction, isBreached, allowCovert, allowCombat, allowControl, allowUltimate, allowPing, allowWhistle) {
          this.SetQuickhackInactiveReason(puppetAction, attiudeTowardsPlayer);
        } else if !isPuppetActive || this.Sts_Ep1_12_ActiveForQHack_Hack() {
          puppetAction.SetInactiveWithReason(false, "LocKey#7018");
        }
        ArrayPush(Deref(puppetActions), puppetAction);
      }
    }
    i += 1;
  }
}

// Helper: Checks if action is a remote quickhack type
@addMethod(ScriptedPuppetPS)
private final func IsRemoteQuickHackAction(action: wref<ObjectAction_Record>, const context: script_ref<GetActionsContext>) -> Bool {
  if !Equals(Deref(context).requestType, gamedeviceRequestType.Remote) {
    return false;
  }
  let actionType: gamedataObjectActionType = action.ObjectActionType().Type();
  let isRemoteType: Bool = Equals(actionType, gamedataObjectActionType.MinigameUpload)
                        || Equals(actionType, gamedataObjectActionType.VehicleQuickHack)
                        || Equals(actionType, gamedataObjectActionType.PuppetQuickHack)
                        || Equals(actionType, gamedataObjectActionType.DeviceQuickHack)
                        || Equals(actionType, gamedataObjectActionType.Remote);
  return isRemoteType && TweakDBInterface.GetBool(action.GetID() + t".isQuickHack", false);
}

// Helper: Creates and initializes puppet action from record
@addMethod(ScriptedPuppetPS)
private final func CreatePuppetAction(action: wref<ObjectAction_Record>, instigator: wref<GameObject>) -> ref<PuppetAction> {
  let puppetAction: ref<PuppetAction> = this.GetAction(action);
  puppetAction.SetExecutor(instigator);
  puppetAction.RegisterAsRequester(PersistentID.ExtractEntityID(this.GetID()));
  puppetAction.SetObjectActionID(action.GetID());
  puppetAction.SetUp(this);
  return puppetAction;
}

// Helper: Determines if quickhack should be inactive based on progression requirements
@addMethod(ScriptedPuppetPS)
private final func ShouldQuickhackBeInactive(puppetAction: ref<PuppetAction>, isBreached: Bool, allowCovert: Bool, allowCombat: Bool, allowControl: Bool, allowUltimate: Bool, allowPing: Bool, allowWhistle: Bool) -> Bool {
  // All hacks available if breached or whitelisted
  if isBreached || this.IsWhiteListedForHacks() {
    return false;
  }

  // Check hack category against progression requirements
  let hackCategory: CName = puppetAction.GetObjectActionRecord().HackCategory().EnumName();
  if Equals(hackCategory, n"CovertHack") && allowCovert {
    return false;
  }
  if Equals(hackCategory, n"DamageHack") && allowCombat {
    return false;
  }
  if Equals(hackCategory, n"ControlHack") && allowControl {
    return false;
  }
  if Equals(hackCategory, n"UltimateHack") && allowUltimate {
    return false;
  }

  // Check special always-allowed quickhacks
  if IsDefined(puppetAction as PingSquad) && allowPing {
    return false;
  }
  if Equals(puppetAction.GetObjectActionRecord().ActionName(), n"Whistle") && allowWhistle {
    return false;
  }

  return true;
}

// Helper: Sets appropriate inactive reason message based on NPC attitude
@addMethod(ScriptedPuppetPS)
private final func SetQuickhackInactiveReason(puppetAction: ref<PuppetAction>, attiudeTowardsPlayer: EAIAttitude) -> Void {
  if NotEquals(attiudeTowardsPlayer, EAIAttitude.AIA_Friendly) {
    puppetAction.SetInactiveWithReason(false, "LocKey#7021");
  } else {
    puppetAction.SetInactiveWithReason(false, "LocKey#27694");
  }
}

/*
 * Whitelist of tutorial NPCs that should have all quickhacks available
 * These NPCs bypass progression requirements for proper tutorial flow
 * Credit: KiroKobra (AKA 'Phantum Jak' on Discord)
 */
@addMethod(ScriptedPuppetPS)
protected final func IsWhiteListedForHacks() -> Bool {
  let puppet: wref<ScriptedPuppet> = this.GetOwnerEntity() as ScriptedPuppet;
  let recordID: TweakDBID = puppet.GetRecordID();
  return recordID == t"Character.q000_tutorial_course_01_patroller"
      || recordID == t"Character.q000_tutorial_course_02_enemy_02"
      || recordID == t"Character.q000_tutorial_course_02_enemy_03"
      || recordID == t"Character.q000_tutorial_course_02_enemy_04"
      || recordID == t"Character.q000_tutorial_course_03_guard_01"
      || recordID == t"Character.q000_tutorial_course_03_guard_02"
      || recordID == t"Character.q000_tutorial_course_03_guard_03";
}

/*
 * Keeps NPCs connected to network when incapacitated
 * VANILLA DIFF: Removes this.RemoveLink() call to keep network connection active
 * Allows quickhacking unconscious NPCs per mod design
 */
@replaceMethod(ScriptedPuppet)
protected func OnIncapacitated() -> Void {
  let incapacitatedEvent: ref<IncapacitatedEvent>;
  if this.IsIncapacitated() {
    return;
  }
  if !StatusEffectSystem.ObjectHasStatusEffectWithTag(this, n"CommsNoiseIgnore") {
    incapacitatedEvent = new IncapacitatedEvent();
    GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, incapacitatedEvent, 0.50);
  }
  this.m_securitySupportListener = null;
  // Keep network link active (do not call this.RemoveLink())
  this.EnableLootInteractionWithDelay(this);
  this.EnableInteraction(n"Grapple", false);
  this.EnableInteraction(n"TakedownLayer", false);
  this.EnableInteraction(n"AerialTakedown", false);
  this.EnableInteraction(n"NewPerkFinisherLayer", false);
  StatusEffectHelper.RemoveAllStatusEffectsByType(this, gamedataStatusEffectType.Cloaked);
  if this.IsBoss() {
    this.EnableInteraction(n"BossTakedownLayer", false);
  } else if this.IsMassive() {
    this.EnableInteraction(n"MassiveTargetTakedownLayer", false);
  }
  this.RevokeAllTickets();
  this.GetSensesComponent().ToggleComponent(false);
  this.GetBumpComponent().Toggle(false);
  this.UpdateQuickHackableState(false);
  if this.IsPerformingCallReinforcements() {
    this.HidePhoneCallDuration(gamedataStatPoolType.CallReinforcementProgress);
  }
  this.GetPuppetPS().SetWasIncapacitated(true);
  this.ProcessQuickHackQueueOnDefeat();
  CachedBoolValue.SetDirty(this.m_isActiveCached);
}

/*
 * Disconnects NPCs from network upon death
 * VANILLA DIFF: Calls this.RemoveLink() to disconnect from network (vanilla also does this)
 */
@replaceMethod(ScriptedPuppet)
protected func OnDied() -> Void {
  StatusEffectHelper.RemoveStatusEffect(this, t"BaseStatusEffect.Defeated");
  this.GetPuppetPS().SetIsDead(true);
  this.OnIncapacitated();
  // Remove network link on death
  this.RemoveLink();
  let link: ref<PuppetDeviceLinkPS> = this.GetDeviceLink() as PuppetDeviceLinkPS;
  if IsDefined(link) {
    link.NotifyAboutSpottingPlayer(false);
    GameInstance.GetPersistencySystem(this.GetGame()).QueuePSEvent(link.GetID(), link.GetClassName(), new DestroyLink());
  }
  CachedBoolValue.SetDirty(this.m_isActiveCached);
  QuickHackableQueueHelper.RemoveQuickhackQueue(this.m_gameplayRoleComponent, this.m_currentlyUploadingAction);
}

/*
 * Checks if device is connected to any access point controller
 * Used to determine if unconscious NPC breach is possible
 */
@addMethod(DeviceComponentPS)
public final func IsConnectedToPhysicalAccessPoint() -> Bool {
  let sharedGameplayPS: ref<SharedGameplayPS> = this as SharedGameplayPS;
  if !IsDefined(sharedGameplayPS) {
    return false;
  }
  let apControllers: array<ref<AccessPointControllerPS>> = sharedGameplayPS.GetAccessPoints();
  return ArraySize(apControllers) > 0;
}

/*
 * Adds breach action to unconscious NPC interaction menu
 * Allows breaching unconscious NPCs when connected to network
 */
@wrapMethod(ScriptedPuppetPS)
public final const func GetValidChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>, objectActionsCallbackController: wref<gameObjectActionsCallbackController>, checkPlayerQuickHackList: Bool, choices: script_ref<array<InteractionChoice>>) -> Void {
	if BN_Settings.AllowBreachingUnconsciousNPCs() && this.IsConnectedToAccessPoint() && (!BN_Settings.UnlockIfNoAccessPoint() || this.GetDeviceLink().IsConnectedToPhysicalAccessPoint()) && !this.m_betterNetrunningWasDirectlyBreached {
    ArrayPush(Deref(actions), TweakDBInterface.GetObjectActionRecord(t"Takedown.BreachUnconsciousOfficer"));
  }
	wrappedMethod(actions, context, objectActionsCallbackController, checkPlayerQuickHackList, choices);
}

// Persistent fields for tracking breach state per device type
@addField(ScriptedPuppetPS)
public persistent let m_betterNetrunningWasDirectlyBreached: Bool;

// Device breach state fields
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedBasic: Bool;
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedNPCs: Bool;
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedCameras: Bool;
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedTurrets: Bool;

/*
 * Processes breach minigame results and unlocks quickhacks network-wide
 *
 * VERSION HISTORY:
 * - Release version: Simple breach state tracking without radial unlock
 * - Latest version: Added radial unlock system + network centroid calculation
 *
 * VANILLA DIFF: Complete rewrite to implement progressive unlock per device type
 * Handles loot rewards and progressive unlock per device type
 *
 * NEW FEATURES (Latest):
 * - Radial unlock: Records breach position for standalone device support (50m radius)
 * - Network centroid: Calculates average position of all devices for accurate breach location
 * - Isolated NPC detection: Auto-unlocks NPCs not connected to any network
 */
@replaceMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().HackingMinigame);
  let minigamePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms));

  this.CheckMasterRunnerAchievement(ArraySize(minigamePrograms));
  this.FilterRedundantPrograms(minigamePrograms);

  // Process uploaded breach programs (loot + unlock)
  let lootResult: BreachLootResult = this.ProcessMinigamePrograms(minigamePrograms);
  let unlockFlags: BreachUnlockFlags = lootResult.unlockFlags;

  // Update blackboard to remove processed loot programs
  if lootResult.markForErase {
    ArrayErase(minigamePrograms, lootResult.eraseIndex);
    minigameBB.SetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms, ToVariant(minigamePrograms));
  }

  // Reward loot items
  if lootResult.shouldLoot {
    this.ProcessLoot(lootResult.baseMoney, lootResult.craftingMaterial, lootResult.baseShardDropChance, GameInstance.GetTransactionSystem(this.GetGameInstance()));
  }

  // Execute network-wide daemon effects
  this.ProcessMinigameNetworkActions(this);

  // Mark directly breached NPC
  let entity: wref<Entity> = FromVariant<wref<Entity>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity));
  if IsDefined(entity as ScriptedPuppet) {
    (entity as ScriptedPuppet).GetPS().m_betterNetrunningWasDirectlyBreached = true;
  }

  // Apply device-type-specific unlock to all network devices
  this.ApplyBreachUnlockToDevices(devices, unlockFlags);

  // Record this AccessPoint's breach for radial unlock (standalone devices)
  // STRATEGY: Calculate network centroid (average position of all devices)
  // This provides a more accurate "network center" than using a single random device

  let sumX: Float = 0.0;
  let sumY: Float = 0.0;
  let sumZ: Float = 0.0;
  let validDeviceCount: Int32 = 0;

  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];
    let deviceEntity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;

    if IsDefined(deviceEntity) {
      let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
      sumX += devicePosition.X;
      sumY += devicePosition.Y;
      sumZ += devicePosition.Z;
      validDeviceCount += 1;
    }
    i += 1;
  }

  if validDeviceCount > 0 {
    // Calculate centroid (average position)
    let centroidX: Float = sumX / Cast<Float>(validDeviceCount);
    let centroidY: Float = sumY / Cast<Float>(validDeviceCount);
    let centroidZ: Float = sumZ / Cast<Float>(validDeviceCount);
    let centroid: Vector4 = Vector4(centroidX, centroidY, centroidZ, 1.0);

    BNLog("RefreshSlaves: Recording breach using network centroid (" + ToString(centroidX) + ", " + ToString(centroidY) + ", " + ToString(centroidZ) + ") from " + ToString(validDeviceCount) + " devices");
    RecordAccessPointBreachByPosition(centroid, this.GetGameInstance());
  } else {
    BNLog("RefreshSlaves: WARNING - Could not record breach - no valid device entities found in network");
  }

  // Final money reward
  if lootResult.baseMoney >= 1.00 && this.ShouldRewardMoney() {
    this.RewardMoney(lootResult.baseMoney);
  }
  RPGManager.GiveReward(this.GetGameInstance(), t"RPGActionRewards.Hacking", Cast<StatsObjectID>(this.GetMyEntityID()));
}

// Data structures for breach processing results
public struct BreachUnlockFlags {
  public let unlockBasic: Bool;
  public let unlockNPCs: Bool;
  public let unlockCameras: Bool;
  public let unlockTurrets: Bool;
}

public struct BreachLootResult {
  public let baseMoney: Float;
  public let craftingMaterial: Bool;
  public let baseShardDropChance: Float;
  public let shouldLoot: Bool;
  public let markForErase: Bool;
  public let eraseIndex: Int32;
  public let unlockFlags: BreachUnlockFlags;
}

// Helper: Processes all uploaded breach programs and extracts loot/unlock data
@addMethod(AccessPointControllerPS)
private final func ProcessMinigamePrograms(minigamePrograms: array<TweakDBID>) -> BreachLootResult {
  let result: BreachLootResult;
  let TS: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());

  let i: Int32 = ArraySize(minigamePrograms) - 1;
  while i >= 0 {
    let programID: TweakDBID = minigamePrograms[i];

    // Quest-specific programs
    if programID == t"minigame_v2.FindAnna" {
      AddFact(this.GetPlayerMainObject().GetGame(), n"Kab08Minigame_program_uploaded");
    } else if programID == t"MinigameAction.NetworkLootQ003" {
      TS.GiveItemByItemQuery(this.GetPlayerMainObject(), t"Query.Q003CyberdeckProgram");
    }
    // Datamine loot programs
    else if programID == t"MinigameAction.NetworkDataMineLootAll"
         || programID == t"MinigameAction.NetworkDataMineLootAllAdvanced"
         || programID == t"MinigameAction.NetworkDataMineLootAllMaster" {
      this.ProcessLootProgram(programID, result);
    }
    // Device unlock programs
    else if programID == t"MinigameAction.UnlockQuickhacks"
         || programID == t"MinigameAction.UnlockNPCQuickhacks"
         || programID == t"MinigameAction.UnlockCameraQuickhacks"
         || programID == t"MinigameAction.UnlockTurretQuickhacks" {
      this.ProcessUnlockProgram(programID, result.unlockFlags);
    }
    i -= 1;
  }

  result.eraseIndex = i;
  return result;
}

// Helper: Processes loot program and updates result data
@addMethod(AccessPointControllerPS)
private final func ProcessLootProgram(programID: TweakDBID, result: script_ref<BreachLootResult>) -> Void {
  if programID == t"MinigameAction.NetworkDataMineLootAll" {
    Deref(result).baseMoney += 1.00;
  } else if programID == t"MinigameAction.NetworkDataMineLootAllAdvanced" {
    Deref(result).baseMoney += 1.00;
    Deref(result).craftingMaterial = true;
  } else if programID == t"MinigameAction.NetworkDataMineLootAllMaster" {
    Deref(result).baseShardDropChance += 1.00;
  }
  Deref(result).shouldLoot = true;
  Deref(result).markForErase = true;
}

// Helper: Processes unlock program and updates unlock flags
@addMethod(AccessPointControllerPS)
private final func ProcessUnlockProgram(programID: TweakDBID, flags: script_ref<BreachUnlockFlags>) -> Void {
  if programID == t"MinigameAction.UnlockQuickhacks" {
    Deref(flags).unlockBasic = true;
  } else if programID == t"MinigameAction.UnlockNPCQuickhacks" {
    Deref(flags).unlockNPCs = true;
  } else if programID == t"MinigameAction.UnlockCameraQuickhacks" {
    Deref(flags).unlockCameras = true;
  } else if programID == t"MinigameAction.UnlockTurretQuickhacks" {
    Deref(flags).unlockTurrets = true;
  }
}

// Helper: Applies device-type-specific unlock to all connected devices
@addMethod(AccessPointControllerPS)
private final func ApplyBreachUnlockToDevices(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  let setBreachedSubnetEvent: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  setBreachedSubnetEvent.breachedBasic = unlockFlags.unlockBasic;
  setBreachedSubnetEvent.breachedNPCs = unlockFlags.unlockNPCs;
  setBreachedSubnetEvent.breachedCameras = unlockFlags.unlockCameras;
  setBreachedSubnetEvent.breachedTurrets = unlockFlags.unlockTurrets;

  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];

    // Classic mode: unlock all quickhacks on all devices
    if BN_Settings.EnableClassicMode() {
      this.QueuePSEvent(device, this.ActionSetExposeQuickHacks());
    }
    // Progressive mode: unlock by device type
    else {
      this.ApplyDeviceTypeUnlock(device, unlockFlags);
    }

    this.ProcessMinigameNetworkActions(device);
    this.QueuePSEvent(device, setBreachedSubnetEvent);
    i += 1;
  }
}

// Helper: Unlocks quickhacks based on device type
@addMethod(AccessPointControllerPS)
private final func ApplyDeviceTypeUnlock(device: ref<DeviceComponentPS>, unlockFlags: BreachUnlockFlags) -> Void {
  // NPCs and community proxies
  if IsDefined(device as PuppetDeviceLinkPS) || IsDefined(device as CommunityProxyPS) {
    if unlockFlags.unlockNPCs {
      this.QueuePSEvent(device, this.ActionSetExposeQuickHacks());
    }
  }
  // Cameras
  else if IsDefined(device.GetOwnerEntityWeak() as SurveillanceCamera) {
    if unlockFlags.unlockCameras {
      this.QueuePSEvent(device, this.ActionSetExposeQuickHacks());
    }
  }
  // Turrets
  else if IsDefined(device.GetOwnerEntityWeak() as SecurityTurret) {
    if unlockFlags.unlockTurrets {
      this.QueuePSEvent(device, this.ActionSetExposeQuickHacks());
    }
  }
  // Basic devices
  else {
    if unlockFlags.unlockBasic {
      this.QueuePSEvent(device, this.ActionSetExposeQuickHacks());
    }
  }
}

/*
 * Injects progressive unlock programs into breach minigame
 * Programs appear only if their device type has not been breached yet
 * FIXED: Backdoor devices only allow Root + Surveillance programs
 */
@addMethod(MinigameGenerationRuleScalingPrograms)
public final func InjectBetterNetrunningPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {
  if BN_Settings.EnableClassicMode() {
    return;
  }

  // Get target device state
  let device: ref<SharedGameplayPS>;
  if IsDefined(this.m_entity as ScriptedPuppet) {
    device = (this.m_entity as ScriptedPuppet).GetPS().GetDeviceLink();
  } else {
    device = (this.m_entity as Device).GetDevicePS();
  }

  // Determine breach point type
  let isAccessPoint: Bool = IsDefined(this.m_entity as AccessPoint);
  let isBackdoor: Bool = !isAccessPoint && IsDefined(this.m_entity as Device) && (this.m_entity as Device).GetDevicePS().IsConnectedToBackdoorDevice();
  let isUnconsciousNPC: Bool = IsDefined(this.m_entity as ScriptedPuppet);
  let isNetrunner: Bool = isUnconsciousNPC && (this.m_entity as ScriptedPuppet).IsNetrunnerPuppet();

  // Add unlock programs for un-breached device types
  // Netrunners have full access (all systems)
  // Turrets: Access Points or Netrunners
  if !device.m_betterNetrunningBreachedTurrets && (isAccessPoint || isNetrunner) {
    let turretAccessProgram: MinigameProgramData;
    turretAccessProgram.actionID = t"MinigameAction.UnlockTurretQuickhacks";
    turretAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, turretAccessProgram);
  }
  // Cameras: Access Points, Backdoors, or Netrunners
  if !device.m_betterNetrunningBreachedCameras && (isAccessPoint || isBackdoor || isNetrunner) {
    let cameraAccessProgram: MinigameProgramData;
    cameraAccessProgram.actionID = t"MinigameAction.UnlockCameraQuickhacks";
    cameraAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, cameraAccessProgram);
  }
  // NPCs: Access Points, Unconscious NPCs, or Netrunners
  if !device.m_betterNetrunningBreachedNPCs && (isAccessPoint || isUnconsciousNPC || isNetrunner) {
    let npcAccessProgram: MinigameProgramData;
    npcAccessProgram.actionID = t"MinigameAction.UnlockNPCQuickhacks";
    npcAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, npcAccessProgram);
  }
  // Basic: All breach points
  if !device.m_betterNetrunningBreachedBasic {
    let basicAccessProgram: MinigameProgramData;
    basicAccessProgram.actionID = t"MinigameAction.UnlockQuickhacks";
    basicAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, basicAccessProgram);
  }
}

/*
 * Recursively finds the top-level access point in network hierarchy
 */
@addMethod(AccessPointControllerPS)
public func GetMainframe() -> ref<AccessPointControllerPS> {
  let parents: array<ref<DeviceComponentPS>>;
  this.GetParents(parents);
  let i: Int32 = 0;
  while i < ArraySize(parents) {
    if IsDefined(parents[i] as AccessPointControllerPS) {
      return (parents[i] as AccessPointControllerPS).GetMainframe();
    };
    i += 1;
  };
  return this;
}

/*
 * Allows breach program upload even when all devices of specific type are disabled
 * VANILLA DIFF: Removes IsON() and IsBroken() checks to count all devices regardless of power state
 * Fixes vanilla issue where disabled devices block program availability
 */
@replaceMethod(AccessPointControllerPS)
public final const func CheckConnectedClassTypes() -> ConnectedClassTypes {
  let data: ConnectedClassTypes;
  let puppet: ref<GameObject>;
  let slaves: array<ref<DeviceComponentPS>> = this.GetImmediateSlaves();
  let i: Int32 = 0;

  // Check device existence regardless of power state
  while i < ArraySize(slaves) {
    if data.surveillanceCamera && data.securityTurret && data.puppet {
      break;
    }
    if !data.surveillanceCamera && IsDefined(slaves[i] as SurveillanceCameraControllerPS) {
      data.surveillanceCamera = true;
    } else if !data.securityTurret && IsDefined(slaves[i] as SecurityTurretControllerPS) {
      data.securityTurret = true;
    } else if !data.puppet && IsDefined(slaves[i] as PuppetDeviceLinkPS) {
      puppet = slaves[i].GetOwnerEntityWeak() as GameObject;
      if IsDefined(puppet) && puppet.IsActive() {
        data.puppet = true;
      }
    }
    i += 1;
  }
  return data;
}

/*
 * Handles breach minigame completion for NPCs
 * VANILLA DIFF: Removes TriggerSecuritySystemNotification(ALARM) call on breach failure
 * Intentionally suppresses alarm on breach failure to avoid breaking stealth
 */
@replaceMethod(ScriptedPuppet)
protected cb func OnAccessPointMiniGameStatus(evt: ref<AccessPointMiniGameStatus>) -> Bool {
  let deviceLink: ref<PuppetDeviceLinkPS> = this.GetDeviceLink();

  // Update NPC breach state
  if IsDefined(deviceLink) {
    deviceLink.PerformNPCBreach(evt.minigameState);
    // Vanilla alarm trigger disabled - prevents hostility on failed breach attempt
  }

  // Clean up breach state
  this.ClearNetworkBlackboardState();
  this.RestoreTimeDilation();
  QuickhackModule.RequestRefreshQuickhackMenu(this.GetGame(), this.GetEntityID());
}

// Helper: Clears network state from blackboard
@addMethod(ScriptedPuppet)
private final func ClearNetworkBlackboardState() -> Void {
  let emptyID: EntityID;
  this.GetNetworkBlackboard().SetString(this.GetNetworkBlackboardDef().NetworkName, "");
  this.GetNetworkBlackboard().SetEntityID(this.GetNetworkBlackboardDef().DeviceID, emptyID);
}

// Helper: Restores normal time flow after breach minigame
@addMethod(ScriptedPuppet)
private final func RestoreTimeDilation() -> Void {
  let easeOutCurve: CName = TweakDBInterface.GetCName(t"timeSystem.nanoWireBreach.easeOutCurve", n"DiveEaseOut");
  GameInstance.GetTimeSystem(this.GetGame()).UnsetTimeDilation(n"NetworkBreach", easeOutCurve);
}

// ==================== Progression System Functions ====================
// These functions evaluate player progression requirements (Cyberdeck quality,
// Intelligence stat, Enemy Rarity) to determine quickhack unlock eligibility
//
// VERSION HISTORY:
// - Release version: Used EnemyLevel for NPC progression checks
// - Latest version: Changed to EnemyRarity for more granular control (intentional design change)
//
// RATIONALE: EnemyRarity provides better progression curve:
// - Weak -> Normal -> Strong -> Elite -> Rare -> Boss -> MiniBoss -> MaxTac
// - More nuanced than simple level ranges
// - Aligned with vanilla game's enemy classification system

// Converts config value (1-11) to gamedataQuality enum
public func CyberdeckQualityFromConfigValue(value: Int32) -> gamedataQuality {
  switch(value) {
    case 2:
      return gamedataQuality.CommonPlus;
    case 3:
      return gamedataQuality.Uncommon;
    case 4:
      return gamedataQuality.UncommonPlus;
    case 5:
      return gamedataQuality.Rare;
    case 6:
      return gamedataQuality.RarePlus;
    case 7:
      return gamedataQuality.Epic;
    case 8:
      return gamedataQuality.EpicPlus;
    case 9:
      return gamedataQuality.Legendary;
    case 10:
      return gamedataQuality.LegendaryPlus;
    case 11:
      return gamedataQuality.LegendaryPlusPlus;
  }
  return gamedataQuality.Invalid;
}

// Converts gamedataQuality enum to numeric rank (1-11) for comparison
// Required because CDPR reordered enum values inconsistently
public func CyberdeckQualityToRank(quality: gamedataQuality) -> Int32 {
  switch(quality) {
    case gamedataQuality.Common:
      return 1;
    case gamedataQuality.CommonPlus:
      return 2;
    case gamedataQuality.Uncommon:
      return 3;
    case gamedataQuality.UncommonPlus:
      return 4;
    case gamedataQuality.Rare:
      return 5;
    case gamedataQuality.RarePlus:
      return 6;
    case gamedataQuality.Epic:
      return 7;
    case gamedataQuality.EpicPlus:
      return 8;
    case gamedataQuality.Legendary:
      return 9;
    case gamedataQuality.LegendaryPlus:
      return 10;
    case gamedataQuality.LegendaryPlusPlus:
      return 11;
  }
  return 0;
}

// Checks if player's Cyberdeck meets minimum quality requirement
public func CyberdeckConditionMet(gameInstance: GameInstance, value: Int32) -> Bool {
  let systemReplacementID: ItemID = EquipmentSystem.GetData(GetPlayer(gameInstance)).GetActiveItem(gamedataEquipmentArea.SystemReplacementCW);
  let itemRecord: wref<Item_Record> = RPGManager.GetItemRecord(systemReplacementID);
  let playerCyberdeckQuality: gamedataQuality = itemRecord.Quality().Type();
  let minQuality: gamedataQuality = CyberdeckQualityFromConfigValue(value);
  return CyberdeckQualityToRank(playerCyberdeckQuality) >= CyberdeckQualityToRank(minQuality);
}

// Returns true if Cyberdeck requirement is enabled (value > 1 = Common+)
public func CyberdeckConditionEnabled(value: Int32) -> Bool {
  return value > 1;
}

// Checks if player's Intelligence stat meets minimum requirement
public func IntelligenceConditionMet(gameInstance: GameInstance, value: Int32) -> Bool {
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(gameInstance);
  let playerIntelligence: Int32 = Cast(statsSystem.GetStatValue(Cast(GetPlayer(gameInstance).GetEntityID()), gamedataStatType.Intelligence));
  return playerIntelligence >= value;
}

// Returns true if Intelligence requirement is enabled (value > 3 = base stat)
public func IntelligenceConditionEnabled(value: Int32) -> Bool {
  return value > 3;
}

// Converts NPC rarity enum to numeric rank (1-8) for comparison
public func NPCRarityToRank(rarity: gamedataNPCRarity) -> Int32 {
  switch rarity {
    case gamedataNPCRarity.Trash:
      return 1;
    case gamedataNPCRarity.Weak:
      return 2;
    case gamedataNPCRarity.Normal:
      return 3;
    case gamedataNPCRarity.Rare:
      return 4;
    case gamedataNPCRarity.Officer:
      return 5;
    case gamedataNPCRarity.Elite:
      return 6;
    case gamedataNPCRarity.Boss:
      return 7;
    case gamedataNPCRarity.MaxTac:
      return 8;
  }
  return 0;
}

// Checks if enemy rarity allows quickhack unlock
public func EnemyRarityConditionMet(gameInstance: GameInstance, enemy: wref<Entity>, value: Int32) -> Bool {
  let puppet: wref<ScriptedPuppet> = enemy as ScriptedPuppet;
  if !IsDefined(puppet) {
    return false;
  }
  let rarity: gamedataNPCRarity = puppet.GetNPCRarity();
  return NPCRarityToRank(rarity) <= value;
}

// Returns true if enemy rarity requirement is enabled (value < 8 = not MaxTac)
public func EnemyRarityConditionEnabled(value: Int32) -> Bool {
  return value < 8;
}

// Evaluates if NPC quickhacks should be unlocked based on progression settings
public func ShouldUnlockHackNPC(gameInstance: GameInstance, enemy: wref<Entity>, alwaysAllow: Bool, cyberdeckValue: Int32, intelligenceValue: Int32, enemyRarityValue: Int32) -> Bool {
  if alwaysAllow {
    return true;
  }

  let useConditionCyberdeck: Bool = CyberdeckConditionEnabled(cyberdeckValue);
  let useConditionIntelligence: Bool = IntelligenceConditionEnabled(intelligenceValue);
  let useConditionEnemyRarity: Bool = EnemyRarityConditionEnabled(enemyRarityValue);

  if !useConditionCyberdeck && !useConditionIntelligence && !useConditionEnemyRarity {
    return false;
  }

  let requireAll: Bool = BN_Settings.ProgressionRequireAll();
  let conditionCyberdeck: Bool = CyberdeckConditionMet(gameInstance, cyberdeckValue);
  let conditionIntelligence: Bool = IntelligenceConditionMet(gameInstance, intelligenceValue);
  let conditionEnemyRarity: Bool = EnemyRarityConditionMet(gameInstance, enemy, enemyRarityValue);

  if requireAll {
    return (!useConditionCyberdeck || conditionCyberdeck) && (!useConditionIntelligence || conditionIntelligence) && (!useConditionEnemyRarity || conditionEnemyRarity);
  } else {
    return (useConditionCyberdeck && conditionCyberdeck) || (useConditionIntelligence && conditionIntelligence) || (useConditionEnemyRarity && conditionEnemyRarity);
  }
}

// Evaluates if device quickhacks should be unlocked based on progression settings
public func ShouldUnlockHackDevice(gameInstance: GameInstance, alwaysAllow: Bool, cyberdeckValue: Int32, intelligenceValue: Int32) -> Bool {
  if alwaysAllow {
    return true;
  }

  let useConditionCyberdeck: Bool = CyberdeckConditionEnabled(cyberdeckValue);
  let useConditionIntelligence: Bool = IntelligenceConditionEnabled(intelligenceValue);

  if !useConditionCyberdeck && !useConditionIntelligence {
    return false;
  }

  let requireAll: Bool = BN_Settings.ProgressionRequireAll();
  let conditionCyberdeck: Bool = CyberdeckConditionMet(gameInstance, cyberdeckValue);
  let conditionIntelligence: Bool = IntelligenceConditionMet(gameInstance, intelligenceValue);

  if requireAll {
    return (!useConditionCyberdeck || conditionCyberdeck) && (!useConditionIntelligence || conditionIntelligence);
  } else {
    return (useConditionCyberdeck && conditionCyberdeck) || (useConditionIntelligence && conditionIntelligence);
  }
}

// ==================== Breach State Event System ====================

/*
 * Custom event for propagating breach state across network devices
 * Sent to all devices when subnet is successfully breached
 */
public class SetBreachedSubnet extends ActionBool {

  public let breachedBasic: Bool;
  public let breachedNPCs: Bool;
  public let breachedCameras: Bool;
  public let breachedTurrets: Bool;

  public final func SetProperties() -> Void {
    this.actionName = n"SetBreachedSubnet";
    this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(this.actionName, true, n"SetBreachedSubnet", n"SetBreachedSubnet");
  }

  public func GetTweakDBChoiceRecord() -> String {
    return "SetBreachedSubnet";
  }

  public final static func IsAvailable(device: ref<ScriptableDeviceComponentPS>) -> Bool {
    return true;
  }

  public final static func IsClearanceValid(clearance: ref<Clearance>) -> Bool {
    if Clearance.IsInRange(clearance, 2) {
      return true;
    };
    return false;
  }

  public final static func IsContextValid(const context: script_ref<GetActionsContext>) -> Bool {
    if Equals(Deref(context).requestType, gamedeviceRequestType.Direct) {
      return true;
    };
    return false;
  }

}

// Event handler: Updates device breach state when subnet is breached
@addMethod(SharedGameplayPS)
public func OnSetBreachedSubnet(evt: ref<SetBreachedSubnet>) -> EntityNotificationType {
  if evt.breachedBasic {
    this.m_betterNetrunningBreachedBasic = true;
  }
  if evt.breachedNPCs {
    this.m_betterNetrunningBreachedNPCs = true;
  }
  if evt.breachedCameras {
    this.m_betterNetrunningBreachedCameras = true;
  }
  if evt.breachedTurrets {
    this.m_betterNetrunningBreachedTurrets = true;
  }
  return EntityNotificationType.SendThisEventToEntity;
}