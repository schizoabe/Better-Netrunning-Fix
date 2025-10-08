module BetterNetrunning.Devices

import BetterNetrunningConfig.*
import BetterNetrunning.Common.*
import BetterNetrunning.Progression.*

/*
 * ============================================================================
 * DEVICE QUICKHACKS MODULE
 * ============================================================================
 *
 * PURPOSE:
 * Manages device quickhack availability based on breach status and player
 * progression requirements.
 *
 * FUNCTIONALITY:
 * - Progressive unlock restrictions (Cyberdeck tier, Intelligence stat)
 * - Standalone device support via radial breach system (50m radius)
 * - Network isolation detection -> auto-unlock for unsecured networks
 * - Device-type-specific permissions (Camera, Turret, Basic)
 * - Special always-allowed quickhacks (Ping, Distraction)
 *
 * ARCHITECTURE:
 * - SetActionsInactiveUnbreached(): Main entry point for progressive unlock
 * - FinalizeGetQuickHackActions(): Finalizes actions before presenting to player
 * - GetRemoteActions(): Provides device quickhack actions based on breach status
 * - CanRevealRemoteActionsWheel(): Controls quickhack menu visibility
 *
 * REFACTORED:
 * SetActionsInactiveUnbreached reduced from 100 lines with 6-level nesting
 * to 25 lines with 2-level nesting using Extract Method pattern.
 *
 * ============================================================================
 */

// ==================== Progressive Unlock System ====================

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

// ==================== Quickhack Finalization ====================

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

// ==================== Remote Actions ====================

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
