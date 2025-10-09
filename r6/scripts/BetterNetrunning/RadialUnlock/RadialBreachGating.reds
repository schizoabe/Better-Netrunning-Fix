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
// - Supports both AccessPoint breach and RemoteBreach (Phase 4)
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
//
// PHASE 4 ADDITIONS (2025-10-08):
// - RemoteBreach integration via PlayerPuppet methods
// - ApplyRemoteBreachNetworkUnlock() for RemoteBreach network filtering
// - GetRadialBreachRangeForRemote() for setting retrieval
// - IsDeviceWithinRemoteBreachRadius() for distance checks
// ============================================================================

module BetterNetrunning.RadialUnlock

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
/// Refactored: Reduced nesting from 4 levels to 2 levels
@if(ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
public final func ApplyBreachUnlockToDevices(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  // RadialBreach Integration - Physical Distance Filtering
  let breachPosition: Vector4 = this.GetBreachPosition();
  let maxDistance: Float = this.GetRadialBreachRange();
  let shouldUseRadialFiltering: Bool = breachPosition.X >= -999000.0;

  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];
    
    // Physical distance check (RadialBreach integration)
    let withinRadius: Bool = !shouldUseRadialFiltering || 
                             this.IsDeviceWithinBreachRadius(device, breachPosition, maxDistance);
    
    if withinRadius {
      // Process device unlock
      this.ProcessSingleDeviceUnlock(device, unlockFlags);
    }
    i += 1;
  }
}

/// Applies device-type-specific unlock to all connected devices
/// Fallback version: No physical filtering (unlocks all devices in network)
/// Refactored: Reduced nesting from 3 levels to 2 levels
@if(!ModuleExists("RadialBreach"))
@addMethod(AccessPointControllerPS)
public final func ApplyBreachUnlockToDevices(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  // No RadialBreach filtering - unlock all devices in network
  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];
    this.ProcessSingleDeviceUnlock(device, unlockFlags);
    i += 1;
  }
}

/// Helper: Process unlock for a single device (shared by both versions)
@addMethod(AccessPointControllerPS)
private final func ProcessSingleDeviceUnlock(device: ref<DeviceComponentPS>, unlockFlags: BreachUnlockFlags) -> Void {
  // Apply device-type-specific unlock
  this.ApplyDeviceTypeUnlock(device, unlockFlags);

  // Process minigame network actions
  this.ProcessMinigameNetworkActions(device);

  // Queue SetBreachedSubnet event
  let evt: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  evt.breachedBasic = unlockFlags.unlockBasic;
  evt.breachedNPCs = unlockFlags.unlockNPCs;
  evt.breachedCameras = unlockFlags.unlockCameras;
  evt.breachedTurrets = unlockFlags.unlockTurrets;
  this.GetPersistencySystem().QueuePSEvent(device.GetID(), device.GetClassName(), evt);
}

// ============================================================================
// REMOTEBREACH INTEGRATION (PHASE 4)
// ============================================================================

/// Gets RadialBreach range for RemoteBreach filtering (PlayerPuppet version)
/// Syncs with RadialBreach user configuration
@if(ModuleExists("RadialBreach"))
@addMethod(PlayerPuppet)
public final func GetRadialBreachRangeForRemote() -> Float {
  let settings: ref<RadialBreachSettings> = new RadialBreachSettings();
  return settings.breachRange;
}

/// Fallback when RadialBreach is not installed
@if(!ModuleExists("RadialBreach"))
@addMethod(PlayerPuppet)
public final func GetRadialBreachRangeForRemote() -> Float {
  return 50.0; // Default (not used in fallback version)
}

/// Checks if device is within RemoteBreach radius (physical distance check)
/// Used by RemoteBreach network unlock logic
@addMethod(PlayerPuppet)
public final func IsDeviceWithinRemoteBreachRadius(
  device: ref<DeviceComponentPS>,
  breachPosition: Vector4,
  maxDistance: Float
) -> Bool {
  let deviceEntity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;

  if !IsDefined(deviceEntity) {
    // Fallback: allow unlock if entity not found
    return true;
  }

  let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
  let distance: Float = Vector4.Distance(breachPosition, devicePosition);

  return distance <= maxDistance;
}

// ============================================================================
// SHARED HELPER METHODS (PHASE 4 REFACTORING)
// ============================================================================

