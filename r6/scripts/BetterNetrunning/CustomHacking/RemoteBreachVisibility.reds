// ============================================================================
// RemoteBreach Visibility Management Module
// ============================================================================
// This module manages RemoteBreach action visibility based on device unlock state.
//
// RESPONSIBILITIES:
// - RemoteBreach visibility control (show/hide based on device state)
// - RemoteBreach action injection (Computer, Vehicle, Device)
// - Device unlock state detection (daemon flags + RemoteBreach daemon completion)
// - RemoteBreach action removal from unlocked devices
//
// VISIBILITY RULES:
// RemoteBreach is hidden when ANY of the following conditions are met:
//   1. Device unlocked via daemon (UnlockQuickhacks/Camera/Turret)
//   2. RemoteBreach completed ANY daemon (Basic/NPC/Camera/Turret)
// Both conditions use OR logic.
//
// ARCHITECTURE:
// - AccessPointBreach: Dynamic filtering via vanilla hooks (betterNetrunning.reds)
// - RemoteBreach: Static definition via CustomHackingSystem (CustomHacking/*.reds)
// - RemoteBreachVisibility: Visibility management bridge (this file)
//
// DESIGN PATTERN:
// - Early Return: Prevent RemoteBreach addition if device already unlocked
// - Defense-in-Depth: Fallback removal if RemoteBreach slips through
// - Separation of Concerns: Focused on visibility logic only
//
// ============================================================================

module BetterNetrunning.CustomHacking
import BetterNetrunning.Common.*
import BetterNetrunning.*
import BetterNetrunningConfig.*

/*
 * Checks if device is already unlocked via daemon or CustomHackingSystem breach
 * Returns true if device is unlocked via daemon or CustomHackingSystem breach
 *
 * NEW REQUIREMENT: RemoteBreach should be hidden when:
 *   1. Device is unlocked via daemon (UnlockQuickhacks/Camera/Turret), OR
 *   2. Device has completed ANY RemoteBreach daemon (Basic/NPC/Camera/Turret)
 * Both conditions are checked with OR logic.
 *
 * PERFORMANCE: This prevents unnecessary RemoteBreach action creation and UI flash
 * APPLIES TO: All devices including Vehicles, Cameras, Turrets, and generic devices
 */
@addMethod(ScriptableDeviceComponentPS)
public final func IsDeviceAlreadyUnlocked() -> Bool {
  // Check 1: Vehicle-specific unlock (via UnlockQuickhacks daemon)
  if IsDefined(this as VehicleComponentPS) {
    if this.m_betterNetrunningBreachedBasic {
      BNLog("[IsDeviceAlreadyUnlocked] Vehicle already unlocked");
    }
    return this.m_betterNetrunningBreachedBasic;
  }

  // Check 2: Camera-specific unlock (via UnlockCameraQuickhacks daemon)
  if DaemonFilterUtils.IsCamera(this) {
    if this.m_betterNetrunningBreachedCameras {
      BNLog("[IsDeviceAlreadyUnlocked] Camera already unlocked");
    }
    return this.m_betterNetrunningBreachedCameras;
  }

  // Check 3: Turret-specific unlock (via UnlockTurretQuickhacks daemon)
  if DaemonFilterUtils.IsTurret(this) {
    if this.m_betterNetrunningBreachedTurrets {
      BNLog("[IsDeviceAlreadyUnlocked] Turret already unlocked");
    }
    return this.m_betterNetrunningBreachedTurrets;
  }

  // Check 4a: Basic device unlock (via UnlockQuickhacks daemon)
  if this.m_betterNetrunningBreachedBasic {
    BNLog("[IsDeviceAlreadyUnlocked] Device already unlocked (Basic daemon)");
    return true;
  }

  // Check 4b: CustomHackingSystem RemoteBreach state
  let deviceEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
  if IsDefined(deviceEntity) {
    let stateSystem: ref<DeviceRemoteBreachStateSystem> =
      GameInstance.GetScriptableSystemsContainer(this.GetGameInstance())
        .Get(n"BetterNetrunning.CustomHacking.DeviceRemoteBreachStateSystem") as DeviceRemoteBreachStateSystem;

    if IsDefined(stateSystem) {
      return stateSystem.IsDeviceBreached(deviceEntity.GetEntityID());
    }
  }

  return false;
}

