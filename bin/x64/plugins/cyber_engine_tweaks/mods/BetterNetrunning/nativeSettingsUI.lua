-- -----------------------------------------------------------------------------
-- Better Netrunning - NativeSettings UI Builder
-- -----------------------------------------------------------------------------
-- Handles: NativeSettings UI construction and dynamic Progression UI
-- -----------------------------------------------------------------------------

local NativeSettingsUI = {}

-- Option table storage (for dynamic UI rebuild)
local progressionOptionTables = {
    cyberdeck = {},
    intelligence = {},
    enemyRarity = {}
}

-- Localization helper
local function GetLocKey(key)
    return "LocKey#" .. tostring(LocKey(key).hash):gsub("ULL$", "")
end

-- Main UI builder
function NativeSettingsUI.Build(nativeSettings, SettingsManager, TweakDBSetup)
    local settings = SettingsManager.GetAll()

    -- Create tabs and subcategories
    nativeSettings.addTab("/BetterNetrunning", "Better Netrunning")

    nativeSettings.addSubcategory("/BetterNetrunning/Controls", GetLocKey("Category-Controls"))
    nativeSettings.addSubcategory("/BetterNetrunning/Breaching", GetLocKey("Category-Breaching"))
    nativeSettings.addSubcategory("/BetterNetrunning/RemoteBreach", GetLocKey("Category-RemoteBreach"))
    nativeSettings.addSubcategory("/BetterNetrunning/AccessPoints", GetLocKey("Category-AccessPoints"))
    nativeSettings.addSubcategory("/BetterNetrunning/RemovedQuickhacks", GetLocKey("Category-RemovedQuickhacks"))
    nativeSettings.addSubcategory("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("Category-UnlockedQuickhacks"))
    nativeSettings.addSubcategory("/BetterNetrunning/Progression", GetLocKey("Category-Progression"))
    nativeSettings.addSubcategory("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("Category-BetterNetrunning-ProgressionCyberdeck"))
    nativeSettings.addSubcategory("/BetterNetrunning/ProgressionIntelligence", GetLocKey("Category-BetterNetrunning-ProgressionIntelligence"))
    nativeSettings.addSubcategory("/BetterNetrunning/ProgressionEnemyRarity", GetLocKey("Category-BetterNetrunning-ProgressionEnemyRarity"))
    nativeSettings.addSubcategory("/BetterNetrunning/Debug", GetLocKey("Category-Debug"))

    -- Controls
    local breachingHotkey = {[1] = "Choice1", [2] = "Choice2", [3] = "Choice3", [4] = "Choice4"}
    nativeSettings.addSelectorString("/BetterNetrunning/Controls", GetLocKey("DisplayName-BetterNetrunning-BreachingHotkey"), GetLocKey("Description-BetterNetrunning-BreachingHotkey"),
        breachingHotkey, settings.BreachingHotkey, 3,
        function(state)
            SettingsManager.Set("BreachingHotkey", state)
            TweakDBSetup.ApplyBreachingHotkey(state)
            SettingsManager.Save()
        end
    )

    -- Breaching
    nativeSettings.addSwitch("/BetterNetrunning/Breaching", GetLocKey("DisplayName-BetterNetrunning-EnableClassicMode"), GetLocKey("Description-BetterNetrunning-EnableClassicMode"), settings.EnableClassicMode, false, function(state)
        SettingsManager.Set("EnableClassicMode", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/Breaching", GetLocKey("DisplayName-BetterNetrunning-AllowBreachingUnconsciousNPCs"), GetLocKey("Description-BetterNetrunning-AllowBreachingUnconsciousNPCs"), settings.AllowBreachUnconscious, true, function(state)
        SettingsManager.Set("AllowBreachUnconscious", state)
        SettingsManager.Save()
    end)

    -- RemoteBreach
    nativeSettings.addSwitch("/BetterNetrunning/RemoteBreach", GetLocKey("DisplayName-BetterNetrunning-RemoteBreachEnabledComputer"), GetLocKey("Description-BetterNetrunning-RemoteBreachEnabledComputer"), settings.RemoteBreachEnabledComputer, true, function(state)
        SettingsManager.Set("RemoteBreachEnabledComputer", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/RemoteBreach", GetLocKey("DisplayName-BetterNetrunning-RemoteBreachEnabledDevice"), GetLocKey("Description-BetterNetrunning-RemoteBreachEnabledDevice"), settings.RemoteBreachEnabledDevice, true, function(state)
        SettingsManager.Set("RemoteBreachEnabledDevice", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/RemoteBreach", GetLocKey("DisplayName-BetterNetrunning-RemoteBreachEnabledVehicle"), GetLocKey("Description-BetterNetrunning-RemoteBreachEnabledVehicle"), settings.RemoteBreachEnabledVehicle, true, function(state)
        SettingsManager.Set("RemoteBreachEnabledVehicle", state)
        SettingsManager.Save()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/RemoteBreach", GetLocKey("DisplayName-BetterNetrunning-RemoteBreachRAMCostPercent"), GetLocKey("Description-BetterNetrunning-RemoteBreachRAMCostPercent"), 10, 100, 5,
        settings.RemoteBreachRAMCostPercent, 35,
        function(state)
            SettingsManager.Set("RemoteBreachRAMCostPercent", state)
            SettingsManager.Save()
        end
    )

    -- Access Points
    nativeSettings.addSwitch("/BetterNetrunning/AccessPoints", GetLocKey("DisplayName-BetterNetrunning-UnlockIfNoAccessPoint"), GetLocKey("Description-BetterNetrunning-UnlockIfNoAccessPoint"), settings.UnlockIfNoAccessPoint, true, function(state)
        SettingsManager.Set("UnlockIfNoAccessPoint", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/AccessPoints", GetLocKey("DisplayName-BetterNetrunning-AutoDatamineBySuccessCount"), GetLocKey("Description-BetterNetrunning-AutoDatamineBySuccessCount"), settings.AutoDatamineBySuccessCount, false, function(state)
        SettingsManager.Set("AutoDatamineBySuccessCount", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/AccessPoints", GetLocKey("DisplayName-BetterNetrunning-AutoExecutePingOnSuccess"), GetLocKey("Description-BetterNetrunning-AutoExecutePingOnSuccess"), settings.AutoExecutePingOnSuccess, false, function(state)
        SettingsManager.Set("AutoExecutePingOnSuccess", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/AccessPoints", GetLocKey("DisplayName-BetterNetrunning-AllowAllDaemonsOnAccessPoints"), GetLocKey("Description-BetterNetrunning-AllowAllDaemonsOnAccessPoints"), settings.AllowAllDaemonsOnAccessPoints, false, function(state)
        SettingsManager.Set("AllowAllDaemonsOnAccessPoints", state)
        SettingsManager.Save()
    end)

    -- Removed Quickhacks
    nativeSettings.addSwitch("/BetterNetrunning/RemovedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-BlockCameraDisableQuickhack"), GetLocKey("Description-BetterNetrunning-BlockCameraDisableQuickhack"), settings.BlockCameraDisable, false, function(state)
        SettingsManager.Set("BlockCameraDisable", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/RemovedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-BlockTurretDisableQuickhack"), GetLocKey("Description-BetterNetrunning-BlockTurretDisableQuickhack"), settings.BlockTurretDisable, false, function(state)
        SettingsManager.Set("BlockTurretDisable", state)
        SettingsManager.Save()
    end)

    -- Always Unlocked Quickhacks
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysAllowPing"), GetLocKey("Description-BetterNetrunning-AlwaysAllowPing"), settings.AlwaysAllowPing, true, function(state)
        SettingsManager.Set("AlwaysAllowPing", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysAllowWhistle"), GetLocKey("Description-BetterNetrunning-AlwaysAllowWhistle"), settings.AlwaysAllowWhistle, false, function(state)
        SettingsManager.Set("AlwaysAllowWhistle", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysAllowDistract"), GetLocKey("Description-BetterNetrunning-AlwaysAllowDistract"), settings.AlwaysAllowDistract, false, function(state)
        SettingsManager.Set("AlwaysAllowDistract", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysBasicDevices"), GetLocKey("Description-BetterNetrunning-AlwaysBasicDevices"), settings.AlwaysBasicDevices, false, function(state)
        SettingsManager.Set("AlwaysBasicDevices", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysCameras"), GetLocKey("Description-BetterNetrunning-AlwaysCameras"), settings.AlwaysCameras, false, function(state)
        SettingsManager.Set("AlwaysCameras", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysTurrets"), GetLocKey("Description-BetterNetrunning-AlwaysTurrets"), settings.AlwaysTurrets, false, function(state)
        SettingsManager.Set("AlwaysTurrets", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysNPCsCovert"), GetLocKey("Description-BetterNetrunning-AlwaysNPCsCovert"), settings.AlwaysNPCsCovert, false, function(state)
        SettingsManager.Set("AlwaysNPCsCovert", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysNPCsCombat"), GetLocKey("Description-BetterNetrunning-AlwaysNPCsCombat"), settings.AlwaysNPCsCombat, false, function(state)
        SettingsManager.Set("AlwaysNPCsCombat", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysNPCsControl"), GetLocKey("Description-BetterNetrunning-AlwaysNPCsControl"), settings.AlwaysNPCsControl, false, function(state)
        SettingsManager.Set("AlwaysNPCsControl", state)
        SettingsManager.Save()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysNPCsUltimate"), GetLocKey("Description-BetterNetrunning-AlwaysNPCsUltimate"), settings.AlwaysNPCsUltimate, false, function(state)
        SettingsManager.Set("AlwaysNPCsUltimate", state)
        SettingsManager.Save()
    end)

    -- Progression
    nativeSettings.addSwitch("/BetterNetrunning/Progression", GetLocKey("DisplayName-BetterNetrunning-ProgressionRequireAll"), GetLocKey("Description-BetterNetrunning-ProgressionRequireAll"), settings.ProgressionRequireAll, true, function(state)
        SettingsManager.Set("ProgressionRequireAll", state)
        SettingsManager.Save()
    end)

    -- Progression - Cyberdeck (dynamic UI rebuild)
    NativeSettingsUI.BuildCyberdeckProgression(nativeSettings, SettingsManager)

    -- Progression - Intelligence (dynamic UI rebuild)
    NativeSettingsUI.BuildIntelligenceProgression(nativeSettings, SettingsManager)

    -- Progression - Enemy Rarity (dynamic UI rebuild)
    NativeSettingsUI.BuildEnemyRarityProgression(nativeSettings, SettingsManager)

    -- Debug
    nativeSettings.addSwitch("/BetterNetrunning/Debug", GetLocKey("DisplayName-BetterNetrunning-EnableDebugLog"), GetLocKey("Description-BetterNetrunning-EnableDebugLog"), settings.EnableDebugLog, false, function(state)
        SettingsManager.Set("EnableDebugLog", state)
        SettingsManager.Save()
    end)

    print("[Better Netrunning] NativeSettings UI built successfully")
end

-- Progression - Cyberdeck (dynamic UI)
function NativeSettingsUI.BuildCyberdeckProgression(nativeSettings, SettingsManager)
    local settings = SettingsManager.GetAll()

    nativeSettings.addSwitch("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckEnabled"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckEnabled"), settings.ProgressionCyberdeckEnabled, false, function(state)
        SettingsManager.Set("ProgressionCyberdeckEnabled", state)
        SettingsManager.Save()
        NativeSettingsUI.RebuildCyberdeckOptions(nativeSettings, SettingsManager)
        nativeSettings.refresh()
    end)

    NativeSettingsUI.CreateCyberdeckOptions(nativeSettings, SettingsManager)
end

function NativeSettingsUI.CreateCyberdeckOptions(nativeSettings, SettingsManager)
    local settings = SettingsManager.GetAll()
    if not settings.ProgressionCyberdeckEnabled then
        return
    end

    local cyberdeckQualityOptions = {
        [1] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-Common"),
        [2] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-CommonPlus"),
        [3] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-Uncommon"),
        [4] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-UncommonPlus"),
        [5] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-Rare"),
        [6] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-RarePlus"),
        [7] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-Epic"),
        [8] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-EpicPlus"),
        [9] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-Legendary"),
        [10] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-LegendaryPlus"),
        [11] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-LegendaryPlusPlus")
    }

    local opt
    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckBasicDevices"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckBasicDevices"), cyberdeckQualityOptions, settings.ProgressionCyberdeckBasicDevices, 1, function(state)
        SettingsManager.Set("ProgressionCyberdeckBasicDevices", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.cyberdeck, opt)

    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckCameras"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckCameras"), cyberdeckQualityOptions, settings.ProgressionCyberdeckCameras, 1, function(state)
        SettingsManager.Set("ProgressionCyberdeckCameras", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.cyberdeck, opt)

    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckTurrets"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckTurrets"), cyberdeckQualityOptions, settings.ProgressionCyberdeckTurrets, 1, function(state)
        SettingsManager.Set("ProgressionCyberdeckTurrets", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.cyberdeck, opt)

    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsCovert"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckNPCsCovert"), cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsCovert, 1, function(state)
        SettingsManager.Set("ProgressionCyberdeckNPCsCovert", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.cyberdeck, opt)

    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsCombat"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckNPCsCombat"), cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsCombat, 1, function(state)
        SettingsManager.Set("ProgressionCyberdeckNPCsCombat", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.cyberdeck, opt)

    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsControl"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckNPCsControl"), cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsControl, 1, function(state)
        SettingsManager.Set("ProgressionCyberdeckNPCsControl", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.cyberdeck, opt)

    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsUltimate"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckNPCsUltimate"), cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsUltimate, 1, function(state)
        SettingsManager.Set("ProgressionCyberdeckNPCsUltimate", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.cyberdeck, opt)
end

function NativeSettingsUI.ClearCyberdeckOptions(nativeSettings)
    for _, optionTable in ipairs(progressionOptionTables.cyberdeck) do
        nativeSettings.removeOption(optionTable)
    end
    progressionOptionTables.cyberdeck = {}
end

function NativeSettingsUI.RebuildCyberdeckOptions(nativeSettings, SettingsManager)
    NativeSettingsUI.ClearCyberdeckOptions(nativeSettings)
    NativeSettingsUI.CreateCyberdeckOptions(nativeSettings, SettingsManager)
end

-- Progression - Intelligence (dynamic UI)
function NativeSettingsUI.BuildIntelligenceProgression(nativeSettings, SettingsManager)
    local settings = SettingsManager.GetAll()

    nativeSettings.addSwitch("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceEnabled"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceEnabled"), settings.ProgressionIntelligenceEnabled, false, function(state)
        SettingsManager.Set("ProgressionIntelligenceEnabled", state)
        SettingsManager.Save()
        NativeSettingsUI.RebuildIntelligenceOptions(nativeSettings, SettingsManager)
        nativeSettings.refresh()
    end)

    NativeSettingsUI.CreateIntelligenceOptions(nativeSettings, SettingsManager)
end

function NativeSettingsUI.CreateIntelligenceOptions(nativeSettings, SettingsManager)
    local settings = SettingsManager.GetAll()
    if not settings.ProgressionIntelligenceEnabled then
        return
    end

    local opt
    opt = nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceBasicDevices"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceBasicDevices"), 3, 20, 1, settings.ProgressionIntelligenceBasicDevices, 3, function(state)
        SettingsManager.Set("ProgressionIntelligenceBasicDevices", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.intelligence, opt)

    opt = nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceCameras"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceCameras"), 3, 20, 1, settings.ProgressionIntelligenceCameras, 3, function(state)
        SettingsManager.Set("ProgressionIntelligenceCameras", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.intelligence, opt)

    opt = nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceTurrets"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceTurrets"), 3, 20, 1, settings.ProgressionIntelligenceTurrets, 3, function(state)
        SettingsManager.Set("ProgressionIntelligenceTurrets", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.intelligence, opt)

    opt = nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsCovert"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceNPCsCovert"), 3, 20, 1, settings.ProgressionIntelligenceNPCsCovert, 3, function(state)
        SettingsManager.Set("ProgressionIntelligenceNPCsCovert", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.intelligence, opt)

    opt = nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsCombat"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceNPCsCombat"), 3, 20, 1, settings.ProgressionIntelligenceNPCsCombat, 3, function(state)
        SettingsManager.Set("ProgressionIntelligenceNPCsCombat", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.intelligence, opt)

    opt = nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsControl"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceNPCsControl"), 3, 20, 1, settings.ProgressionIntelligenceNPCsControl, 3, function(state)
        SettingsManager.Set("ProgressionIntelligenceNPCsControl", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.intelligence, opt)

    opt = nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsUltimate"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceNPCsUltimate"), 3, 20, 1, settings.ProgressionIntelligenceNPCsUltimate, 3, function(state)
        SettingsManager.Set("ProgressionIntelligenceNPCsUltimate", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.intelligence, opt)
end

function NativeSettingsUI.ClearIntelligenceOptions(nativeSettings)
    for _, optionTable in ipairs(progressionOptionTables.intelligence) do
        nativeSettings.removeOption(optionTable)
    end
    progressionOptionTables.intelligence = {}
end

function NativeSettingsUI.RebuildIntelligenceOptions(nativeSettings, SettingsManager)
    NativeSettingsUI.ClearIntelligenceOptions(nativeSettings)
    NativeSettingsUI.CreateIntelligenceOptions(nativeSettings, SettingsManager)
end

-- Progression - Enemy Rarity (dynamic UI)
function NativeSettingsUI.BuildEnemyRarityProgression(nativeSettings, SettingsManager)
    local settings = SettingsManager.GetAll()

    nativeSettings.addSwitch("/BetterNetrunning/ProgressionEnemyRarity", GetLocKey("DisplayName-BetterNetrunning-ProgressionEnemyRarityEnabled"), GetLocKey("Description-BetterNetrunning-ProgressionEnemyRarityEnabled"), settings.ProgressionEnemyRarityEnabled, false, function(state)
        SettingsManager.Set("ProgressionEnemyRarityEnabled", state)
        SettingsManager.Save()
        NativeSettingsUI.RebuildEnemyRarityOptions(nativeSettings, SettingsManager)
        nativeSettings.refresh()
    end)

    NativeSettingsUI.CreateEnemyRarityOptions(nativeSettings, SettingsManager)
end

function NativeSettingsUI.CreateEnemyRarityOptions(nativeSettings, SettingsManager)
    local settings = SettingsManager.GetAll()
    if not settings.ProgressionEnemyRarityEnabled then
        return
    end

    local enemyRarityOptions = {
        [1] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Trash"),
        [2] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Weak"),
        [3] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Normal"),
        [4] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Rare"),
        [5] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Officer"),
        [6] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Elite"),
        [7] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Boss"),
        [8] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-MaxTac")
    }

    local opt
    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", GetLocKey("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsCovert"), GetLocKey("Description-BetterNetrunning-ProgressionEnemyRarityNPCsCovert"), enemyRarityOptions, settings.ProgressionEnemyRarityNPCsCovert, 8, function(state)
        SettingsManager.Set("ProgressionEnemyRarityNPCsCovert", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.enemyRarity, opt)

    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", GetLocKey("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsCombat"), GetLocKey("Description-BetterNetrunning-ProgressionEnemyRarityNPCsCombat"), enemyRarityOptions, settings.ProgressionEnemyRarityNPCsCombat, 8, function(state)
        SettingsManager.Set("ProgressionEnemyRarityNPCsCombat", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.enemyRarity, opt)

    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", GetLocKey("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsControl"), GetLocKey("Description-BetterNetrunning-ProgressionEnemyRarityNPCsControl"), enemyRarityOptions, settings.ProgressionEnemyRarityNPCsControl, 8, function(state)
        SettingsManager.Set("ProgressionEnemyRarityNPCsControl", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.enemyRarity, opt)

    opt = nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", GetLocKey("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsUltimate"), GetLocKey("Description-BetterNetrunning-ProgressionEnemyRarityNPCsUltimate"), enemyRarityOptions, settings.ProgressionEnemyRarityNPCsUltimate, 8, function(state)
        SettingsManager.Set("ProgressionEnemyRarityNPCsUltimate", state)
        SettingsManager.Save()
    end)
    table.insert(progressionOptionTables.enemyRarity, opt)
end

function NativeSettingsUI.ClearEnemyRarityOptions(nativeSettings)
    for _, optionTable in ipairs(progressionOptionTables.enemyRarity) do
        nativeSettings.removeOption(optionTable)
    end
    progressionOptionTables.enemyRarity = {}
end

function NativeSettingsUI.RebuildEnemyRarityOptions(nativeSettings, SettingsManager)
    NativeSettingsUI.ClearEnemyRarityOptions(nativeSettings)
    NativeSettingsUI.CreateEnemyRarityOptions(nativeSettings, SettingsManager)
end

return NativeSettingsUI
