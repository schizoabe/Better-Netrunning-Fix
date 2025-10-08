module BetterNetrunning

import BetterNetrunning.Common.*
import BetterNetrunning.CustomHacking.*
import BetterNetrunningConfig.*

// Import RadialBreach settings when available
@if(ModuleExists("RadialBreach"))
import RadialBreach.Config.*

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

  // Get network connection status and available device types
  if (this.m_entity as GameObject).IsPuppet() {
    connectedToNetwork = true;
    data = (this.m_entity as ScriptedPuppet).GetMasterConnectedClassTypes();
    BNLog("[FilterPlayerPrograms] Target: NPC (always connected)");
  } else {
    connectedToNetwork = (this.m_entity as Device).GetDevicePS().IsConnectedToPhysicalAccessPoint();
    data = (this.m_entity as Device).GetDevicePS().CheckMasterConnectedClassTypes();
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

  BNLog("[FilterPlayerPrograms] Removed " + ToString(removedCount) + " programs, final count: " + ToString(ArraySize(Deref(programs))));
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
  // Only applies to non-access-point, non-computer devices (Backdoor devices like Camera/Door)
  // CRITICAL FIX: Exclude Computers - they should have full network access (same as Access Points)
  if !DaemonFilterUtils.IsRegularDevice(entity) {
    return false;
  }
  return actionID == t"MinigameAction.NetworkDataMineLootAllMaster"
      || actionID == t"MinigameAction.UnlockNPCQuickhacks"
      || actionID == t"MinigameAction.UnlockTurretQuickhacks";
}

