-- -----------------------------------------------------------------------------
-- Better Netrunning - Settings Manager
-- -----------------------------------------------------------------------------
-- Handles: Settings load, save, get, set, and CET Override integration
-- -----------------------------------------------------------------------------

local SettingsManager = {}

-- Default settings
local defaults = {
    -- Controls
    BreachingHotkey = 3,
    -- Breaching
    EnableClassicMode = false,
    AllowBreachUnconscious = true,
    -- RemoteBreach
    RemoteBreachEnabledComputer = true,
    RemoteBreachEnabledDevice = true,
    RemoteBreachEnabledVehicle = true,
    RemoteBreachRAMCostPercent = 35,
    -- Removed Quickhacks
    BlockCameraDisable = false,
    BlockTurretDisable = false,
    -- Unlocked Quickhacks
    AlwaysAllowPing = true,
    AlwaysAllowWhistle = false,
    AlwaysAllowDistract = false,
    -- Access Points
    UnlockIfNoAccessPoint = false,
    AutoDatamineBySuccessCount = true,
    AutoExecutePingOnSuccess = true,
    AllowAllDaemonsOnAccessPoints = false,
    -- Progression
    ProgressionRequireAll = true,
    ProgressionCyberdeckEnabled = false,
    ProgressionIntelligenceEnabled = false,
    ProgressionEnemyRarityEnabled = false,
    -- Progression - Cyberdeck
    ProgressionCyberdeckBasicDevices = 1,
    ProgressionCyberdeckCameras = 1,
    ProgressionCyberdeckTurrets = 1,
    ProgressionCyberdeckNPCsCovert = 1,
    ProgressionCyberdeckNPCsCombat = 1,
    ProgressionCyberdeckNPCsControl = 1,
    ProgressionCyberdeckNPCsUltimate = 1,
    -- Progression - Intelligence
    ProgressionIntelligenceBasicDevices = 3,
    ProgressionIntelligenceCameras = 3,
    ProgressionIntelligenceTurrets = 3,
    ProgressionIntelligenceNPCsCovert = 3,
    ProgressionIntelligenceNPCsCombat = 3,
    ProgressionIntelligenceNPCsControl = 3,
    ProgressionIntelligenceNPCsUltimate = 3,
    -- Progression - Enemy Rarity
    ProgressionEnemyRarityNPCsCovert = 8,
    ProgressionEnemyRarityNPCsCombat = 8,
    ProgressionEnemyRarityNPCsControl = 8,
    ProgressionEnemyRarityNPCsUltimate = 8,
    -- Progression - Always Unlocked
    AlwaysBasicDevices = false,
    AlwaysCameras = false,
    AlwaysTurrets = false,
    AlwaysNPCsCovert = false,
    AlwaysNPCsCombat = false,
    AlwaysNPCsControl = false,
    AlwaysNPCsUltimate = false,
    -- Debug
    EnableDebugLog = false
}

-- Current settings
local current = {}

-- Initialize: Set current to default values
for k, v in pairs(defaults) do
    current[k] = v
end

-- Load settings from file
function SettingsManager.Load()
    local file = io.open("settings.json", "r")
    if file ~= nil then
        local contents = file:read("*a")
        local validJson, savedState = pcall(function() return json.decode(contents) end)

        if validJson then
            file:close()
            for key, _ in pairs(defaults) do
                if savedState[key] ~= nil then
                    current[key] = savedState[key]
                end
            end
            print("[Better Netrunning] Settings loaded from settings.json")
            return true
        end
        file:close()
    end

    print("[Better Netrunning] Using default settings")
    return false
end

-- Save settings to file
function SettingsManager.Save()
    local validJson, contents = pcall(function() return json.encode(current) end)

    if validJson and contents ~= nil then
        local updatedFile = io.open("settings.json", "w+")
        updatedFile:write(contents)
        updatedFile:close()
        return true
    end

    print("[Better Netrunning] ERROR: Failed to save settings")
    return false
end

-- Get setting value
function SettingsManager.Get(key)
    return current[key]
end

-- Set setting value
function SettingsManager.Set(key, value)
    current[key] = value
end

-- Get all settings (for UI builder)
function SettingsManager.GetAll()
    return current
end

