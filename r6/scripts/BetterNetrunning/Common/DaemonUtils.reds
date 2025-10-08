// ============================================================================
// BetterNetrunning - Common Daemon Filter Utilities
// ============================================================================
// Shared logic for device type detection, daemon identification, and
// network connectivity checks used by both AccessPointBreach and RemoteBreach
// ============================================================================

module BetterNetrunning.Common

// ============================================================================
// DaemonFilterUtils - Common filtering utilities for daemon display logic
// ============================================================================
public abstract class DaemonFilterUtils {

    // ========================================================================
    // DEVICE TYPE DETECTION
    // ========================================================================

    /// Check if device is a surveillance camera
    /// @param devicePS Device power state to check
    /// @return true if device is a camera, false otherwise
    public static func IsCamera(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return IsDefined(devicePS as SurveillanceCameraControllerPS);
    }

    /// Check if device is a security turret
    /// @param devicePS Device power state to check
    /// @return true if device is a turret, false otherwise
    public static func IsTurret(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return IsDefined(devicePS as SecurityTurretControllerPS);
    }

    /// Check if device is a computer/terminal
    /// @param devicePS Device power state to check
    /// @return true if device is a computer, false otherwise
    public static func IsComputer(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return IsDefined(devicePS as ComputerControllerPS);
    }

    /// Check if entity is a regular device (not AccessPoint, not Computer)
    /// @param entity Game object to check
    /// @return true if entity is a regular hackable device
    public static func IsRegularDevice(entity: wref<GameObject>) -> Bool {
        return IsDefined(entity as Device)
            && !IsDefined(entity as AccessPoint)
            && !IsDefined((entity as Device).GetDevicePS() as ComputerControllerPS);
    }

    // ========================================================================
    // NETWORK CONNECTION CHECK
    // ========================================================================

    /// Check if entity is connected to an access point network
    /// @param entity Game object to check
    /// @return true if connected to network, false otherwise
    public static func IsConnectedToNetwork(entity: wref<GameObject>) -> Bool {
        // Regular devices (not AccessPoint, not Computer) are considered connected
        if DaemonFilterUtils.IsRegularDevice(entity) {
            return true;
        }
        return false;
    }

    /// Check if device is connected to physical access point
    /// (Delegates to device's native method)
    /// @param devicePS Device power state to check
    /// @return true if connected to physical access point
    public static func IsConnectedToPhysicalAccessPoint(devicePS: ref<ScriptableDeviceComponentPS>) -> Bool {
        return devicePS.IsConnectedToPhysicalAccessPoint();
    }

    // ========================================================================
    // DAEMON TYPE DETECTION
    // ========================================================================

