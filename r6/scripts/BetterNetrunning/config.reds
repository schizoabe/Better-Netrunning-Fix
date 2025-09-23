module BetterNetrunningConfig

public class BetterNetrunningSettings {

    // !!! WARNING !!!
    // If using Native Settings UI, the values in this file will have no effect.

    // Controls
    public static func BreachingHotkey() -> String { return "Choice3"; }

    // Breaching
    public static func EnableClassicMode() -> Bool { return false; }
    public static func AllowBreachingUnconsciousNPCs() -> Bool { return true; }

    // Access Points
    public static func UnlockIfNoAccessPoint() -> Bool { return true; }
    public static func DisableDatamineOneTwo() -> Bool { return false; }
    public static func AllowAllDaemonsOnAccessPoints() -> Bool { return false; }

    // Removed Quickhacks
    public static func BlockCameraDisableQuickhack() -> Bool { return false; }
    public static func BlockTurretDisableQuickhack() -> Bool { return false; }

    // Always Unlocked Quickhacks
    public static func AlwaysAllowPing() -> Bool { return true; }
    public static func AlwaysAllowWhistle() -> Bool { return false; }
    public static func AlwaysAllowDistract() -> Bool { return false; }
    public static func ProgressionAlwaysBasicDevices() -> Bool { return false; }
    public static func ProgressionAlwaysCameras() -> Bool { return false; }
    public static func ProgressionAlwaysTurrets() -> Bool { return false; }
    public static func ProgressionAlwaysNPCsCovert() -> Bool { return false; }
    public static func ProgressionAlwaysNPCsCombat() -> Bool { return false; }
    public static func ProgressionAlwaysNPCsControl() -> Bool { return false; }
    public static func ProgressionAlwaysNPCsUltimate() -> Bool { return false; }

    // Progression
    public static func ProgressionRequireAll() -> Bool { return true; }

    // Progression - Cyberdeck
    public static func ProgressionCyberdeckBasicDevices() -> Int32 { return 1; }
    public static func ProgressionCyberdeckCameras() -> Int32 { return 1; }
    public static func ProgressionCyberdeckTurrets() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsCovert() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsCombat() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsControl() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsUltimate() -> Int32 { return 1; }

    // Progression - Intelligence
    public static func ProgressionIntelligenceBasicDevices() -> Int32 { return 3; }
    public static func ProgressionIntelligenceCameras() -> Int32 { return 3; }
    public static func ProgressionIntelligenceTurrets() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsCovert() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsCombat() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsControl() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsUltimate() -> Int32 { return 3; }

    // Progression - Enemy Rarity
    public static func ProgressionEnemyRarityNPCsCovert() -> Int32 { return 8; }
    public static func ProgressionEnemyRarityNPCsCombat() -> Int32 { return 8; }
    public static func ProgressionEnemyRarityNPCsControl() -> Int32 { return 8; }
    public static func ProgressionEnemyRarityNPCsUltimate() -> Int32 { return 8; }
}