/*
 * Tries to add Custom RemoteBreach action (Computer, Vehicle, or Device)
 * Only compiled when HackingExtensions module exists
 */
@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
public final func TryAddCustomRemoteBreach(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // EARLY EXIT: Device already unlocked, don't add RemoteBreach
  // This prevents UI flash of RemoteBreach before it gets removed
  if this.IsDeviceAlreadyUnlocked() {
    return;
  }

  // Check if Custom RemoteBreach already exists
  let hasCustomRemoteBreach: Bool = false;
  let i: Int32 = 0;
  while i < ArraySize(Deref(outActions)) {
    let action: ref<DeviceAction> = Deref(outActions)[i];
    if IsDefined(action) && IsCustomRemoteBreachAction(action.GetClassName()) {
      hasCustomRemoteBreach = true;
      break;
    }
    i += 1;
  }

  // Only add if Custom RemoteBreach doesn't exist
  if !hasCustomRemoteBreach {
    // Determine which type of Custom RemoteBreach to add
    let isComputer: Bool = DaemonFilterUtils.IsComputer(this);
    let isVehicle: Bool = IsDefined(this as VehicleComponentPS);

    if isComputer {
      // Check if Computer RemoteBreach is enabled
      if !BetterNetrunningSettings.RemoteBreachEnabledComputer() {
        return;
      }
      let computerPS: ref<ComputerControllerPS> = this as ComputerControllerPS;
      let breachAction: ref<RemoteBreachAction> = computerPS.ActionCustomRemoteBreach();
      ArrayPush(Deref(outActions), breachAction);
    } else if isVehicle {
      // Check if Vehicle RemoteBreach is enabled
      if !BetterNetrunningSettings.RemoteBreachEnabledVehicle() {
        return;
      }
      let vehiclePS: ref<VehicleComponentPS> = this as VehicleComponentPS;
      let breachAction: ref<VehicleRemoteBreachAction> = vehiclePS.ActionCustomVehicleRemoteBreach();
      ArrayPush(Deref(outActions), breachAction);
    } else {
      // Check if Device RemoteBreach is enabled
      if !BetterNetrunningSettings.RemoteBreachEnabledDevice() {
        return;
      }
      let breachAction: ref<DeviceRemoteBreachAction> = this.ActionCustomDeviceRemoteBreach();
      ArrayPush(Deref(outActions), breachAction);
    }
  }
}

/*
 * Adds missing Custom RemoteBreach to devices that override GetQuickHackActions()
 * Only compiled when HackingExtensions module exists
 * CRITICAL: Some devices (NetrunnerChair, Jukebox, DisposalDevice) override GetQuickHackActions()
 * without calling wrappedMethod(), so Custom RemoteBreach must be injected here
 */
@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
public final func TryAddMissingCustomRemoteBreach(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // EARLY EXIT: Device already unlocked, don't add RemoteBreach
  // This prevents RemoteBreach from appearing on devices unlocked via network breach
  if this.IsDeviceAlreadyUnlocked() {
    return;
  }

  // Skip Computer and Vehicle (they have specialized implementations)
  let isComputer: Bool = DaemonFilterUtils.IsComputer(this);
  let isVehicle: Bool = IsDefined(this as VehicleComponentPS);

  if !isComputer && !isVehicle {
    // Check if Device RemoteBreach is enabled
    if !BetterNetrunningSettings.RemoteBreachEnabledDevice() {
      return;
    }
    let breachAction: ref<DeviceRemoteBreachAction> = this.ActionCustomDeviceRemoteBreach();
    ArrayPush(Deref(outActions), breachAction);
  }
}

/*
 * Removes Custom RemoteBreach from unlocked devices
 *
 * DEFENSE-IN-DEPTH: This is a fallback safety mechanism
 * - Primary prevention: IsDeviceAlreadyUnlocked() check in TryAddCustomRemoteBreach()
 * - Secondary cleanup: This function removes any RemoteBreach that slipped through
 *
 * NEW REQUIREMENT: Once device is unlocked OR any RemoteBreach daemon succeeds, RemoteBreach should be hidden
 * APPLIES TO: All devices including Vehicles, Cameras, Turrets, and generic devices
 *
 * UNLOCK DETECTION (OR logic):
 * - Vehicles: m_betterNetrunningBreachedBasic flag (UnlockQuickhacks daemon)
 * - Basic devices (Computer, TV, etc.):
 *   1. DeviceRemoteBreachStateSystem.IsDeviceBreached() (CustomHackingSystem RemoteBreach - ANY daemon success)
 *   2. m_betterNetrunningBreachedBasic flag (UnlockQuickhacks daemon)
 * - Cameras: m_betterNetrunningBreachedCameras flag (UnlockCameraQuickhacks daemon)
 * - Turrets: m_betterNetrunningBreachedTurrets flag (UnlockTurretQuickhacks daemon)
 */