// Returns true if access point programs should be restricted (based on user settings)
public func ShouldRemoveAccessPointPrograms(actionID: TweakDBID, miniGameActionRecord: wref<MinigameAction_Record>, isRemoteBreach: Bool) -> Bool {
  // Allow all programs if configured or if remote breach
  if BetterNetrunningSettings.AllowAllDaemonsOnAccessPoints() || isRemoteBreach {
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

// Returns true if already breached programs should be removed
// CRITICAL: This removes daemons that were added by vanilla logic but already completed
public func ShouldRemoveBreachedPrograms(actionID: TweakDBID, entity: wref<GameObject>) -> Bool {
  // Only applies to devices (not NPCs)
  if !IsDefined(entity as Device) {
    return false;
  }

  let devicePS: ref<DeviceComponentPS> = (entity as Device).GetDevicePS();
  let sharedPS: ref<SharedGameplayPS> = devicePS as SharedGameplayPS;

  if !IsDefined(sharedPS) {
    return false;
  }

  // Check each daemon type against breach status
  if actionID == t"MinigameAction.UnlockQuickhacks" && sharedPS.m_betterNetrunningBreachedBasic {
    return true;
  }
  if actionID == t"MinigameAction.UnlockNPCQuickhacks" && sharedPS.m_betterNetrunningBreachedNPCs {
    return true;
  }
  if actionID == t"MinigameAction.UnlockCameraQuickhacks" && sharedPS.m_betterNetrunningBreachedCameras {
    return true;
  }
  if actionID == t"MinigameAction.UnlockTurretQuickhacks" && sharedPS.m_betterNetrunningBreachedTurrets {
    return true;
  }

  return false;
}

// Returns true if programs should be removed based on device type availability
public func ShouldRemoveDeviceTypePrograms(actionID: TweakDBID, miniGameActionRecord: wref<MinigameAction_Record>, data: ConnectedClassTypes) -> Bool {
  // In RadialUnlock mode, delegate filtering to RadialBreach's physical proximity-based system if installed
  // If RadialBreach is not installed, disable network-based filtering to reduce UI noise
  if !BetterNetrunningSettings.UnlockIfNoAccessPoint() {
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
  if !BetterNetrunningSettings.DisableDatamineOneTwo() {
    return false;
  }
  return Equals(actionID, t"MinigameAction.NetworkDataMineLootAllAdvanced")
      || Equals(actionID, t"MinigameAction.NetworkDataMineLootAll");
}

// ==================== Utility Functions ====================

// Returns true if the action is a CustomHackingSystem RemoteBreach action
public func IsCustomRemoteBreachAction(className: CName) -> Bool {
  return Equals(className, n"BetterNetrunning.CustomHacking.RemoteBreachAction")
      || Equals(className, n"BetterNetrunning.CustomHacking.VehicleRemoteBreachAction")
      || Equals(className, n"BetterNetrunning.CustomHacking.DeviceRemoteBreachAction");
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
    if !BetterNetrunningSettings.BlockTurretDisableQuickhack() {
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
    if !BetterNetrunningSettings.BlockCameraDisableQuickhack() {
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
 *
 * REFACTORED: Reduced from 100 lines with 6-level nesting to 25 lines with 2-level nesting
 * Using Extract Method pattern to improve readability and maintainability
 */
@addMethod(ScriptableDeviceComponentPS)
public final func SetActionsInactiveUnbreached(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Step 1: Get device classification
  let deviceInfo: DeviceBreachInfo = this.GetDeviceBreachInfo();

  // Step 2: Update standalone device breach state (radial unlock)
  this.UpdateStandaloneDeviceBreachState(deviceInfo);

  // Step 3: Calculate device permissions based on breach state + progression
  let permissions: DevicePermissions = this.CalculateDevicePermissions(deviceInfo);

  // Step 4: Apply permissions to all actions
  this.ApplyPermissionsToActions(actions, deviceInfo, permissions);
}

// Helper: Gets device classification and network status
@addMethod(ScriptableDeviceComponentPS)
private final func GetDeviceBreachInfo() -> DeviceBreachInfo {
  let info: DeviceBreachInfo;
  info.isCamera = DaemonFilterUtils.IsCamera(this);
  info.isTurret = DaemonFilterUtils.IsTurret(this);

  let sharedPS: ref<SharedGameplayPS> = this;
  if IsDefined(sharedPS) {
    let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
    info.isStandaloneDevice = ArraySize(apControllers) == 0;
  }

  return info;
}

// Helper: Updates breach flags for standalone devices within radial breach radius
@addMethod(ScriptableDeviceComponentPS)
private final func UpdateStandaloneDeviceBreachState(deviceInfo: DeviceBreachInfo) -> Void {
  // Only process standalone devices that are within radial breach radius
  if !deviceInfo.isStandaloneDevice || !ShouldUnlockStandaloneDevice(this, this.GetGameInstance()) {
    return;
  }

  // PERSISTENCE FIX: Mark device as permanently breached to survive save/load
  if !this.m_betterNetrunningBreachedBasic {
    this.m_betterNetrunningBreachedBasic = true;
  }
  if deviceInfo.isCamera && !this.m_betterNetrunningBreachedCameras {
    this.m_betterNetrunningBreachedCameras = true;
  }
  if deviceInfo.isTurret && !this.m_betterNetrunningBreachedTurrets {
    this.m_betterNetrunningBreachedTurrets = true;
  }
}

// Helper: Calculates permissions based on breach state and player progression
@addMethod(ScriptableDeviceComponentPS)
private final func CalculateDevicePermissions(deviceInfo: DeviceBreachInfo) -> DevicePermissions {
  let permissions: DevicePermissions;
  let gameInstance: GameInstance = this.GetGameInstance();

  // Device-type permissions: Breached OR progression requirements met
  permissions.allowCameras = this.m_betterNetrunningBreachedCameras || ShouldUnlockHackDevice(gameInstance, BetterNetrunningSettings.AlwaysCameras(), BetterNetrunningSettings.ProgressionCyberdeckCameras(), BetterNetrunningSettings.ProgressionIntelligenceCameras());
  permissions.allowTurrets = this.m_betterNetrunningBreachedTurrets || ShouldUnlockHackDevice(gameInstance, BetterNetrunningSettings.AlwaysTurrets(), BetterNetrunningSettings.ProgressionCyberdeckTurrets(), BetterNetrunningSettings.ProgressionIntelligenceTurrets());
  permissions.allowBasicDevices = this.m_betterNetrunningBreachedBasic || ShouldUnlockHackDevice(gameInstance, BetterNetrunningSettings.AlwaysBasicDevices(), BetterNetrunningSettings.ProgressionCyberdeckBasicDevices(), BetterNetrunningSettings.ProgressionIntelligenceBasicDevices());

  // Special always-allowed quickhacks
  permissions.allowPing = BetterNetrunningSettings.AlwaysAllowPing();
  permissions.allowDistraction = BetterNetrunningSettings.AlwaysAllowDistract();

  return permissions;
}

// Helper: Applies calculated permissions to all actions
@addMethod(ScriptableDeviceComponentPS)
private final func ApplyPermissionsToActions(actions: script_ref<array<ref<DeviceAction>>>, deviceInfo: DeviceBreachInfo, permissions: DevicePermissions) -> Void {
  let i: Int32 = 0;
  while i < ArraySize(Deref(actions)) {
    let sAction: ref<ScriptableDeviceAction> = (Deref(actions)[i] as ScriptableDeviceAction);

    if IsDefined(sAction) && !this.ShouldAllowAction(sAction, deviceInfo.isCamera, deviceInfo.isTurret, permissions.allowCameras, permissions.allowTurrets, permissions.allowBasicDevices, permissions.allowPing, permissions.allowDistraction) {
      sAction.SetInactive();
      sAction.SetInactiveReason("LocKey#7021");
    }

    i += 1;
  }
}

// Helper: Determines if an action should be allowed based on device type and progression
@addMethod(ScriptableDeviceComponentPS)
private final func ShouldAllowAction(action: ref<ScriptableDeviceAction>, isCamera: Bool, isTurret: Bool, allowCameras: Bool, allowTurrets: Bool, allowBasicDevices: Bool, allowPing: Bool, allowDistraction: Bool) -> Bool {
  let className: CName = action.GetClassName();

  // RemoteBreachAction must ALWAYS be allowed (CustomHackingSystem integration)
  if IsCustomRemoteBreachAction(className) {
    return true;
  }

  // Always-allowed quickhacks
  if Equals(className, n"PingDevice") && allowPing {
    return true;
  }
  if Equals(className, n"QuickHackDistraction") && allowDistraction {
    return true;
  }

  // Device-type-specific permissions
  if isCamera && allowCameras {
    return true;
  }
  if isTurret && allowTurrets {
    return true;
  }
  if !isCamera && !isTurret && allowBasicDevices {
    return true;
  }

  return false;
}

/*
 * Finalizes device quickhack actions before presenting to player
 * VANILLA DIFF: Removes IsBreached() check on ActionRemoteBreach() to allow breach action when not yet breached
 * Handles backdoor actions, power state checks, and RPG availability (including equipment check)
 *
 * ARCHITECTURE: Conditional compilation with shared logic extraction
 * - @if(ModuleExists("HackingExtensions")): Custom RemoteBreach support
 * - @if(!ModuleExists("HackingExtensions")): Fallback (no custom breach)
 * - Common logic extracted to helper methods for maintainability
 */
@if(ModuleExists("HackingExtensions"))
@replaceMethod(ScriptableDeviceComponentPS)
protected final func FinalizeGetQuickHackActions(outActions: script_ref<array<ref<DeviceAction>>>, const context: script_ref<GetActionsContext>) -> Void {
  // Common early exit checks
  if !this.ShouldProcessQuickHackActions(outActions) {
    return;
  }

  // Add backdoor breach and ping actions (with Custom RemoteBreach)
  if this.IsConnectedToBackdoorDevice() {
    this.TryAddCustomRemoteBreach(outActions);
    this.AddPingAction(outActions);
  } else if this.HasNetworkBackdoor() {
    this.AddPingAction(outActions);
  }

  // Apply common restrictions (power state, RPG checks, illegality, etc.)
  this.ApplyCommonQuickHackRestrictions(outActions, context);

  // NOTE: MoveVehicleRemoteBreachToBottom is NOT called here
  // It must be called in GetRemoteActions AFTER all @wrapMethod processing completes
}

@if(!ModuleExists("HackingExtensions"))
@replaceMethod(ScriptableDeviceComponentPS)
protected final func FinalizeGetQuickHackActions(outActions: script_ref<array<ref<DeviceAction>>>, const context: script_ref<GetActionsContext>) -> Void {
  // Common early exit checks
  if !this.ShouldProcessQuickHackActions(outActions) {
    return;
  }

  // Add backdoor breach and ping actions (vanilla RemoteBreach fallback)
  if this.IsConnectedToBackdoorDevice() {
    let currentAction: ref<ScriptableDeviceAction> = this.ActionRemoteBreach();
    ArrayPush(Deref(outActions), currentAction);
    this.AddPingAction(outActions);
  } else if this.HasNetworkBackdoor() {
    this.AddPingAction(outActions);
  }

  // Apply common restrictions (power state, RPG checks, illegality, etc.)
  this.ApplyCommonQuickHackRestrictions(outActions, context);

  // NOTE: MoveVehicleRemoteBreachToBottom is NOT needed for vanilla RemoteBreach
}

// ==================== Helper Methods (Shared Logic) ====================

/*
 * Wrapper for TryAddMissingCustomRemoteBreach (conditional compilation support)
 * Only compiled when HackingExtensions module exists
 */
@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func TryAddMissingCustomRemoteBreachWrapper(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  this.TryAddMissingCustomRemoteBreach(outActions);
}

/*
 * Stub wrapper when HackingExtensions module does not exist
 */
@if(!ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func TryAddMissingCustomRemoteBreachWrapper(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // No-op: CustomHackingSystem not installed
}

/*
 * Common early exit checks for FinalizeGetQuickHackActions
 * Returns true if processing should continue, false if should exit early
 */
@addMethod(ScriptableDeviceComponentPS)
private final func ShouldProcessQuickHackActions(outActions: script_ref<array<ref<DeviceAction>>>) -> Bool {
  // Early exit if device is not in nominal state
  if NotEquals(this.GetDurabilityState(), EDeviceDurabilityState.NOMINAL) {
    return false;
  }
  // Early exit if quickhacks are disabled
  if this.m_disableQuickHacks {
    if ArraySize(Deref(outActions)) > 0 {
      ArrayClear(Deref(outActions));
    }
    return false;
  }
  return true;
}

/*
 * Adds Ping action to backdoor device
 * Common logic shared by both conditional compilation versions
 */
@addMethod(ScriptableDeviceComponentPS)
private final func AddPingAction(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let currentAction: ref<ScriptableDeviceAction> = this.ActionPing();
  currentAction.SetInactiveWithReason(!this.GetNetworkSystem().HasActivePing(this.GetMyEntityID()), "LocKey#49279");
  ArrayPush(Deref(outActions), currentAction);
}

/*
 * Override MarkActionsAsQuickHacks to support CustomAccessBreach
 * CRITICAL FIX: CustomAccessBreach extends PuppetAction, not ScriptableDeviceAction,
 * so vanilla MarkActionsAsQuickHacks skips it. This causes RemoteBreach to not appear in UI.
 *
 * MOD COMPATIBILITY: Changed from @replaceMethod to @wrapMethod for better compatibility.
 * Vanilla processing is preserved, CustomAccessBreach support is added as extension.
 */
@if(ModuleExists("HackingExtensions"))
@wrapMethod(ScriptableDeviceComponentPS)
protected final func MarkActionsAsQuickHacks(actionsToMark: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Execute vanilla logic first (handles all ScriptableDeviceAction)
  wrappedMethod(actionsToMark);

  // EXTENSION: Add CustomAccessBreach support (BetterNetrunning-specific)
  let i: Int32 = 0;
  while i < ArraySize(Deref(actionsToMark)) {
    // CRITICAL: Also check for CustomAccessBreach (CustomHackingSystem actions)
    // CustomAccessBreach extends PuppetAction, not ScriptableDeviceAction
    let customBreachAction: ref<CustomAccessBreach> = Deref(actionsToMark)[i] as CustomAccessBreach;
    if IsDefined(customBreachAction) {
      // CustomAccessBreach doesn't have SetAsQuickHack(), but PuppetAction does
      // Cast to PuppetAction to access the method
      let puppetAction: ref<PuppetAction> = customBreachAction as PuppetAction;
      if IsDefined(puppetAction) {
        puppetAction.SetAsQuickHack();
      }
    }

    i += 1;
  }
}

/*
 * Applies common quickhack restrictions (power state, RPG checks, illegality)
 * Common logic shared by both conditional compilation versions
 */
@addMethod(ScriptableDeviceComponentPS)
private final func ApplyCommonQuickHackRestrictions(outActions: script_ref<array<ref<DeviceAction>>>, const context: script_ref<GetActionsContext>) -> Void {
  // Disable all actions if device is unpowered
  if this.IsUnpowered() {
    ScriptableDeviceComponentPS.SetActionsInactiveAll(outActions, "LocKey#7013");
  }

  // Apply RPG system restrictions (skill checks, illegality, equipment check, etc.)
  this.EvaluateActionsRPGAvailabilty(outActions, context);
  this.SetActionIllegality(outActions, this.m_illegalActions.quickHacks);
  this.MarkActionsAsQuickHacks(outActions);
  this.SetActionsQuickHacksExecutioner(outActions);

  // NEW REQUIREMENT: Remove Custom RemoteBreach if device is already unlocked
  // This must be called AFTER all actions are added to prevent re-adding
  this.RemoveCustomRemoteBreachIfUnlocked(outActions);

  // NOTE: MoveVehicleRemoteBreachToBottom is NOT called here
  // It must be called AFTER TryAddCustomRemoteBreach in FinalizeGetQuickHackActions
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

  // CRITICAL FIX: Some devices (Jukebox, NetrunnerChair, DisposalDevice) override GetQuickHackActions()
  // without calling wrappedMethod(), causing TweakDB RemoteBreach to not be removed.
  // Remove ALL vanilla RemoteBreach actions here as a final cleanup step.
  let i: Int32 = ArraySize(outActions) - 1;
  let hasCustomRemoteBreach: Bool = false;

  while i >= 0 {
    let action: ref<DeviceAction> = outActions[i];
    if IsDefined(action) && Equals(action.actionName, n"RemoteBreach") {
      let className: CName = action.GetClassName();
      let isCustomAction: Bool = IsCustomRemoteBreachAction(className);

      if isCustomAction {
        hasCustomRemoteBreach = true;
      } else {
        ArrayErase(outActions, i);
      }
    }
    i -= 1;
  }

  // CRITICAL FIX: Add Custom RemoteBreach if not present (for devices that don't call wrappedMethod)
  // This ensures NetrunnerChair, Jukebox, DisposalDevice, TV, etc. get Custom RemoteBreach
  if !hasCustomRemoteBreach && !BetterNetrunningSettings.UnlockIfNoAccessPoint() {
    this.TryAddMissingCustomRemoteBreachWrapper(outActions);
  }

  // NEW REQUIREMENT: Remove Custom RemoteBreach if device is already unlocked (except Vehicles)
  // Vehicles always show RemoteBreach regardless of unlock state
  this.RemoveCustomRemoteBreachIfUnlocked(outActions);

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
  let isUnsecuredNetwork: Bool = !hasAccessPoint && BetterNetrunningSettings.UnlockIfNoAccessPoint();

  // Handle sequencer lock or breach state
  if this.IsLockedViaSequencer() {
    // Sequencer locked: only allow RemoteBreach action
    ScriptableDeviceComponentPS.SetActionsInactiveAll(outActions, "LocKey#7021", n"RemoteBreach");
  } else if !BetterNetrunningSettings.EnableClassicMode() && !isUnsecuredNetwork {
    // Progressive Mode: apply device-type-specific unlock restrictions (unless unsecured network)
    this.SetActionsInactiveUnbreached(outActions);
  }

  // CRITICAL FIX: Move Vehicle RemoteBreach to bottom AFTER all processing
  // This must be the LAST operation to ensure RemoteBreach stays at bottom
  this.MoveVehicleRemoteBreachToBottom(outActions);

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
 *
 * REFACTORED: Reduced from 58 lines with 3-level nesting to 45 lines with 2-level nesting
 * Using Extract Method pattern for permission calculation
 */
@replaceMethod(ScriptedPuppetPS)
public final const func GetAllChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>, puppetActions: script_ref<array<ref<PuppetAction>>>) -> Void {
  // Step 1: Calculate NPC permissions (breach state + progression)
  let permissions: NPCHackPermissions = this.CalculateNPCHackPermissions();

  // Step 2: Get activity state
  let isPuppetActive: Bool = ScriptedPuppet.IsActive(this.GetOwnerEntity());
  let attiudeTowardsPlayer: EAIAttitude = this.GetOwnerEntity().GetAttitudeTowards(GetPlayer(this.GetGameInstance()));
  let instigator: wref<GameObject> = Deref(context).processInitiatorObject;

  // Step 3: Process all actions
  let i: Int32 = 0;
  while i < ArraySize(Deref(actions)) {
    if this.IsRemoteQuickHackAction(Deref(actions)[i], context) {
      let puppetAction: ref<PuppetAction> = this.CreatePuppetAction(Deref(actions)[i], instigator);

      if puppetAction.IsQuickHack() {
        // Apply progressive unlock restrictions
        if this.ShouldQuickhackBeInactive(puppetAction, permissions) {
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

// Helper: Calculates NPC hack permissions based on breach state and progression
@addMethod(ScriptedPuppetPS)
private final func CalculateNPCHackPermissions() -> NPCHackPermissions {
  let permissions: NPCHackPermissions;
  let gameInstance: GameInstance = this.GetGameInstance();
  let npc: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;

  // Check breach status (m_quickHacksExposed is breach state, not menu visibility)
  permissions.isBreached = this.m_quickHacksExposed;

  // Check if NPC is connected to any network
  let isConnectedToNetwork: Bool = this.IsConnectedToAccessPoint();

  // Auto-unlock if not connected to any network (isolated enemies)
  if !isConnectedToNetwork {
    permissions.isBreached = true;
  }

  // Evaluate progression-based unlock conditions for hack categories
  permissions.allowCovert = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsCovert(), BetterNetrunningSettings.ProgressionCyberdeckNPCsCovert(), BetterNetrunningSettings.ProgressionIntelligenceNPCsCovert(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsCovert());
  permissions.allowCombat = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsCombat(), BetterNetrunningSettings.ProgressionCyberdeckNPCsCombat(), BetterNetrunningSettings.ProgressionIntelligenceNPCsCombat(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsCombat());
  permissions.allowControl = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsControl(), BetterNetrunningSettings.ProgressionCyberdeckNPCsControl(), BetterNetrunningSettings.ProgressionIntelligenceNPCsControl(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsControl());
  permissions.allowUltimate = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsUltimate(), BetterNetrunningSettings.ProgressionCyberdeckNPCsUltimate(), BetterNetrunningSettings.ProgressionIntelligenceNPCsUltimate(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsUltimate());
  permissions.allowPing = BetterNetrunningSettings.AlwaysAllowPing() || permissions.allowCovert;
  permissions.allowWhistle = BetterNetrunningSettings.AlwaysAllowWhistle() || permissions.allowCovert;

  return permissions;
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
private final func ShouldQuickhackBeInactive(puppetAction: ref<PuppetAction>, permissions: NPCHackPermissions) -> Bool {
  // All hacks available if breached or whitelisted
  if permissions.isBreached || this.IsWhiteListedForHacks() {
    return false;
  }

  // Check hack category against progression requirements
  let hackCategory: CName = puppetAction.GetObjectActionRecord().HackCategory().EnumName();
  if Equals(hackCategory, n"CovertHack") && permissions.allowCovert {
    return false;
  }
  if Equals(hackCategory, n"DamageHack") && permissions.allowCombat {
    return false;
  }
  if Equals(hackCategory, n"ControlHack") && permissions.allowControl {
    return false;
  }
  if Equals(hackCategory, n"UltimateHack") && permissions.allowUltimate {
    return false;
  }

  // Check special always-allowed quickhacks
  if IsDefined(puppetAction as PingSquad) && permissions.allowPing {
    return false;
  }
  if Equals(puppetAction.GetObjectActionRecord().ActionName(), n"Whistle") && permissions.allowWhistle {
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
 * VANILLA DIFF: Identical to vanilla behavior (removed @replaceMethod for better mod compatibility)
 *
 * MOD COMPATIBILITY: This method is no longer overridden as it's identical to vanilla.
 * Better Netrunning now delegates death handling to vanilla logic.
 */
// @replaceMethod(ScriptedPuppet)
// REMOVED: This override is unnecessary (100% identical to vanilla)

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
	if BetterNetrunningSettings.AllowBreachingUnconsciousNPCs() && this.IsConnectedToAccessPoint() && (!BetterNetrunningSettings.UnlockIfNoAccessPoint() || this.GetDeviceLink().IsConnectedToPhysicalAccessPoint()) && !this.m_betterNetrunningWasDirectlyBreached {
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
 *
 * REFACTORED: Reduced from 95 lines with 5-level nesting to 30 lines with 2-level nesting
 * Using Composed Method pattern for improved readability
 */
@replaceMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  // Step 1: Get active minigame programs from blackboard
  let minigamePrograms: array<TweakDBID> = this.GetActiveMinigamePrograms();

  // Step 2: Process breach programs and extract rewards
  let lootResult: BreachLootResult = this.ProcessMinigamePrograms(minigamePrograms);

  // Step 3: Update blackboard and reward player
  this.UpdateMinigameBlackboard(minigamePrograms, lootResult);
  this.ProcessLootRewards(lootResult);

  // Step 4: Apply network-wide effects
  this.ApplyNetworkEffects(devices, lootResult.unlockFlags);

  // Step 5: Record breach position for radial unlock
  this.RecordNetworkBreachPosition(devices);

  // Step 6: Final rewards
  this.ProcessFinalRewards(lootResult);
}

// Helper: Gets hacking minigame blackboard (centralized access)
@addMethod(AccessPointControllerPS)
private final func GetMinigameBlackboard() -> ref<IBlackboard> {
  return GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().HackingMinigame);
}

// Helper: Retrieves active minigame programs from blackboard
@addMethod(AccessPointControllerPS)
private final func GetActiveMinigamePrograms() -> array<TweakDBID> {
  let minigameBB: ref<IBlackboard> = this.GetMinigameBlackboard();
  let minigamePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms));

  this.CheckMasterRunnerAchievement(ArraySize(minigamePrograms));
  this.FilterRedundantPrograms(minigamePrograms);

  return minigamePrograms;
}

// Helper: Updates blackboard with processed programs
@addMethod(AccessPointControllerPS)
private final func UpdateMinigameBlackboard(minigamePrograms: array<TweakDBID>, lootResult: BreachLootResult) -> Void {
  if !lootResult.markForErase {
    return;
  }

  ArrayErase(minigamePrograms, lootResult.eraseIndex);
  this.GetMinigameBlackboard().SetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms, ToVariant(minigamePrograms));
}

// Helper: Processes and rewards loot items
@addMethod(AccessPointControllerPS)
private final func ProcessLootRewards(lootResult: BreachLootResult) -> Void {
  if !lootResult.shouldLoot {
    return;
  }

  this.ProcessLoot(lootResult.baseMoney, lootResult.craftingMaterial, lootResult.baseShardDropChance, GameInstance.GetTransactionSystem(this.GetGameInstance()));
}

// Helper: Applies network-wide breach effects
@addMethod(AccessPointControllerPS)
private final func ApplyNetworkEffects(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  // Execute minigame actions on access point itself
  this.ProcessMinigameNetworkActions(this);

  // Mark directly breached NPC
  let entity: wref<Entity> = FromVariant<wref<Entity>>(this.GetMinigameBlackboard().GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity));
  if IsDefined(entity as ScriptedPuppet) {
    (entity as ScriptedPuppet).GetPS().m_betterNetrunningWasDirectlyBreached = true;
  }

  // Apply device-type-specific unlock to all network devices
  this.ApplyBreachUnlockToDevices(devices, unlockFlags);
}

// Helper: Records network centroid position for radial unlock
@addMethod(AccessPointControllerPS)
private final func RecordNetworkBreachPosition(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  let centroid: Vector4 = this.CalculateNetworkCentroid(devices);

  // Only record if we found valid devices
  if centroid.X >= -999000.0 {
    RecordAccessPointBreachByPosition(centroid, this.GetGameInstance());
  }
}

// Helper: Calculates average position of all network devices
@addMethod(AccessPointControllerPS)
private final func CalculateNetworkCentroid(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Vector4 {
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

  // Return centroid if valid, otherwise return invalid position
  if validDeviceCount > 0 {
    return Vector4(sumX / Cast<Float>(validDeviceCount), sumY / Cast<Float>(validDeviceCount), sumZ / Cast<Float>(validDeviceCount), 1.0);
  }

  return Vector4(-999999.0, -999999.0, -999999.0, 1.0);
}

// Helper: Processes final rewards (money + XP)
@addMethod(AccessPointControllerPS)
private final func ProcessFinalRewards(lootResult: BreachLootResult) -> Void {
  if lootResult.baseMoney >= 1.00 && this.ShouldRewardMoney() {
    this.RewardMoney(lootResult.baseMoney);
  }
  RPGManager.GiveReward(this.GetGameInstance(), t"RPGActionRewards.Hacking", Cast<StatsObjectID>(this.GetMyEntityID()));
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

// Helper: Applies device-type-specific unlock to all connected devices (WITH RadialBreach)
@if(ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
private final func ApplyBreachUnlockToDevices(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  let setBreachedSubnetEvent: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  setBreachedSubnetEvent.breachedBasic = unlockFlags.unlockBasic;
  setBreachedSubnetEvent.breachedNPCs = unlockFlags.unlockNPCs;
  setBreachedSubnetEvent.breachedCameras = unlockFlags.unlockCameras;
  setBreachedSubnetEvent.breachedTurrets = unlockFlags.unlockTurrets;

  // RadialBreach Integration - Physical Distance Filtering
  let breachPosition: Vector4 = this.GetBreachPosition();
  let maxDistance: Float = this.GetRadialBreachRange();
  let shouldUseRadialFiltering: Bool = breachPosition.X >= -999000.0;

  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];

    // Physical distance check (RadialBreach integration)
    let shouldUnlock: Bool = !shouldUseRadialFiltering || this.IsDeviceWithinBreachRadius(device, breachPosition, maxDistance);

    if shouldUnlock {
      // Classic mode: unlock all quickhacks on all devices
      if BetterNetrunningSettings.EnableClassicMode() {
        this.QueuePSEvent(device, this.ActionSetExposeQuickHacks());
      }
      // Progressive mode: unlock by device type
      else {
        this.ApplyDeviceTypeUnlock(device, unlockFlags);
      }

      this.ProcessMinigameNetworkActions(device);
      this.QueuePSEvent(device, setBreachedSubnetEvent);
    }

    i += 1;
  }
}

// Helper: Applies device-type-specific unlock to all connected devices (WITHOUT RadialBreach)
@if(!ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
private final func ApplyBreachUnlockToDevices(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  let setBreachedSubnetEvent: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  setBreachedSubnetEvent.breachedBasic = unlockFlags.unlockBasic;
  setBreachedSubnetEvent.breachedNPCs = unlockFlags.unlockNPCs;
  setBreachedSubnetEvent.breachedCameras = unlockFlags.unlockCameras;
  setBreachedSubnetEvent.breachedTurrets = unlockFlags.unlockTurrets;

  // No RadialBreach filtering - unlock all devices in network
  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];

    // Classic mode: unlock all quickhacks on all devices
    if BetterNetrunningSettings.EnableClassicMode() {
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

// Helper: Unlocks quickhacks based on device type (using DeviceTypeUtils)
@addMethod(AccessPointControllerPS)
private final func ApplyDeviceTypeUnlock(device: ref<DeviceComponentPS>, unlockFlags: BreachUnlockFlags) -> Void {
  let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;
  if !IsDefined(sharedPS) {
    return;
  }

  // Use DeviceTypeUtils for centralized device type detection
  let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

  // Check if this device type should be unlocked based on flags
  if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
    return;
  }

  // Unlock quickhacks and set breach flag
  this.QueuePSEvent(device, this.ActionSetExposeQuickHacks());
  DeviceTypeUtils.SetBreached(deviceType, sharedPS, true);
}

// ============================================================================
// RADIALBREACH INTEGRATION HELPERS
// ============================================================================

// Gets the breach range from RadialBreach settings (or default 50m)
// Automatically syncs with RadialBreach user configuration
@if(ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
private final func GetRadialBreachRange() -> Float {
  // Reference RadialBreach's breachRange setting directly
  // This automatically syncs with user's Native Settings UI configuration
  let settings: ref<RadialBreachSettings> = new RadialBreachSettings();
  return settings.breachRange;
}

// Fallback when RadialBreach is not installed - use default 50m
@if(!ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
private final func GetRadialBreachRange() -> Float {
  return 50.0; // Default range when RadialBreach not installed
}

// Gets the breach position (AccessPoint position or player position as fallback)
@addMethod(AccessPointControllerPS)
private final func GetBreachPosition() -> Vector4 {
  // Try to get AccessPoint entity position
  let apEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
  if IsDefined(apEntity) {
    let position: Vector4 = apEntity.GetWorldPosition();
      return position;
  }

  // Fallback: player position
  let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
  if IsDefined(player) {
    let position: Vector4 = player.GetWorldPosition();
      return position;
  }

  // ✁EFIXED: Error signal instead of zero vector to prevent filtering all devices
  // Zero vector would cause all devices to be filtered out (distance > 50m from world origin)
  BNLog("[GetBreachPosition] ERROR: Could not get breach position, returning error signal");
  return Vector4(-999999.0, -999999.0, -999999.0, 1.0);
}

// Checks if a device is within breach radius
@addMethod(AccessPointControllerPS)
private final func IsDeviceWithinBreachRadius(device: ref<DeviceComponentPS>, breachPosition: Vector4, maxDistance: Float) -> Bool {
  let deviceEntity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;
  if !IsDefined(deviceEntity) {
      return true; // Fallback: allow unlock if entity not found
  }

  let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
  let distance: Float = Vector4.Distance(breachPosition, devicePosition);

  let withinRadius: Bool = distance <= maxDistance;

  if withinRadius {
    } else {
    }

  return withinRadius;
}

// ============================================================================
// END RADIALBREACH INTEGRATION
// ============================================================================

/*
 * Injects progressive unlock programs into breach minigame
 * Programs appear only if their device type has not been breached yet
 * FIXED: Backdoor devices only allow Root + Surveillance programs
 */
@addMethod(MinigameGenerationRuleScalingPrograms)
public final func InjectBetterNetrunningPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {

  if BetterNetrunningSettings.EnableClassicMode() {
      return;
  }

  // Get target device state
  let device: ref<SharedGameplayPS>;
  if IsDefined(this.m_entity as ScriptedPuppet) {
    device = (this.m_entity as ScriptedPuppet).GetPS().GetDeviceLink();
    } else {
    device = (this.m_entity as Device).GetDevicePS();
    }

  if !IsDefined(device) {
    BNLog("[InjectBetterNetrunningPrograms] ERROR: device (SharedGameplayPS) is null!");
    return;
  }

  // Determine breach point type
  let isAccessPoint: Bool = IsDefined(this.m_entity as AccessPoint);
  let isUnconsciousNPC: Bool = IsDefined(this.m_entity as ScriptedPuppet);
  let isNetrunner: Bool = isUnconsciousNPC && (this.m_entity as ScriptedPuppet).IsNetrunnerPuppet();

  // CRITICAL FIX: Remote breach support (CustomHackingSystem integration)
  // Remote breach should behave like Access Point breach (full network access)
  // PRIORITY: Check isComputer BEFORE isBackdoor to avoid misclassification
  let devicePS: ref<ScriptableDeviceComponentPS> = (this.m_entity as Device).GetDevicePS();
  let isComputer: Bool = IsDefined(devicePS) && DaemonFilterUtils.IsComputer(devicePS);

  // CRITICAL FIX: Backdoor check must EXCLUDE Computers
  // Computers can be connected to backdoor network, but should NOT be treated as backdoor breach points
  let isBackdoor: Bool = !isAccessPoint && !isComputer && IsDefined(this.m_entity as Device) && (this.m_entity as Device).GetDevicePS().IsConnectedToBackdoorDevice();

  // Add unlock programs for un-breached device types
  // Netrunners have full access (all systems)
  // Computers: Full network access (same as Access Points via Remote Breach)
  // Turrets: Access Points, Computers, or Netrunners
  if !device.m_betterNetrunningBreachedTurrets && (isAccessPoint || isComputer || isNetrunner) {
    let turretAccessProgram: MinigameProgramData;
    turretAccessProgram.actionID = t"MinigameAction.UnlockTurretQuickhacks";
    turretAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, turretAccessProgram);
    }
  // Cameras: Access Points, Computers, Backdoors, or Netrunners
  if !device.m_betterNetrunningBreachedCameras && (isAccessPoint || isComputer || isBackdoor || isNetrunner) {
    let cameraAccessProgram: MinigameProgramData;
    cameraAccessProgram.actionID = t"MinigameAction.UnlockCameraQuickhacks";
    cameraAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, cameraAccessProgram);
    }
  // NPCs: Access Points, Computers, Unconscious NPCs, or Netrunners
  if !device.m_betterNetrunningBreachedNPCs && (isAccessPoint || isComputer || isUnconsciousNPC || isNetrunner) {
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
    // Cast DeviceComponentPS to ScriptableDeviceComponentPS for DaemonFilterUtils
    let slavePS: ref<ScriptableDeviceComponentPS> = slaves[i] as ScriptableDeviceComponentPS;
    if IsDefined(slavePS) {
      if !data.surveillanceCamera && DaemonFilterUtils.IsCamera(slavePS) {
        data.surveillanceCamera = true;
      } else if !data.securityTurret && DaemonFilterUtils.IsTurret(slavePS) {
        data.securityTurret = true;
      }
    }
    if !data.puppet && IsDefined(slaves[i] as PuppetDeviceLinkPS) {
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

  let requireAll: Bool = BetterNetrunningSettings.ProgressionRequireAll();
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

  let requireAll: Bool = BetterNetrunningSettings.ProgressionRequireAll();
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