-- Setup CET Override functions (REDscript integration)
function SettingsManager.OverrideConfigFunctions()
    -- Controls
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "BreachingHotkey;",
        function() return current.BreachingHotkey end)
    -- Breaching
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "EnableClassicMode;",
        function() return current.EnableClassicMode end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AllowBreachingUnconsciousNPCs;",
        function() return current.AllowBreachUnconscious end)
    -- RemoteBreach
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "RemoteBreachEnabledComputer;",
        function() return current.RemoteBreachEnabledComputer end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "RemoteBreachEnabledDevice;",
        function() return current.RemoteBreachEnabledDevice end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "RemoteBreachEnabledVehicle;",
        function() return current.RemoteBreachEnabledVehicle end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "RemoteBreachRAMCostPercent;",
        function() return current.RemoteBreachRAMCostPercent end)
    -- Removed Quickhacks
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "BlockCameraDisableQuickhack;",
        function() return current.BlockCameraDisable end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "BlockTurretDisableQuickhack;",
        function() return current.BlockTurretDisable end)
    -- Unlocked Quickhacks
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysAllowPing;",
        function() return current.AlwaysAllowPing end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysAllowWhistle;",
        function() return current.AlwaysAllowWhistle end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysAllowDistract;",
        function() return current.AlwaysAllowDistract end)
    -- Access Points
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "UnlockIfNoAccessPoint;",
        function() return current.UnlockIfNoAccessPoint end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AutoDatamineBySuccessCount;",
        function() return current.AutoDatamineBySuccessCount end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AutoExecutePingOnSuccess;",
        function() return current.AutoExecutePingOnSuccess end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AllowAllDaemonsOnAccessPoints;",
        function() return current.AllowAllDaemonsOnAccessPoints end)
    -- Progression
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionRequireAll;",
        function() return current.ProgressionRequireAll end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckEnabled;",
        function() return current.ProgressionCyberdeckEnabled end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceEnabled;",
        function() return current.ProgressionIntelligenceEnabled end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionEnemyRarityEnabled;",
        function() return current.ProgressionEnemyRarityEnabled end)
    -- Progression - Cyberdeck
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckBasicDevices;",
        function() return current.ProgressionCyberdeckBasicDevices end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckCameras;",
        function() return current.ProgressionCyberdeckCameras end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckTurrets;",
        function() return current.ProgressionCyberdeckTurrets end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckNPCsCovert;",
        function() return current.ProgressionCyberdeckNPCsCovert end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckNPCsCombat;",
        function() return current.ProgressionCyberdeckNPCsCombat end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckNPCsControl;",
        function() return current.ProgressionCyberdeckNPCsControl end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckNPCsUltimate;",
        function() return current.ProgressionCyberdeckNPCsUltimate end)
    -- Progression - Intelligence
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceBasicDevices;",
        function() return current.ProgressionIntelligenceBasicDevices end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceCameras;",
        function() return current.ProgressionIntelligenceCameras end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceTurrets;",
        function() return current.ProgressionIntelligenceTurrets end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceNPCsCovert;",
        function() return current.ProgressionIntelligenceNPCsCovert end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceNPCsCombat;",
        function() return current.ProgressionIntelligenceNPCsCombat end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceNPCsControl;",
        function() return current.ProgressionIntelligenceNPCsControl end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceNPCsUltimate;",
        function() return current.ProgressionIntelligenceNPCsUltimate end)
    -- Progression - Enemy Rarity
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionEnemyRarityNPCsCovert;",
        function() return current.ProgressionEnemyRarityNPCsCovert end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionEnemyRarityNPCsCombat;",
        function() return current.ProgressionEnemyRarityNPCsCombat end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionEnemyRarityNPCsControl;",
        function() return current.ProgressionEnemyRarityNPCsControl end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionEnemyRarityNPCsUltimate;",
        function() return current.ProgressionEnemyRarityNPCsUltimate end)
    -- Progression - Always Unlocked
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysBasicDevices;",
        function() return current.AlwaysBasicDevices end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysCameras;",
        function() return current.AlwaysCameras end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysTurrets;",
        function() return current.AlwaysTurrets end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysNPCsCovert;",
        function() return current.AlwaysNPCsCovert end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysNPCsCombat;",
        function() return current.AlwaysNPCsCombat end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysNPCsControl;",
        function() return current.AlwaysNPCsControl end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysNPCsUltimate;",
        function() return current.AlwaysNPCsUltimate end)
    -- Debug
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "EnableDebugLog;",
        function() return current.EnableDebugLog end)

    print("[Better Netrunning] CET Override functions registered")
end

return SettingsManager
