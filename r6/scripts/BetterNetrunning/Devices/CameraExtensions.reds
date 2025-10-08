// ============================================================================
// BetterNetrunning - Camera Extensions
// ============================================================================
//
// PURPOSE:
// Extends SurveillanceCameraControllerPS with additional quickhack actions
// for enhanced camera control functionality.
//
// FUNCTIONALITY:
// - Adds take control quickhack (manual camera control)
// - Adds camera attitude override quickhacks (friendly/hostile control)
// - Optionally adds toggle quickhack (on/off control)
// - Respects user settings for blocking disable quickhacks
//
// CRITICAL FIX (Scenario 5):
// wrappedMethod() is called OUTSIDE the if-condition to ensure
// FinalizeGetQuickHackActions() executes for ALL device states (NOMINAL,
// DAMAGED, DESTROYED, UNPOWERED). This preserves vanilla behavior where
// RPG checks, equipment requirements, and illegality marking are always applied.
//
// MOD COMPATIBILITY:
// Uses @wrapMethod for better compatibility with other mods that hook camera quickhacks
// ============================================================================

module BetterNetrunning.Devices

import BetterNetrunningConfig.*

// ============================================================================
// CAMERA QUICKHACK EXTENSIONS
// ============================================================================

/// Extends camera quickhack actions with custom behaviors
/// @wrapMethod to preserve vanilla logic and allow other mod hooks
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

// ============================================================================
// HELPER METHODS
// ============================================================================

/// Adds camera take control action
/// Allows player to manually control camera (first-person camera view)
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

/// Adds camera attitude override action
/// Sets camera to friendly/hostile mode (ignore player or detect player)
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

/// Adds camera toggle action (on/off control)
/// Allows player to disable/enable camera remotely
@addMethod(SurveillanceCameraControllerPS)
private final func AddCameraToggleAction(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let action: ref<ScriptableDeviceAction> = this.ActionQuickHackToggleON();
  action.SetObjectActionID(t"DeviceAction.ToggleStateClassHack");
  action.SetExecutor(GetPlayer(this.GetGameInstance()));
  action.SetDurationValue(action.GetDurationTime());
  ArrayPush(Deref(actions), action);
}
