module BetterNetrunning.Minigame

import BetterNetrunningConfig.*
import BetterNetrunning.Common.*

/*
 * ============================================================================
 * PROGRAM FILTERING MODULE
 * ============================================================================
 *
 * PURPOSE:
 * Determines which breach programs (daemons) should be available in the
 * breach minigame based on context, settings, and device state.
 *
 * FUNCTIONALITY:
 * - Network connectivity filtering (remove unlock programs if not connected)
 * - Device type filtering (access points vs backdoor devices)
 * - Access point program restrictions (based on user settings)
 * - Non-netrunner NPC restrictions (limit programs for regular NPCs)
 * - Already-breached program removal (prevent re-breach of same type)
 * - Device type availability (remove programs for unavailable device types)
 * - Datamine V1/V2 removal (based on user settings)
 *
 * MOD COMPATIBILITY:
 * These functions are called from FilterPlayerPrograms() @wrapMethod,
 * ensuring compatibility with other mods that modify breach programs.
 *
 * ============================================================================
 */

// ==================== Network & Device Type Filtering ====================

/*
 * Returns true if unlock programs should be removed (when target is not connected to network)
 *
 * @param actionID - The program's TweakDB ID
 * @param connectedToNetwork - Whether the target is connected to a network
 * @return True if the program should be removed
 */
public func ShouldRemoveNetworkPrograms(actionID: TweakDBID, connectedToNetwork: Bool) -> Bool {
  if connectedToNetwork {
    return false;
  }
  return IsUnlockQuickhackAction(actionID);
}

/*
 * Returns true if device-specific programs should be removed (for non-access-point devices)
 *
 * CRITICAL FIX: Exclude Computers - they should have full network access (same as Access Points)
 *
 * @param actionID - The program's TweakDB ID
 * @param entity - The target entity (device/NPC)
 * @return True if the program should be removed
 */
public func ShouldRemoveDeviceBackdoorPrograms(actionID: TweakDBID, entity: wref<GameObject>) -> Bool {
  // Only applies to non-access-point, non-computer devices (Backdoor devices like Camera/Door)
  if !DaemonFilterUtils.IsRegularDevice(entity) {
    return false;
  }
  return actionID == t"MinigameAction.NetworkDataMineLootAllMaster"
      || actionID == t"MinigameAction.UnlockNPCQuickhacks"
      || actionID == t"MinigameAction.UnlockTurretQuickhacks";
}

// ==================== Access Point & Remote Breach Filtering ====================

/*
 * Returns true if access point programs should be restricted (based on user settings)
 *
 * @param actionID - The program's TweakDB ID
 * @param miniGameActionRecord - The program's record data
 * @param isRemoteBreach - Whether this is a remote breach (CustomHackingSystem)
 * @return True if the program should be removed
 */
public func ShouldRemoveAccessPointPrograms(actionID: TweakDBID, miniGameActionRecord: wref<MinigameAction_Record>, isRemoteBreach: Bool) -> Bool {
  // Allow all programs if configured or if remote breach
  if BetterNetrunningSettings.AllowAllDaemonsOnAccessPoints() || isRemoteBreach {
    return false;
  }
  // Remove non-access-point programs and non-unlock programs
  return NotEquals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.AccessPoint)
      && !IsUnlockQuickhackAction(actionID);
}

// ==================== Non-Netrunner NPC Filtering ====================

/*
 * Returns true if programs should be restricted for non-netrunner NPCs
 *
 * @param actionID - The program's TweakDB ID
 * @param miniGameActionRecord - The program's record data
 * @param isRemoteBreach - Whether this is a remote breach
 * @param entity - The target entity
 * @return True if the program should be removed
 */
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

/*
 * Returns true if target is a remote breach on a non-netrunner NPC
 *
 * @param isRemoteBreach - Whether this is a remote breach
 * @param entity - The target entity
 * @return True if remote breach on non-netrunner NPC
 */
public func IsRemoteNonNetrunner(isRemoteBreach: Bool, entity: wref<GameObject>) -> Bool {
  if !isRemoteBreach {
    return false;
  }
  let puppet: wref<ScriptedPuppet> = entity as ScriptedPuppet;
  return IsDefined(puppet) && !puppet.IsNetrunnerPuppet();
}

// ==================== Already-Breached Program Filtering ====================

/*
 * Returns true if already breached programs should be removed
 * CRITICAL: This removes daemons that were added by vanilla logic but already completed
 *
 * @param actionID - The program's TweakDB ID
 * @param entity - The target entity (device/NPC)
 * @return True if the program should be removed
 */
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

// ==================== Device Type Availability Filtering ====================

/*
 * Returns true if programs should be removed based on device type availability
 *
 * In RadialUnlock mode, delegates filtering to RadialBreach's physical proximity-based system.
 * If RadialBreach is not installed, disables network-based filtering to reduce UI noise.
 *
 * In Classic mode, uses traditional network connectivity-based filtering.
 *
 * @param actionID - The program's TweakDB ID
 * @param miniGameActionRecord - The program's record data
 * @param data - Connected device types data
 * @return True if the program should be removed
 */
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

// ==================== Helper Functions ====================

/*
 * Returns true if action is any type of unlock quickhack program
 *
 * @param actionID - The program's TweakDB ID
 * @return True if the action is an unlock quickhack program
 */
private func IsUnlockQuickhackAction(actionID: TweakDBID) -> Bool {
  return actionID == t"MinigameAction.UnlockQuickhacks"
      || actionID == t"MinigameAction.UnlockNPCQuickhacks"
      || actionID == t"MinigameAction.UnlockCameraQuickhacks"
      || actionID == t"MinigameAction.UnlockTurretQuickhacks";
}
