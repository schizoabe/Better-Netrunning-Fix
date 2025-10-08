module BetterNetrunning.Minigame

import BetterNetrunningConfig.*
import BetterNetrunning.Common.*

/*
 * ============================================================================
 * PROGRAM INJECTION MODULE
 * ============================================================================
 *
 * PURPOSE:
 * Injects progressive unlock programs into the breach minigame based on
 * device state and breach point type.
 *
 * FUNCTIONALITY:
 * - Adds unlock programs for un-breached device types
 * - Determines appropriate programs based on breach point (Access Point, Computer, Backdoor, NPC)
 * - Supports remote breach integration (CustomHackingSystem)
 * - Respects progressive unlock state (m_betterNetrunningBreached* flags)
 *
 * BREACH POINT TYPES:
 * - Access Points: Full network access (all unlock programs)
 * - Computers: Full network access (treated same as Access Points via Remote Breach)
 * - Backdoor Devices: Limited access (Root + Camera programs only)
 * - Netrunner NPCs: Full network access (all systems)
 * - Regular NPCs: Limited access (NPC programs only when unconscious)
 *
 * CRITICAL FIXES:
 * - Computers are checked BEFORE backdoor to avoid misclassification
 * - Computers are EXCLUDED from backdoor check (full network access)
 * - Remote breach integration ensures proper daemon availability
 *
 * MOD COMPATIBILITY:
 * This function is called from FilterPlayerPrograms() @wrapMethod,
 * ensuring compatibility with other mods that modify breach programs.
 *
 * ============================================================================
 */

/*
 * Injects progressive unlock programs into breach minigame
 * Programs appear only if their device type has not been breached yet
 *
 * @param programs - Reference to the array of programs to inject into
 */
@addMethod(MinigameGenerationRuleScalingPrograms)
public final func InjectBetterNetrunningPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {

  // Skip injection in Classic Mode (vanilla behavior)
  if BetterNetrunningSettings.EnableClassicMode() {
      return;
  }

  // ==================== Get Target Device State ====================

  let device: ref<SharedGameplayPS>;
  if IsDefined(this.m_entity as ScriptedPuppet) {
    // NPC breach: Get device link from puppet persistent state
    device = (this.m_entity as ScriptedPuppet).GetPS().GetDeviceLink();
    } else {
    // Device breach: Get device persistent state directly
    device = (this.m_entity as Device).GetDevicePS();
    }

  if !IsDefined(device) {
    BNLog("[InjectBetterNetrunningPrograms] ERROR: device (SharedGameplayPS) is null!");
    return;
  }

  // ==================== Determine Breach Point Type ====================

  // Check if breaching from an access point
  let isAccessPoint: Bool = IsDefined(this.m_entity as AccessPoint);

  // Check if breaching from an unconscious NPC
  let isUnconsciousNPC: Bool = IsDefined(this.m_entity as ScriptedPuppet);

  // Check if the NPC is a netrunner (full network access)
  let isNetrunner: Bool = isUnconsciousNPC && (this.m_entity as ScriptedPuppet).IsNetrunnerPuppet();

  // CRITICAL FIX: Remote breach support (CustomHackingSystem integration)
  // Remote breach should behave like Access Point breach (full network access)
  // PRIORITY: Check isComputer BEFORE isBackdoor to avoid misclassification
  let devicePS: ref<ScriptableDeviceComponentPS> = (this.m_entity as Device).GetDevicePS();
  let isComputer: Bool = IsDefined(devicePS) && DaemonFilterUtils.IsComputer(devicePS);

  // CRITICAL FIX: Backdoor check must EXCLUDE Computers
  // Computers can be connected to backdoor network, but should NOT be treated as backdoor breach points
  let isBackdoor: Bool = !isAccessPoint && !isComputer && IsDefined(this.m_entity as Device) && (this.m_entity as Device).GetDevicePS().IsConnectedToBackdoorDevice();

  // ==================== Inject Unlock Programs ====================

  // Add unlock programs for un-breached device types
  // Programs are inserted at the beginning of the array (highest priority)

  // TURRETS: Access Points, Computers, or Netrunners
  // Backdoor devices do NOT have turret access (security restriction)
  if !device.m_betterNetrunningBreachedTurrets && (isAccessPoint || isComputer || isNetrunner) {
    let turretAccessProgram: MinigameProgramData;
    turretAccessProgram.actionID = t"MinigameAction.UnlockTurretQuickhacks";
    turretAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, turretAccessProgram);
    }

  // CAMERAS: Access Points, Computers, Backdoors, or Netrunners
  // Backdoor devices HAVE camera access (surveillance network connection)
  if !device.m_betterNetrunningBreachedCameras && (isAccessPoint || isComputer || isBackdoor || isNetrunner) {
    let cameraAccessProgram: MinigameProgramData;
    cameraAccessProgram.actionID = t"MinigameAction.UnlockCameraQuickhacks";
    cameraAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, cameraAccessProgram);
    }

  // NPCs: Access Points, Computers, Unconscious NPCs, or Netrunners
  // Backdoor devices do NOT have NPC access (requires full network or direct neural link)
  if !device.m_betterNetrunningBreachedNPCs && (isAccessPoint || isComputer || isUnconsciousNPC || isNetrunner) {
    let npcAccessProgram: MinigameProgramData;
    npcAccessProgram.actionID = t"MinigameAction.UnlockNPCQuickhacks";
    npcAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, npcAccessProgram);
    }

  // BASIC: All breach points (always available)
  // This is the root access program - available from any breach point
  if !device.m_betterNetrunningBreachedBasic {
    let basicAccessProgram: MinigameProgramData;
    basicAccessProgram.actionID = t"MinigameAction.UnlockQuickhacks";
    basicAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, basicAccessProgram);
    }

}
