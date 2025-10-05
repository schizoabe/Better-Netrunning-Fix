local settings = {
    -- Controls
    BreachingHotkey = 3,
    -- Breaching
    EnableClassicMode = false,
    AllowBreachUnconscious = true,
    -- Removed Quickhacks
    BlockCameraDisable = false,
    BlockTurretDisable = false,
    -- Unlocked Quickhacks
    AlwaysAllowPing = true,
    AlwaysAllowWhistle = false,
    AlwaysAllowDistract = false,
    -- Access Points
    UnlockIfNoAccessPoint = false,
    DisableDatamineOneTwo = false,
    AllowAllDaemonsOnAccessPoints = false,
    -- Progression
    ProgressionRequireAll = true,
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

registerForEvent("onInit", function()
    local nativeSettings = GetMod("nativeSettings")
    if nativeSettings then
        LoadSettings()
        BuildSettingsMenu(nativeSettings)
        OverrideConfigFunctions()
    else
        print("NativeSettings not loaded. Continuing with settings from config file.")
    end

    SetupAccessProgram("NetworkBasicAccess", "UnlockQuickhacks", LocKey("Better-Netrunning-Basic-Access-Name"), LocKey("Better-Netrunning-Basic-Access-Description"), "ChoiceCaptionParts.BreachProtocolIcon", 20.0)
    SetupAccessProgram("NetworkNPCAccess", "UnlockNPCQuickhacks", LocKey("Better-Netrunning-NPC-Access-Name"), LocKey("Better-Netrunning-NPC-Access-Description"), "ChoiceCaptionParts.PingIcon", 60.0)
    SetupAccessProgram("NetworkCameraAccess", "UnlockCameraQuickhacks", LocKey("Better-Netrunning-Camera-Access-Name"), LocKey("Better-Netrunning-Camera-Access-Description"), "ChoiceCaptionParts.CameraShutdownIcon", 40.0)
    SetupAccessProgram("NetworkTurretAccess", "UnlockTurretQuickhacks", LocKey("Better-Netrunning-Turret-Access-Name"), LocKey("Better-Netrunning-Turret-Access-Description"), "ChoiceCaptionParts.TurretShutdownIcon", 70.0)
    SetupUnconsciousBreachAction()
end)

function SetupUnconsciousBreachAction()
	TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.instigatorPrereqs", {"QuickHack.RemoteBreach_inline0", "QuickHack.QuickHack_inline3", "Takedown.GeneralStateChecks", "Takedown.IsPlayerInExploration", "Takedown.IsPlayerInAcceptableGroundLocomotionState", "Takedown.PlayerNotInSafeZone", "Takedown.GameplayRestrictions", "Takedown.BreachUnconsciousOfficer_inline0", "Takedown.BreachUnconsciousOfficer_inline1", "Takedown.BreachUnconsciousOfficer_inline2"})
	TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.targetActivePrereqs", {"Prereqs.QuickHackUploadingPrereq", "Prereqs.ConnectedToBackdoorActive"})
    TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.targetPrereqs", {"Takedown.BreachUnconsciousOfficer_inline4"})
	TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.startEffects", {"QuickHack.QuickHack_inline12", "QuickHack.QuickHack_inline13"})
	TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.completionEffects", {"QuickHack.QuickHack_inline4", "QuickHack.QuickHack_inline8", "QuickHack.QuickHack_inline10", "QuickHack.QuickHack_inline11"})
    TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.actionName", "RemoteBreach")
	TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.activationTime", {})

    ApplyBreachingHotkey()
end

function SetupAccessProgram(interactionName, actionName, caption, description, icon, complexity)
    TweakDB:CloneRecord("Interactions."..interactionName, "Interactions.NetworkGainAccessProgram")
    TweakDB:SetFlat("Interactions."..interactionName..".caption", caption)
    TweakDB:SetFlat("Interactions."..interactionName..".captionIcon", icon)
    TweakDB:SetFlat("Interactions."..interactionName..".description", description)

    TweakDB:CloneRecord("MinigameAction."..actionName, "MinigameAction.NetworkLowerICEMajor")
    TweakDB:SetFlat("MinigameAction."..actionName..".objectActionType", "ObjectActionType.MinigameUpload")
    TweakDB:SetFlat("MinigameAction."..actionName..".objectActionUI", "Interactions."..interactionName)
    TweakDB:SetFlat("MinigameAction."..actionName..".completionEffects", {})
    TweakDB:SetFlat("MinigameAction."..actionName..".complexity", complexity)
    TweakDB:SetFlat("MinigameAction."..actionName..".type", "MinigameAction.Both")
end

function BuildSettingsMenu(nativeSettings)
    nativeSettings.addTab("/BetterNetrunning", "Better Netrunning")

    nativeSettings.addSubcategory("/BetterNetrunning/Controls", GetLocKey("Category-Controls"))
    nativeSettings.addSubcategory("/BetterNetrunning/Breaching", GetLocKey("Category-Breaching"))
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
            settings.BreachingHotkey = state
            ApplyBreachingHotkey()
            SaveSettings()
        end
    )

    -- Breaching
    nativeSettings.addSwitch("/BetterNetrunning/Breaching", GetLocKey("DisplayName-BetterNetrunning-EnableClassicMode"), GetLocKey("Description-BetterNetrunning-EnableClassicMode"), settings.EnableClassicMode, false, function(state)
        settings.EnableClassicMode = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/Breaching", GetLocKey("DisplayName-BetterNetrunning-AllowBreachingUnconsciousNPCs"), GetLocKey("Description-BetterNetrunning-AllowBreachingUnconsciousNPCs"), settings.AllowBreachUnconscious, true, function(state)
        settings.AllowBreachUnconscious = state
        SaveSettings()
    end)

    -- Access Points
    nativeSettings.addSwitch("/BetterNetrunning/AccessPoints", GetLocKey("DisplayName-BetterNetrunning-UnlockIfNoAccessPoint"), GetLocKey("Description-BetterNetrunning-UnlockIfNoAccessPoint"), settings.UnlockIfNoAccessPoint, true, function(state)
        settings.UnlockIfNoAccessPoint = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/AccessPoints", GetLocKey("DisplayName-BetterNetrunning-DisableDatamineOneTwo"), GetLocKey("Description-BetterNetrunning-DisableDatamineOneTwo"), settings.DisableDatamineOneTwo, false, function(state)
        settings.DisableDatamineOneTwo = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/AccessPoints", GetLocKey("DisplayName-BetterNetrunning-AllowAllDaemonsOnAccessPoints"), GetLocKey("Description-BetterNetrunning-AllowAllDaemonsOnAccessPoints"), settings.AllowAllDaemonsOnAccessPoints, false, function(state)
        settings.AllowAllDaemonsOnAccessPoints = state
        SaveSettings()
    end)

    -- Removed Quickhacks
    nativeSettings.addSwitch("/BetterNetrunning/RemovedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-BlockCameraDisableQuickhack"), GetLocKey("Description-BetterNetrunning-BlockCameraDisableQuickhack"), settings.BlockCameraDisable, false, function(state)
        settings.BlockCameraDisable = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/RemovedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-BlockTurretDisableQuickhack"), GetLocKey("Description-BetterNetrunning-BlockTurretDisableQuickhack"), settings.BlockTurretDisable, false, function(state)
        settings.BlockTurretDisable = state
        SaveSettings()
    end)

    -- Always Unlocked Quickhacks
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysAllowPing"), GetLocKey("Description-BetterNetrunning-AlwaysAllowPing"), settings.AlwaysAllowPing, true, function(state)
        settings.AlwaysAllowPing = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysAllowWhistle"), GetLocKey("Description-BetterNetrunning-AlwaysAllowWhistle"), settings.AlwaysAllowWhistle, false, function(state)
        settings.AlwaysAllowWhistle = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysAllowDistract"), GetLocKey("Description-BetterNetrunning-AlwaysAllowDistract"), settings.AlwaysAllowDistract, false, function(state)
        settings.AlwaysAllowDistract = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysBasicDevices"), GetLocKey("Description-BetterNetrunning-AlwaysBasicDevices"), settings.AlwaysBasicDevices, false, function(state)
        settings.AlwaysBasicDevices = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysCameras"), GetLocKey("Description-BetterNetrunning-AlwaysCameras"), settings.AlwaysCameras, false, function(state)
        settings.AlwaysCameras = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysTurrets"), GetLocKey("Description-BetterNetrunning-AlwaysTurrets"), settings.AlwaysTurrets, false, function(state)
        settings.AlwaysTurrets = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysNPCsCovert"), GetLocKey("Description-BetterNetrunning-AlwaysNPCsCovert"), settings.AlwaysNPCsCovert, false, function(state)
        settings.AlwaysNPCsCovert = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysNPCsCombat"), GetLocKey("Description-BetterNetrunning-AlwaysNPCsCombat"), settings.AlwaysNPCsCombat, false, function(state)
        settings.AlwaysNPCsCombat = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysNPCsControl"), GetLocKey("Description-BetterNetrunning-AlwaysNPCsControl"), settings.AlwaysNPCsControl, false, function(state)
        settings.AlwaysNPCsControl = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", GetLocKey("DisplayName-BetterNetrunning-AlwaysNPCsUltimate"), GetLocKey("Description-BetterNetrunning-AlwaysNPCsUltimate"), settings.AlwaysNPCsUltimate, false, function(state)
        settings.AlwaysNPCsUltimate = state
        SaveSettings()
    end)

    -- Progression
    nativeSettings.addSwitch("/BetterNetrunning/Progression", GetLocKey("DisplayName-BetterNetrunning-ProgressionRequireAll"), GetLocKey("Description-BetterNetrunning-ProgressionRequireAll"), settings.ProgressionRequireAll, true, function(state)
        settings.ProgressionRequireAll = state
        SaveSettings()
    end)

    -- Progression - Cyberdeck
    local cyberdeckQualityOptions = {[1] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-Common"), [2] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-CommonPlus"), [3] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-Uncommon"), [4] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-UncommonPlus"), [5] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-Rare"), [6] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-RarePlus"), [7] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-Epic"), [8] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-EpicPlus"), [9] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-Legendary"), [10] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-LegendaryPlus"), [11] = GetLocKey("DisplayValues-BetterNetrunning-cyberdeckQuality-LegendaryPlusPlus")}
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckBasicDevices"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckBasicDevices"), cyberdeckQualityOptions, settings.ProgressionCyberdeckBasicDevices, 1, function(state)
        settings.ProgressionCyberdeckBasicDevices = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckCameras"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckCameras"), cyberdeckQualityOptions, settings.ProgressionCyberdeckCameras, 1, function(state)
        settings.ProgressionCyberdeckCameras = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckTurrets"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckTurrets"), cyberdeckQualityOptions, settings.ProgressionCyberdeckTurrets, 1, function(state)
        settings.ProgressionCyberdeckTurrets = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsCovert"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckNPCsCovert"), cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsCovert, 1, function(state)
        settings.ProgressionCyberdeckNPCsCovert = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsCombat"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckNPCsCombat"), cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsCombat, 1, function(state)
        settings.ProgressionCyberdeckNPCsCombat = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsControl"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckNPCsControl"), cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsControl, 1, function(state)
        settings.ProgressionCyberdeckNPCsControl = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", GetLocKey("DisplayName-BetterNetrunning-ProgressionCyberdeckNPCsUltimate"), GetLocKey("Description-BetterNetrunning-ProgressionCyberdeckNPCsUltimate"), cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsUltimate, 1, function(state)
        settings.ProgressionCyberdeckNPCsUltimate = state
        SaveSettings()
    end)

    -- Progression - Intelligence
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceBasicDevices"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceBasicDevices"), 3, 20, 1, settings.ProgressionIntelligenceBasicDevices, 3, function(state)
        settings.ProgressionIntelligenceBasicDevices = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceCameras"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceCameras"), 3, 20, 1, settings.ProgressionIntelligenceCameras, 3, function(state)
        settings.ProgressionIntelligenceCameras = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceTurrets"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceTurrets"), 3, 20, 1, settings.ProgressionIntelligenceTurrets, 3, function(state)
        settings.ProgressionIntelligenceTurrets = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsCovert"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceNPCsCovert"), 3, 20, 1, settings.ProgressionIntelligenceNPCsCovert, 3, function(state)
        settings.ProgressionIntelligenceNPCsCovert = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsCombat"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceNPCsCombat"), 3, 20, 1, settings.ProgressionIntelligenceNPCsCombat, 3, function(state)
        settings.ProgressionIntelligenceNPCsCombat = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsControl"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceNPCsControl"), 3, 20, 1, settings.ProgressionIntelligenceNPCsControl, 3, function(state)
        settings.ProgressionIntelligenceNPCsControl = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", GetLocKey("DisplayName-BetterNetrunning-ProgressionIntelligenceNPCsUltimate"), GetLocKey("Description-BetterNetrunning-ProgressionIntelligenceNPCsUltimate"), 3, 20, 1, settings.ProgressionIntelligenceNPCsUltimate, 3, function(state)
        settings.ProgressionIntelligenceNPCsUltimate = state
        SaveSettings()
    end)

    -- Progression - Enemy Rarity
    local enemyRarityOptions = {[1] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Trash"), [2] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Weak"), [3] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Normal"), [4] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Rare"), [5] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Officer"), [6] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Elite"), [7] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-Boss"), [8] = GetLocKey("DisplayValues-BetterNetrunning-NPCRarity-MaxTac")}
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", GetLocKey("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsCovert"), GetLocKey("Description-BetterNetrunning-ProgressionEnemyRarityNPCsCovert"), enemyRarityOptions, settings.ProgressionEnemyRarityNPCsCovert, 8, function(state)
        settings.ProgressionEnemyRarityNPCsCovert = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", GetLocKey("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsCombat"), GetLocKey("Description-BetterNetrunning-ProgressionEnemyRarityNPCsCombat"), enemyRarityOptions, settings.ProgressionEnemyRarityNPCsCombat, 8, function(state)
        settings.ProgressionEnemyRarityNPCsCombat = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", GetLocKey("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsControl"), GetLocKey("Description-BetterNetrunning-ProgressionEnemyRarityNPCsControl"), enemyRarityOptions, settings.ProgressionEnemyRarityNPCsControl, 8, function(state)
        settings.ProgressionEnemyRarityNPCsControl = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", GetLocKey("DisplayName-BetterNetrunning-ProgressionEnemyRarityNPCsUltimate"), GetLocKey("Description-BetterNetrunning-ProgressionEnemyRarityNPCsUltimate"), enemyRarityOptions, settings.ProgressionEnemyRarityNPCsUltimate, 8, function(state)
        settings.ProgressionEnemyRarityNPCsUltimate = state
        SaveSettings()
    end)

    -- Debug
    nativeSettings.addSwitch("/BetterNetrunning/Debug", GetLocKey("DisplayName-BetterNetrunning-EnableDebugLog"), GetLocKey("Description-BetterNetrunning-EnableDebugLog"), settings.EnableDebugLog, false, function(state)
        settings.EnableDebugLog = state
        SaveSettings()
    end)