/// Applies unlock to a single RemoteBreach network device
/// Shared by both RadialBreach and Fallback versions
@addMethod(PlayerPuppet)
private final func ApplyRemoteBreachDeviceUnlockInternal(
  device: ref<DeviceComponentPS>,
  unlockFlags: BreachUnlockFlags
) -> Bool {
  let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;
  if !IsDefined(sharedPS) {
    return false;
  }

  let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

  // Validate device type against unlock flags (daemon-based filtering)
  if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
    BNLog("[RemoteBreach] Skipped device (not unlocked by daemon flags): " +
          EnumValueToString("DeviceType", Cast<Int64>(EnumInt(deviceType))));
    return false;
  }

  // Apply unlock
  let dummyAPPS: ref<AccessPointControllerPS> = new AccessPointControllerPS();
  dummyAPPS.QueuePSEvent(device, dummyAPPS.ActionSetExposeQuickHacks());

  // Set breach flag (device type-specific)
  DeviceTypeUtils.SetBreached(deviceType, sharedPS, true);

  // Set breached subnet event (propagate unlock flags to device)
  let setBreachedSubnetEvent: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  setBreachedSubnetEvent.breachedBasic = unlockFlags.unlockBasic;
  setBreachedSubnetEvent.breachedNPCs = unlockFlags.unlockNPCs;
  setBreachedSubnetEvent.breachedCameras = unlockFlags.unlockCameras;
  setBreachedSubnetEvent.breachedTurrets = unlockFlags.unlockTurrets;
  GameInstance.GetPersistencySystem(this.GetGame()).QueuePSEvent(device.GetID(), device.GetClassName(), setBreachedSubnetEvent);

  BNLog("[RemoteBreach] Unlocked network device: " +
        EnumValueToString("DeviceType", Cast<Int64>(EnumInt(deviceType))));
  return true;
}

/// Applies RemoteBreach network unlock (RadialBreach MOD version - Phase 4)
/// Uses daemon-based filtering + physical distance filtering
@if(ModuleExists("RadialBreach"))
@addMethod(PlayerPuppet)
public final func ApplyRemoteBreachNetworkUnlock(
  targetDevice: ref<ScriptableDeviceComponentPS>,
  networkDevices: array<ref<DeviceComponentPS>>,
  unlockFlags: BreachUnlockFlags
) -> Void {
  let unlockedCount: Int32 = 0;
  let skippedCount: Int32 = 0;
  let filteredCount: Int32 = 0;

  // Get breach position (target device position)
  let targetEntity: wref<GameObject> = targetDevice.GetOwnerEntityWeak() as GameObject;
  if !IsDefined(targetEntity) {
    BNLog("[RemoteBreach] ERROR: Target entity not found for RadialBreach filtering");
    return;
  }

  let breachPosition: Vector4 = targetEntity.GetWorldPosition();
  let maxDistance: Float = this.GetRadialBreachRangeForRemote();
  let shouldUseRadialFiltering: Bool = breachPosition.X >= -999000.0;

  BNLog("[RemoteBreach] RadialBreach filtering enabled - maxDistance: " + ToString(maxDistance) + "m");

  let i: Int32 = 0;
  while i < ArraySize(networkDevices) {
    let device: ref<DeviceComponentPS> = networkDevices[i];

    if IsDefined(device) {
      // Physical distance check (RadialBreach integration - Phase 4)
      let withinRadius: Bool = !shouldUseRadialFiltering ||
                               this.IsDeviceWithinRemoteBreachRadius(device, breachPosition, maxDistance);

      if withinRadius {
        // Apply unlock using shared helper
        if this.ApplyRemoteBreachDeviceUnlockInternal(device, unlockFlags) {
          unlockedCount += 1;
        } else {
          skippedCount += 1;
        }
      } else {
        filteredCount += 1;
        BNLog("[RemoteBreach] Device filtered by RadialBreach (distance > " + ToString(maxDistance) + "m)");
      }
    }

    i += 1;
  }

  BNLog("[RemoteBreach] Network unlock complete - Unlocked: " + ToString(unlockedCount) +
        ", Skipped: " + ToString(skippedCount) +
        ", Filtered: " + ToString(filteredCount));
}

/// Applies RemoteBreach network unlock (Fallback version - no RadialBreach)
/// Uses daemon-based filtering only (no physical distance filtering)
@if(!ModuleExists("RadialBreach"))
@addMethod(PlayerPuppet)
public final func ApplyRemoteBreachNetworkUnlock(
  targetDevice: ref<ScriptableDeviceComponentPS>,
  networkDevices: array<ref<DeviceComponentPS>>,
  unlockFlags: BreachUnlockFlags
) -> Void {
  let unlockedCount: Int32 = 0;
  let skippedCount: Int32 = 0;

  let i: Int32 = 0;
  while i < ArraySize(networkDevices) {
    let device: ref<DeviceComponentPS> = networkDevices[i];

    if IsDefined(device) {
      // Apply unlock using shared helper (no distance check)
      if this.ApplyRemoteBreachDeviceUnlockInternal(device, unlockFlags) {
        unlockedCount += 1;
      } else {
        skippedCount += 1;
      }
    }

    i += 1;
  }

  BNLog("[RemoteBreach] Network unlock complete - Unlocked: " + ToString(unlockedCount) +
        ", Skipped: " + ToString(skippedCount));
}
