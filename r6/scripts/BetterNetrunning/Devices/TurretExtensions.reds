// ============================================================================
// BetterNetrunning - Turret Extensions
// ============================================================================
//
// PURPOSE:
// Extends SecurityTurretControllerPS with additional quickhack actions
// for enhanced turret control functionality.
//
// FUNCTIONALITY:
// - Adds turret attitude override quickhacks (friendly/hostile control)
// - Adds take control quickhack (manual turret control)
// - Adds tag kill mode quickhack (targeted elimination)
// - Optionally adds toggle quickhacks (on/off control)
// - Respects user settings for blocking disable quickhacks
//
// CRITICAL FIX (Scenario 5):
// wrappedMethod() is called OUTSIDE the if-condition to ensure
// FinalizeGetQuickHackActions() executes for ALL device states (NOMINAL,
// DAMAGED, DESTROYED, UNPOWERED). This preserves vanilla behavior where
// RPG checks, equipment requirements, and illegality marking are always applied.
//
// MOD COMPATIBILITY:
// Uses @wrapMethod for better compatibility with other mods that hook turret quickhacks
// ============================================================================

module BetterNetrunning.Devices

import BetterNetrunningConfig.*

// ============================================================================
// TURRET QUICKHACK EXTENSIONS
// ============================================================================

/// Extends turret quickhack actions with custom behaviors
/// @wrapMethod to preserve vanilla logic and allow other mod hooks
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

// ============================================================================
// HELPER METHODS
// ============================================================================

/// Adds turret attitude override action
/// Sets turret to friendly/hostile mode based on quickhack variant
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

/// Adds turret take control action
/// Allows player to manually control turret (like vehicle control)
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

/// Adds turret tag kill mode action
/// Enables targeted elimination mode where turret focuses on tagged enemies
@addMethod(SecurityTurretControllerPS)
private final func AddTurretTagKillModeAction(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let action: ref<ScriptableDeviceAction> = this.ActionSetDeviceTagKillMode();
  action.SetObjectActionID(t"DeviceAction.SetDeviceTagKillMode");
  action.SetInactiveWithReason(!this.IsInTagKillMode(), "LocKey#7004");
  ArrayPush(Deref(actions), action);
}

/// Adds turret toggle action (on/off control)
/// Allows player to disable/enable turret remotely
@addMethod(SecurityTurretControllerPS)
private final func AddTurretToggleAction(actions: script_ref<array<ref<DeviceAction>>>, actionID: TweakDBID) -> Void {
  let action: ref<ScriptableDeviceAction> = this.ActionQuickHackToggleON();
  action.SetObjectActionID(actionID);
  action.SetExecutor(GetPlayer(this.GetGameInstance()));
  action.SetDurationValue(action.GetDurationTime());
  action.SetInactiveWithReason(this.IsOFFTimed(), "LocKey#7005");
  ArrayPush(Deref(actions), action);
}