end

function ApplyBreachingHotkey()
    local map = {[1] = "Choice1", [2] = "Choice2", [3] = "Choice3", [4] = "Choice4"}
    local idx = settings.BreachingHotkey or 3
    if map[idx] == nil then idx = 3 end
    TweakDB:SetFlat("Interactions.BreachUnconsciousOfficer.action", map[idx])
end

function GetLocKey(key)
    return "LocKey#" .. tostring(LocKey(key).hash):gsub("ULL$", "")
end

function SaveSettings()
	local validJson, contents = pcall(function() return json.encode(settings) end)

	if validJson and contents ~= nil then
		local updatedFile = io.open("settings.json", "w+")
		updatedFile:write(contents)
		updatedFile:close()
	end
end

function LoadSettings()
	local file = io.open("settings.json", "r")
	if file ~= nil then
		local contents = file:read("*a")
		local validJson, savedState = pcall(function() return json.decode(contents) end)

		if validJson then
			file:close();
			for key, _ in pairs(settings) do
				if savedState[key] ~= nil then
					settings[key] = savedState[key]
				end
			end
		end
	end
end

function OverrideConfigFunctions()
    -- Controls
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "BreachingHotkey;", function() return settings.BreachingHotkey end)
    -- Breaching
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "EnableClassicMode;", function() return settings.EnableClassicMode end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AllowBreachingUnconsciousNPCs;", function() return settings.AllowBreachUnconscious end)
    -- Removed Quickhacks
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "BlockCameraDisableQuickhack;", function() return settings.BlockCameraDisable end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "BlockTurretDisableQuickhack;", function() return settings.BlockTurretDisable end)
    -- Unlocked Quickhacks
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysAllowPing;", function() return settings.AlwaysAllowPing end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysAllowWhistle;", function() return settings.AlwaysAllowWhistle end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysAllowDistract;", function() return settings.AlwaysAllowDistract end)
    -- Access Points
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "UnlockIfNoAccessPoint;", function() return settings.UnlockIfNoAccessPoint end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "DisableDatamineOneTwo;", function() return settings.DisableDatamineOneTwo end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AllowAllDaemonsOnAccessPoints;", function() return settings.AllowAllDaemonsOnAccessPoints end)
    -- Progression
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionRequireAll;", function() return settings.ProgressionRequireAll end)
    -- Progression - Cyberdeck
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckBasicDevices;", function() return settings.ProgressionCyberdeckBasicDevices end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckCameras;", function() return settings.ProgressionCyberdeckCameras end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckTurrets;", function() return settings.ProgressionCyberdeckTurrets end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckNPCsCovert;", function() return settings.ProgressionCyberdeckNPCsCovert end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckNPCsCombat;", function() return settings.ProgressionCyberdeckNPCsCombat end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckNPCsControl;", function() return settings.ProgressionCyberdeckNPCsControl end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionCyberdeckNPCsUltimate;", function() return settings.ProgressionCyberdeckNPCsUltimate end)
    -- Progression - Intelligence
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceBasicDevices;", function() return settings.ProgressionIntelligenceBasicDevices end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceCameras;", function() return settings.ProgressionIntelligenceCameras end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceTurrets;", function() return settings.ProgressionIntelligenceTurrets end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceNPCsCovert;", function() return settings.ProgressionIntelligenceNPCsCovert end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceNPCsCombat;", function() return settings.ProgressionIntelligenceNPCsCombat end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceNPCsControl;", function() return settings.ProgressionIntelligenceNPCsControl end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionIntelligenceNPCsUltimate;", function() return settings.ProgressionIntelligenceNPCsUltimate end)
    -- Progression - Enemy Rarity
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionEnemyRarityNPCsCovert;", function() return settings.ProgressionEnemyRarityNPCsCovert end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionEnemyRarityNPCsCombat;", function() return settings.ProgressionEnemyRarityNPCsCombat end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionEnemyRarityNPCsControl;", function() return settings.ProgressionEnemyRarityNPCsControl end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionEnemyRarityNPCsUltimate;", function() return settings.ProgressionEnemyRarityNPCsUltimate end)
    -- Progression - Always Unlocked
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysBasicDevices;", function() return settings.AlwaysBasicDevices end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysCameras;", function() return settings.AlwaysCameras end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysTurrets;", function() return settings.AlwaysTurrets end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysNPCsCovert;", function() return settings.AlwaysNPCsCovert end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysNPCsCombat;", function() return settings.AlwaysNPCsCombat end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysNPCsControl;", function() return settings.AlwaysNPCsControl end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "AlwaysNPCsUltimate;", function() return settings.AlwaysNPCsUltimate end)
    -- Etc.
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "EnableDebugLog;", function() return settings.EnableDebugLog end)
end

return true