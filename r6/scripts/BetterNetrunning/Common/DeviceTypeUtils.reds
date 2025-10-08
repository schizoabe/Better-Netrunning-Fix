// -----------------------------------------------------------------------------
// Device Type Utilities
// -----------------------------------------------------------------------------
// Provides centralized device type classification and breach flag management.
// Eliminates duplicate device type checking logic across the codebase.
//
// DESIGN RATIONALE:
// - Single Responsibility: Device type determination
// - DRY Principle: Replaces 16+ duplicate type checks
// - Type Safety: Enum-based classification
// - Maintainability: Centralized breach flag access
//
// USAGE:
// let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(devicePS);
// if DeviceTypeUtils.IsBreached(deviceType, sharedPS) { ... }
// -----------------------------------------------------------------------------

module BetterNetrunning.Common

// Device type classification enum
public enum DeviceType {
  NPC = 0,
  Camera = 1,
  Turret = 2,
  Basic = 3
}

// Helper struct for SetActionsInactiveUnbreached() - Device classification
public struct DeviceBreachInfo {
  public let isCamera: Bool;
  public let isTurret: Bool;
  public let isStandaloneDevice: Bool;
}

// Helper struct for SetActionsInactiveUnbreached() - Permission calculation
public struct DevicePermissions {
  public let allowCameras: Bool;
  public let allowTurrets: Bool;
  public let allowBasicDevices: Bool;
  public let allowPing: Bool;
  public let allowDistraction: Bool;
}

// Helper struct for GetAllChoices() - NPC hack permissions
public struct NPCHackPermissions {
  public let isBreached: Bool;
  public let allowCovert: Bool;
  public let allowCombat: Bool;
  public let allowControl: Bool;
  public let allowUltimate: Bool;
  public let allowPing: Bool;
  public let allowWhistle: Bool;
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

// Centralized device type utilities
public abstract class DeviceTypeUtils {

  // ==================== Type Detection ====================

  // Determines device type from DeviceComponentPS
  // Replaces duplicate if-else chains across codebase
  public static func GetDeviceType(device: ref<DeviceComponentPS>) -> DeviceType {
    // NPCs (PuppetDeviceLink or CommunityProxy)
    if IsDefined(device as PuppetDeviceLinkPS) || IsDefined(device as CommunityProxyPS) {
      return DeviceType.NPC;
    }

    // Get owner entity for Camera/Turret detection
    let entity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;

    // Cameras
    if IsDefined(entity as SurveillanceCamera) {
      return DeviceType.Camera;
    }

    // Turrets
    if IsDefined(entity as SecurityTurret) {
      return DeviceType.Turret;
    }

    // Basic devices (everything else)
    return DeviceType.Basic;
  }

  // Alternative: Type detection from GameObject entity
  public static func GetDeviceTypeFromEntity(entity: wref<GameObject>) -> DeviceType {
    if IsDefined(entity as SurveillanceCamera) {
      return DeviceType.Camera;
    }
    if IsDefined(entity as SecurityTurret) {
      return DeviceType.Turret;
    }
    if IsDefined(entity as ScriptedPuppet) {
      return DeviceType.NPC;
    }
    return DeviceType.Basic;
  }

  // ==================== Breach Flag Management ====================

  // Gets breach state for specific device type
  // Centralizes m_betterNetrunningBreach* field access
  public static func IsBreached(deviceType: DeviceType, sharedPS: ref<SharedGameplayPS>) -> Bool {
    if !IsDefined(sharedPS) {
      return false;
    }

    switch deviceType {
      case DeviceType.NPC:
        return sharedPS.m_betterNetrunningBreachedNPCs;
      case DeviceType.Camera:
        return sharedPS.m_betterNetrunningBreachedCameras;
      case DeviceType.Turret:
        return sharedPS.m_betterNetrunningBreachedTurrets;
      default: // DeviceType.Basic
        return sharedPS.m_betterNetrunningBreachedBasic;
    }
  }

  // Sets breach state for specific device type
  // Centralizes m_betterNetrunningBreach* field modification
  public static func SetBreached(deviceType: DeviceType, sharedPS: ref<SharedGameplayPS>, value: Bool) -> Void {
    if !IsDefined(sharedPS) {
      return;
    }

    switch deviceType {
      case DeviceType.NPC:
        sharedPS.m_betterNetrunningBreachedNPCs = value;
        break;
      case DeviceType.Camera:
        sharedPS.m_betterNetrunningBreachedCameras = value;
        break;
      case DeviceType.Turret:
        sharedPS.m_betterNetrunningBreachedTurrets = value;
        break;
      default: // DeviceType.Basic
        sharedPS.m_betterNetrunningBreachedBasic = value;
        break;
    }
  }

  // ==================== Unlock Flag Management ====================

  // Checks if device type should be unlocked based on BreachUnlockFlags
  public static func ShouldUnlockByFlags(deviceType: DeviceType, flags: BreachUnlockFlags) -> Bool {
    switch deviceType {
      case DeviceType.NPC:
        return flags.unlockNPCs;
      case DeviceType.Camera:
        return flags.unlockCameras;
      case DeviceType.Turret:
        return flags.unlockTurrets;
      default: // DeviceType.Basic
        return flags.unlockBasic;
    }
  }

  // ==================== Helper Predicates ====================

  // Type checking predicates for readability
  public static func IsNPC(deviceType: DeviceType) -> Bool {
    return Equals(deviceType, DeviceType.NPC);
  }

  public static func IsCamera(deviceType: DeviceType) -> Bool {
    return Equals(deviceType, DeviceType.Camera);
  }

  public static func IsTurret(deviceType: DeviceType) -> Bool {
    return Equals(deviceType, DeviceType.Turret);
  }

  public static func IsBasicDevice(deviceType: DeviceType) -> Bool {
    return Equals(deviceType, DeviceType.Basic);
  }

  // ==================== Debug Utilities ====================

  // Converts DeviceType enum to string for logging
  public static func DeviceTypeToString(deviceType: DeviceType) -> String {
    switch deviceType {
      case DeviceType.NPC: return "NPC";
      case DeviceType.Camera: return "Camera";
      case DeviceType.Turret: return "Turret";
      default: return "Basic";
    }
  }
}