    /// Check if action is a Camera unlock daemon
    /// @param actionID TweakDB ID of the daemon action
    /// @return true if this is the camera unlock daemon
    public static func IsCameraDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, t"MinigameAction.UnlockCameraQuickhacks");
    }

    /// Check if action is a Turret unlock daemon
    /// @param actionID TweakDB ID of the daemon action
    /// @return true if this is the turret unlock daemon
    public static func IsTurretDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, t"MinigameAction.UnlockTurretQuickhacks");
    }

    /// Check if action is an NPC unlock daemon
    /// @param actionID TweakDB ID of the daemon action
    /// @return true if this is the NPC unlock daemon
    public static func IsNPCDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, t"MinigameAction.UnlockNPCQuickhacks");
    }

    /// Check if action is a Basic device unlock daemon
    /// @param actionID TweakDB ID of the daemon action
    /// @return true if this is the basic unlock daemon
    public static func IsBasicDaemon(actionID: TweakDBID) -> Bool {
        return Equals(actionID, t"MinigameAction.NetworkDeviceBasicActions");
    }

    /// Check if action is any unlock daemon type
    /// @param actionID TweakDB ID of the daemon action
    /// @return true if this is any unlock daemon (Camera/Turret/NPC/Basic)
    public static func IsUnlockDaemon(actionID: TweakDBID) -> Bool {
        return DaemonFilterUtils.IsCameraDaemon(actionID)
            || DaemonFilterUtils.IsTurretDaemon(actionID)
            || DaemonFilterUtils.IsNPCDaemon(actionID)
            || DaemonFilterUtils.IsBasicDaemon(actionID);
    }

    // ========================================================================
    // DEVICE CAPABILITY CHECK (for daemon display logic)
    // ========================================================================

    /// Determine if Camera daemon should be shown for this device
    /// @param devicePS Device power state
    /// @param data Connected device class types
    /// @return true if Camera daemon should be visible
    public static func ShouldShowCameraDaemon(
        devicePS: ref<ScriptableDeviceComponentPS>,
        data: ConnectedClassTypes
    ) -> Bool {
        // Show Camera daemon if:
        // 1. Device IS a camera, OR
        // 2. Device has cameras in network
        return DaemonFilterUtils.IsCamera(devicePS) || data.surveillanceCamera;
    }

    /// Determine if Turret daemon should be shown for this device
    /// @param devicePS Device power state
    /// @param data Connected device class types
    /// @return true if Turret daemon should be visible
    public static func ShouldShowTurretDaemon(
        devicePS: ref<ScriptableDeviceComponentPS>,
        data: ConnectedClassTypes
    ) -> Bool {
        // Show Turret daemon if:
        // 1. Device IS a turret, OR
        // 2. Device has turrets in network
        return DaemonFilterUtils.IsTurret(devicePS) || data.securityTurret;
    }

    /// Determine if NPC daemon should be shown for this device
    /// @param data Connected device class types
    /// @return true if NPC daemon should be visible
    public static func ShouldShowNPCDaemon(data: ConnectedClassTypes) -> Bool {
        // Show NPC daemon if device has NPCs in network
        return data.puppet;
    }

    // ========================================================================
    // UTILITY HELPERS
    // ========================================================================

    /// Get device type as string for logging/debugging
    /// @param devicePS Device power state
    /// @return Device type name (Camera/Turret/Computer/Device)
    public static func GetDeviceTypeName(devicePS: ref<ScriptableDeviceComponentPS>) -> String {
        if DaemonFilterUtils.IsCamera(devicePS) {
            return "Camera";
        } else if DaemonFilterUtils.IsTurret(devicePS) {
            return "Turret";
        } else if DaemonFilterUtils.IsComputer(devicePS) {
            return "Computer";
        } else {
            return "Device";
        }
    }

    /// Get daemon type as string for logging/debugging
    /// @param actionID TweakDB ID of the daemon action
    /// @return Daemon type name (Camera/Turret/NPC/Basic/Unknown)
    public static func GetDaemonTypeName(actionID: TweakDBID) -> String {
        if DaemonFilterUtils.IsCameraDaemon(actionID) {
            return "Camera";
        } else if DaemonFilterUtils.IsTurretDaemon(actionID) {
            return "Turret";
        } else if DaemonFilterUtils.IsNPCDaemon(actionID) {
            return "NPC";
        } else if DaemonFilterUtils.IsBasicDaemon(actionID) {
            return "Basic";
        } else {
            return "Unknown";
        }
    }
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================
/*
// Example 1: Device type detection (replaces IsDefined checks)
let devicePS: ref<ScriptableDeviceComponentPS> = ...;
if DaemonFilterUtils.IsCamera(devicePS) {
    // Camera-specific logic
}

// Example 2: Daemon type identification
let actionID: TweakDBID = t"MinigameAction.UnlockCameraQuickhacks";
if DaemonFilterUtils.IsCameraDaemon(actionID) {
    // Camera daemon-specific logic
}

// Example 3: Network connectivity check
let entity: wref<GameObject> = ...;
if DaemonFilterUtils.IsConnectedToNetwork(entity) {
    // Network-dependent logic
}

// Example 4: Should show daemon logic
let data: ConnectedClassTypes = ...;
if DaemonFilterUtils.ShouldShowCameraDaemon(devicePS, data) {
    // Show Camera daemon in UI
}

// Example 5: Logging with device type name
let deviceType: String = DaemonFilterUtils.GetDeviceTypeName(devicePS);
BNLog("Device type: " + deviceType);
*/
