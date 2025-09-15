module BetterNetrunningConfig

public class BetterNetrunningSettings {

    // !!! WARNING !!!
    // If using Native Settings UI, the values in this file will have no effect.

    // ---- ENABLE CLASSIC MODE ----
    // If true, the entire network can be breached by uploading any daemon. This disables the subnet system, along with the corresponding breach daemons.
    public static func EnableClassicMode() -> Bool { return false; }

    // ---- UNLOCK NETWORK IF NO ACCESS POINTS PRESENT ----
    // If true, will allow all quickhacks automatically if there are no access points on the network.
    public static func UnlockIfNoAccessPoint() -> Bool { return true; }

    // ---- ALLOW BREACHING UNCONSCIOUS NPCS ----
    // If true, you can perform a network breach on any unconscious NPC connected to a network.
    public static func AllowBreachingUnconsciousNPCs() -> Bool { return true; }

    // ---- BLOCK CAMERA DISABLE QUICKHACK ----
    // If true, the "enable/disable" quickhack will NOT be available on cameras.
    public static func BlockCameraDisableQuickhack() -> Bool { return false; }

    // ---- BLOCK TURRET DISABLE QUICKHACK ----
    // If true, the "enable/disable" quickhack will NOT be available on turrets.
    public static func BlockTurretDisableQuickhack() -> Bool { return false; }

    // ---- ALWAYS ALLOW PING ----
    // If true, the "ping" quickhack will be available on unbreached networks.
    public static func AlwaysAllowPing() -> Bool { return true; }

    // ---- ALWAYS ALLOW WHISTLE ----
    // If true, the "whistle" quickhack will be available on unbreached networks.
    public static func AlwaysAllowWhistle() -> Bool { return false; }

    // ---- ALWAYS ALLOW DISTRACT ENEMIES ----
    // If true, the "distract enemies" quickhack will be available on unbreached networks.
    public static func AlwaysAllowDistract() -> Bool { return false; }

    // ---- DISABLE DATAMINE DAEMON V1 AND V2 ----
    // If true, the Datamine V1 and V2 daemons will not appear while breaching access points (only V3 will remain).
    // This helps to reduce clutter from having too many daemons listed, however it also reduces
    // the amount of eddies and quickhack components you can get from each access point.
    public static func DisableDatamineOneTwo() -> Bool { return false; }

    // ---- ALLOW ALL DAEMONS ON ACCESS POINTS ----
    // If true, allows all daemons to be used on physical access points, rather than only Datamine.
    // Disabled by default because there are issues with the way access points are set up that can cause daemons to work incorrectly.
    // Enable at your own risk (not actually dangerous, just buggy).
    public static func AllowAllDaemonsOnAccessPoints() -> Bool { return false; }

    public static func ProgressionRequireAll() -> Bool { return true; }

    // 1: Disabled, 2: Tier 1+, 3: Tier 2, 4: Tier 2+, 5: Tier 3, 6: Tier 3+, 7: Tier 4, 8: Tier 4+, 9: Tier 5, 10: Tier 5+, 11: Tier 5++
    public static func ProgressionCyberdeckBasicDevices() -> Int32 { return 1; }
    public static func ProgressionCyberdeckCameras() -> Int32 { return 1; }
    public static func ProgressionCyberdeckTurrets() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsCovert() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsCombat() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsControl() -> Int32 { return 1; }
    public static func ProgressionCyberdeckNPCsUltimate() -> Int32 { return 1; }

    public static func ProgressionIntelligenceBasicDevices() -> Int32 { return 3; }
    public static func ProgressionIntelligenceCameras() -> Int32 { return 3; }
    public static func ProgressionIntelligenceTurrets() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsCovert() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsCombat() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsControl() -> Int32 { return 3; }
    public static func ProgressionIntelligenceNPCsUltimate() -> Int32 { return 3; }

    public static func ProgressionEnemyLevelNPCsCovert() -> Int32 { return -51; }
    public static func ProgressionEnemyLevelNPCsCombat() -> Int32 { return -51; }
    public static func ProgressionEnemyLevelNPCsControl() -> Int32 { return -51; }
    public static func ProgressionEnemyLevelNPCsUltimate() -> Int32 { return -51; }

    public static func ProgressionAlwaysBasicDevices() -> Bool { return false; }
    public static func ProgressionAlwaysCameras() -> Bool { return false; }
    public static func ProgressionAlwaysTurrets() -> Bool { return false; }
    public static func ProgressionAlwaysNPCsCovert() -> Bool { return false; }
    public static func ProgressionAlwaysNPCsCombat() -> Bool { return false; }
    public static func ProgressionAlwaysNPCsControl() -> Bool { return false; }
    public static func ProgressionAlwaysNPCsUltimate() -> Bool { return false; }

}