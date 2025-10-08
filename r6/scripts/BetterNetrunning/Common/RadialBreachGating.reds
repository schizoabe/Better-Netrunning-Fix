// ============================================================================
// BetterNetrunning - RadialBreach MOD Gating Layer
// ============================================================================
//
// PURPOSE:
// Provides conditional gating for RadialBreach MOD integration
// (https://www.nexusmods.com/cyberpunk2077/mods/14816)
// Enables physical proximity-based breach filtering for network devices.
//
// FUNCTIONALITY:
// - Conditionally compiled based on RadialBreach MOD presence
// - Syncs breach range configuration with RadialBreach settings
// - Implements physical distance filtering for network devices
// - Records network centroid position for radial unlock system
//
// ARCHITECTURE:
// - @if(ModuleExists("RadialBreach")): Full RadialBreach gating enabled
// - @if(!ModuleExists("RadialBreach")): Fallback stubs (no physical filtering)
//
// MOD COMPATIBILITY:
// - Works with or without RadialBreach MOD installed
// - Automatically syncs breach range with RadialBreach Native Settings
// - Delegates to vanilla behavior when MOD not present
//
// NAMING CONVENTION:
// - Follows [MOD]Gating.reds pattern (e.g., DNRGating.reds, RadialBreachGating.reds)
// - "Gating" = Conditional filtering layer for external MOD integration
// ============================================================================

module BetterNetrunning.Common

import BetterNetrunning.Common.*

// Conditional import: Only load RadialBreach settings when MOD exists
@if(ModuleExists("RadialBreach"))
import RadialBreach.Config.*

// ============================================================================
// BREACH RANGE CONFIGURATION
// ============================================================================

/// Gets the breach range from RadialBreach settings (or default 50m)
/// Automatically syncs with RadialBreach user configuration via Native Settings UI
@if(ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
public final func GetRadialBreachRange() -> Float {
  let settings: ref<RadialBreachSettings> = new RadialBreachSettings();
  return settings.breachRange;
}

/// Fallback when RadialBreach is not installed - use default 50m
@if(!ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
public final func GetRadialBreachRange() -> Float {
  return 50.0;
}

// ============================================================================
// BREACH POSITION TRACKING
// ============================================================================

/// Gets the breach position (AccessPoint position or player position as fallback)
/// Used for network centroid calculation and radial unlock system
@addMethod(AccessPointControllerPS)
public final func GetBreachPosition() -> Vector4 {
  // Try to get AccessPoint entity position
  let apEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
  if IsDefined(apEntity) {
    return apEntity.GetWorldPosition();
  }

  // Fallback: player position
  let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
  if IsDefined(player) {
    return player.GetWorldPosition();
  }

  // Error signal (prevents filtering all devices if position unavailable)
  BNLog("[GetBreachPosition] ERROR: Could not get breach position, returning error signal");
  return Vector4(-999999.0, -999999.0, -999999.0, 1.0);
}

// ============================================================================
// PHYSICAL DISTANCE FILTERING
// ============================================================================

/// Checks if a device is within breach radius (physical proximity-based filtering)
/// Only used when RadialBreach MOD is installed
@addMethod(AccessPointControllerPS)
public final func IsDeviceWithinBreachRadius(device: ref<DeviceComponentPS>, breachPosition: Vector4, maxDistance: Float) -> Bool {
  let deviceEntity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;
  if !IsDefined(deviceEntity) {
    return true; // Fallback: allow unlock if entity not found
  }

  let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
  let distance: Float = Vector4.Distance(breachPosition, devicePosition);

  return distance <= maxDistance;
}

// ============================================================================
// DEVICE UNLOCK APPLICATION (CONDITIONAL COMPILATION)
// ============================================================================

/// Applies device-type-specific unlock to all connected devices
/// RadialBreach version: Filters devices by physical proximity
@if(ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
public final func ApplyBreachUnlockToDevices(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
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
      // Apply device-type-specific unlock
      this.ApplyDeviceTypeUnlock(device, unlockFlags);

      // Process minigame network actions
      this.ProcessMinigameNetworkActions(device);

      // Queue SetBreachedSubnet event
      let evt: ref<SetBreachedSubnet> = new SetBreachedSubnet();
      evt.breachedBasic = setBreachedSubnetEvent.breachedBasic;
      evt.breachedNPCs = setBreachedSubnetEvent.breachedNPCs;
      evt.breachedCameras = setBreachedSubnetEvent.breachedCameras;
      evt.breachedTurrets = setBreachedSubnetEvent.breachedTurrets;
      this.GetPersistencySystem().QueuePSEvent(device.GetID(), device.GetClassName(), evt);
    }

    i += 1;
  }
}

/// Applies device-type-specific unlock to all connected devices
/// Fallback version: No physical filtering (unlocks all devices in network)
@if(!ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
public final func ApplyBreachUnlockToDevices(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  let setBreachedSubnetEvent: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  setBreachedSubnetEvent.breachedBasic = unlockFlags.unlockBasic;
  setBreachedSubnetEvent.breachedNPCs = unlockFlags.unlockNPCs;
  setBreachedSubnetEvent.breachedCameras = unlockFlags.unlockCameras;
  setBreachedSubnetEvent.breachedTurrets = unlockFlags.unlockTurrets;

  // No RadialBreach filtering - unlock all devices in network
  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];

    // Apply device-type-specific unlock (no distance check)
    this.ApplyDeviceTypeUnlock(device, unlockFlags);

    // Process minigame network actions
    this.ProcessMinigameNetworkActions(device);

    // Queue SetBreachedSubnet event
    let evt: ref<SetBreachedSubnet> = new SetBreachedSubnet();
    evt.breachedBasic = setBreachedSubnetEvent.breachedBasic;
    evt.breachedNPCs = setBreachedSubnetEvent.breachedNPCs;
    evt.breachedCameras = setBreachedSubnetEvent.breachedCameras;
    evt.breachedTurrets = setBreachedSubnetEvent.breachedTurrets;
    this.GetPersistencySystem().QueuePSEvent(device.GetID(), device.GetClassName(), evt);

    i += 1;
  }
}