@addMethod(ScriptableDeviceComponentPS)
public final func RemoveCustomRemoteBreachIfUnlocked(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Check if device is unlocked
  let isUnlocked: Bool = false;

  // Check 1: Vehicle-specific unlock (via UnlockQuickhacks daemon)
  if IsDefined(this as VehicleComponentPS) {
    isUnlocked = this.m_betterNetrunningBreachedBasic;
  }
  // Check 2: Camera-specific unlock (via UnlockCameraQuickhacks daemon)
  else if DaemonFilterUtils.IsCamera(this) {
    isUnlocked = this.m_betterNetrunningBreachedCameras;
  }
  // Check 3: Turret-specific unlock (via UnlockTurretQuickhacks daemon)
  else if DaemonFilterUtils.IsTurret(this) {
    isUnlocked = this.m_betterNetrunningBreachedTurrets;
  }
  // Check 4: Basic device unlock (via CustomHackingSystem RemoteBreach OR UnlockQuickhacks daemon)
  else {
    // Check 4a: UnlockQuickhacks daemon flag
    isUnlocked = this.m_betterNetrunningBreachedBasic;

    // Check 4b: CustomHackingSystem RemoteBreach
    if !isUnlocked {
      let deviceEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
      if IsDefined(deviceEntity) {
        let deviceID: EntityID = deviceEntity.GetEntityID();
        let stateSystem: ref<DeviceRemoteBreachStateSystem> =
          GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"BetterNetrunning.CustomHacking.DeviceRemoteBreachStateSystem") as DeviceRemoteBreachStateSystem;

        if IsDefined(stateSystem) {
          isUnlocked = stateSystem.IsDeviceBreached(deviceID);
        }
      }
    }
  }

  // Remove RemoteBreach if device is unlocked
  if isUnlocked {
    let i: Int32 = 0;
    while i < ArraySize(Deref(outActions)) {
      let action: ref<DeviceAction> = Deref(outActions)[i];
      if IsDefined(action) && IsCustomRemoteBreachAction(action.GetClassName()) {
        ArrayErase(Deref(outActions), i);
        break;
      }
      i += 1;
    }
  }
}

/*
 * Moves Vehicle RemoteBreach to the bottom of action list
 * CONDITION: Only applies if Vehicle is NOT yet unlocked
 * BEHAVIOR: If unlocked, RemoteBreach is removed by RemoveCustomRemoteBreachIfUnlocked()
 * PURPOSE: Prevent RemoteBreach from jumping to top during transition states
 */
@addMethod(ScriptableDeviceComponentPS)
public final func MoveVehicleRemoteBreachToBottom(outActions: script_ref<array<ref<DeviceAction>>>) -> Void {
  // Only applies to Vehicles
  if !IsDefined(this as VehicleComponentPS) {
    return;
  }

  // Find Vehicle RemoteBreach action
  let remoteBreachIndex: Int32 = -1;
  let i: Int32 = 0;
  while i < ArraySize(Deref(outActions)) {
    let action: ref<DeviceAction> = Deref(outActions)[i];
    if IsDefined(action) && Equals(action.GetClassName(), n"BetterNetrunning.CustomHacking.VehicleRemoteBreachAction") {
      remoteBreachIndex = i;
      break;
    }
    i += 1;
  }

  // If found and not already at bottom, move it
  if remoteBreachIndex >= 0 && remoteBreachIndex < ArraySize(Deref(outActions)) - 1 {
    let remoteBreachAction: ref<DeviceAction> = Deref(outActions)[remoteBreachIndex];
    ArrayErase(Deref(outActions), remoteBreachIndex);
    ArrayPush(Deref(outActions), remoteBreachAction);
  }
}
