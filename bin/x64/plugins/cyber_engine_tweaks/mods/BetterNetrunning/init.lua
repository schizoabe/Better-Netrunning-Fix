local settings = {
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
    -- Controls
    BreachUnconsciousActionChoice = 3, -- 1..4 maps to Choice1..Choice4
    -- Access Points
    UnlockIfNoAccessPoint = true,
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
    -- 1: Disabled, 2: Trash, 3: Weak, 4: Normal, 5: Rare, 6: Officer, 7: Elite, 8: Boss, 9: MaxTac
    ProgressionEnemyRarityNPCsCovert = 1,
    ProgressionEnemyRarityNPCsCombat = 1,
    ProgressionEnemyRarityNPCsControl = 1,
    ProgressionEnemyRarityNPCsUltimate = 1,
    -- Progression - Always Unlocked
    ProgressionAlwaysBasicDevices = false,
    ProgressionAlwaysCameras = false,
    ProgressionAlwaysTurrets = false,
    ProgressionAlwaysNPCsCovert = false,
    ProgressionAlwaysNPCsCombat = false,
    ProgressionAlwaysNPCsControl = false,
    ProgressionAlwaysNPCsUltimate = false
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

    ApplyBreachUnconsciousActionChoice()
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

    nativeSettings.addSubcategory("/BetterNetrunning/Breaching", "Breaching")
    nativeSettings.addSubcategory("/BetterNetrunning/AccessPoints", "Access Points")
    nativeSettings.addSubcategory("/BetterNetrunning/Controls", "Controls")
    nativeSettings.addSubcategory("/BetterNetrunning/RemovedQuickhacks", "Removed Quickhacks")
    nativeSettings.addSubcategory("/BetterNetrunning/UnlockedQuickhacks", "Always Unlocked Quickhacks")
    nativeSettings.addSubcategory("/BetterNetrunning/Progression", "Progression")
    nativeSettings.addSubcategory("/BetterNetrunning/ProgressionCyberdeck", "Progression - Cyberdeck Quality")
    nativeSettings.addSubcategory("/BetterNetrunning/ProgressionIntelligence", "Progression - Intelligence")
    nativeSettings.addSubcategory("/BetterNetrunning/ProgressionEnemyRarity", "Progression - Enemy Rarity")

    -- Breaching
    nativeSettings.addSwitch("/BetterNetrunning/Breaching", "Enable Classic Mode", "If true, the entire network can be breached by uploading any daemon. This disables the subnet system, along with the corresponding breach daemons.", settings.EnableClassicMode, false, function(state)
        settings.EnableClassicMode = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/Breaching", "Allow Breaching Unconscious NPCs", "If true, you can perform a network breach on any unconscious NPC connected to a network.", settings.AllowBreachUnconscious, true, function(state)
        settings.AllowBreachUnconscious = state
        SaveSettings()
    end)

    -- Controls
    local breachActionChoices = {[1] = "Choice1", [2] = "Choice2", [3] = "Choice3", [4] = "Choice4"}
    nativeSettings.addSelectorString("/BetterNetrunning/Controls", "Unconscious Breach Action", "Select which Interaction Choice triggers the Unconscious Breach. The game maps Choice1 - 4 to the correct key/button for keyboard and gamepad.",
        breachActionChoices, settings.BreachUnconsciousActionChoice, 3,
        function(state)
            settings.BreachUnconsciousActionChoice = state
            ApplyBreachUnconsciousActionChoice()
            SaveSettings()
        end
    )

    -- Access Points
    nativeSettings.addSwitch("/BetterNetrunning/AccessPoints", "Unlock Networks With No Access Points", "If true, all quickhacks are automatically allowed if there are no access points on the network.", settings.UnlockIfNoAccessPoint, true, function(state)
        settings.UnlockIfNoAccessPoint = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/AccessPoints", "Disable Datamine V1 and V2", "If true, the Datamine V1 and V2 daemons will not appear while breaching access points (only V3 will remain). This helps to reduce clutter from having too many daemons listed, however it also reduces the amount of eddies and quickhack components you can get from each access point.", settings.DisableDatamineOneTwo, false, function(state)
        settings.DisableDatamineOneTwo = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/AccessPoints", "Allow All Daemons on Access Points", "If true, all daemons can be uploaded on access points, rather than only Datamine. Very buggy, enable at your own risk.", settings.AllowAllDaemonsOnAccessPoints, false, function(state)
        settings.AllowAllDaemonsOnAccessPoints = state
        SaveSettings()
    end)

    -- Removed Quickhacks
    nativeSettings.addSwitch("/BetterNetrunning/RemovedQuickhacks", "Remove Camera Disable Quickhack", "If true, the enable/disable quickhack will NOT be available on cameras.", settings.BlockCameraDisable, false, function(state)
        settings.BlockCameraDisable = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/RemovedQuickhacks", "Remove Turret Disable Quickhack", "If true, the enable/disable quickhack will NOT be available on turrets.", settings.BlockTurretDisable, false, function(state)
        settings.BlockTurretDisable = state
        SaveSettings()
    end)

    -- Always Unlocked Quickhacks
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", "Ping", "If true, the Ping quickhack is always available on unbreached networks.", settings.AlwaysAllowPing, true, function(state)
        settings.AlwaysAllowPing = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", "Whistle", "If true, the Whistle quickhack is always available on unbreached networks.", settings.AlwaysAllowWhistle, false, function(state)
        settings.AlwaysAllowWhistle = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", "Distract Enemies", "If true, the Distract Enemies quickhack is always available on unbreached networks.", settings.AlwaysAllowDistract, false, function(state)
        settings.AlwaysAllowDistract = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", "Basic Devices", "If true, basic device quickhacks are always available on unbreached networks.", settings.ProgressionAlwaysBasicDevices, false, function(state)
        settings.ProgressionAlwaysBasicDevices = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", "Cameras", "If true, camera quickhacks are always available on unbreached networks.", settings.ProgressionAlwaysCameras, false, function(state)
        settings.ProgressionAlwaysCameras = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", "Turrets", "If true, turret quickhacks are always available on unbreached networks.", settings.ProgressionAlwaysTurrets, false, function(state)
        settings.ProgressionAlwaysTurrets = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", "NPCs - Covert", "If true, covert NPC quickhacks are always available on unbreached networks.", settings.ProgressionAlwaysNPCsCovert, false, function(state)
        settings.ProgressionAlwaysNPCsCovert = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", "NPCs - Combat", "If true, combat NPC quickhacks are always available on unbreached networks.", settings.ProgressionAlwaysNPCsCombat, false, function(state)
        settings.ProgressionAlwaysNPCsCombat = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", "NPCs - Control", "If true, control NPC quickhacks are always available on unbreached networks.", settings.ProgressionAlwaysNPCsControl, false, function(state)
        settings.ProgressionAlwaysNPCsControl = state
        SaveSettings()
    end)
    nativeSettings.addSwitch("/BetterNetrunning/UnlockedQuickhacks", "NPCs - Ultimate", "If true, ultimate NPC quickhacks are always available on unbreached networks.", settings.ProgressionAlwaysNPCsUltimate, false, function(state)
        settings.ProgressionAlwaysNPCsUltimate = state
        SaveSettings()
    end)

    -- Progression
    nativeSettings.addSwitch("/BetterNetrunning/Progression", "Require All", "If true, all progression categories (that are not disabled) must be met to unlock a type of hack. If false, at least one must be met.", settings.ProgressionRequireAll, true, function(state)
        settings.ProgressionRequireAll = state
        SaveSettings()
    end)

    -- Progression - Cyberdeck
    local cyberdeckQualityOptions = {[1] = "Disabled", [2] = "Tier 1+", [3] = "Tier 2", [4] = "Tier 2+", [5] = "Tier 3", [6] = "Tier 3+", [7] = "Tier 4", [8] = "Tier 4+", [9] = "Tier 5", [10] = "Tier 5+", [11] = "Tier 5++"}
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", "Basic Devices", "Minimum cyberdeck quality to access quickhacks on basic devices (no cameras or turrets).", cyberdeckQualityOptions, settings.ProgressionCyberdeckBasicDevices, 1, function(state)
        settings.ProgressionCyberdeckBasicDevices = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", "Cameras", "Minimum cyberdeck quality to access quickhacks on cameras.", cyberdeckQualityOptions, settings.ProgressionCyberdeckCameras, 1, function(state)
        settings.ProgressionCyberdeckCameras = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", "Turrets", "Minimum cyberdeck quality to access quickhacks on turrets.", cyberdeckQualityOptions, settings.ProgressionCyberdeckTurrets, 1, function(state)
        settings.ProgressionCyberdeckTurrets = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", "NPCs - Covert", "Minimum cyberdeck quality to access covert quickhacks on NPCs.", cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsCovert, 1, function(state)
        settings.ProgressionCyberdeckNPCsCovert = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", "NPCs - Combat", "Minimum cyberdeck quality to access combat quickhacks on NPCs.", cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsCombat, 1, function(state)
        settings.ProgressionCyberdeckNPCsCombat = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", "NPCs - Control", "Minimum cyberdeck quality to access control quickhacks on NPCs.", cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsControl, 1, function(state)
        settings.ProgressionCyberdeckNPCsControl = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionCyberdeck", "NPCs - Ultimate", "Minimum cyberdeck quality to access ultimate quickhacks on NPCs.", cyberdeckQualityOptions, settings.ProgressionCyberdeckNPCsUltimate, 1, function(state)
        settings.ProgressionCyberdeckNPCsUltimate = state
        SaveSettings()
    end)

    -- Progression - Intelligence
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", "Basic Devices", "Minimum intelligence to access quickhacks on basic devices (no cameras or turrets). (3 = Disabled)", 3, 20, 1, settings.ProgressionIntelligenceBasicDevices, 3, function(state)
        settings.ProgressionIntelligenceBasicDevices = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", "Cameras", "Minimum intelligence to access quickhacks on cameras. (3 = Disabled)", 3, 20, 1, settings.ProgressionIntelligenceCameras, 3, function(state)
        settings.ProgressionIntelligenceCameras = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", "Turrets", "Minimum intelligence to access quickhacks on turrets. (3 = Disabled)", 3, 20, 1, settings.ProgressionIntelligenceTurrets, 3, function(state)
        settings.ProgressionIntelligenceTurrets = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", "NPCs - Covert", "Minimum intelligence to access covert quickhacks on NPCs. (3 = Disabled)", 3, 20, 1, settings.ProgressionIntelligenceNPCsCovert, 3, function(state)
        settings.ProgressionIntelligenceNPCsCovert = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", "NPCs - Combat", "Minimum intelligence to access combat quickhacks on NPCs. (3 = Disabled)", 3, 20, 1, settings.ProgressionIntelligenceNPCsCombat, 3, function(state)
        settings.ProgressionIntelligenceNPCsCombat = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", "NPCs - Control", "Minimum intelligence to access control quickhacks on NPCs. (3 = Disabled)", 3, 20, 1, settings.ProgressionIntelligenceNPCsControl, 3, function(state)
        settings.ProgressionIntelligenceNPCsControl = state
        SaveSettings()
    end)
    nativeSettings.addRangeInt("/BetterNetrunning/ProgressionIntelligence", "NPCs - Ultimate", "Minimum intelligence to access ultimate quickhacks on NPCs. (3 = Disabled)", 3, 20, 1, settings.ProgressionIntelligenceNPCsUltimate, 3, function(state)
        settings.ProgressionIntelligenceNPCsUltimate = state
        SaveSettings()
    end)

    -- Progression - Enemy Rarity
    local enemyRarityOptions = {[1] = "Disabled", [2] = "Trash", [3] = "Weak", [4] = "Normal", [5] = "Rare", [6] = "Officer", [7] = "Elite", [8] = "Boss", [9] = "MaxTac"}
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", "NPCs - Covert", "Unlock quickhacks for enemies at or below this rarity (inclusive).", enemyRarityOptions, settings.ProgressionEnemyRarityNPCsCovert, 1, function(state)
        settings.ProgressionEnemyRarityNPCsCovert = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", "NPCs - Combat", "Unlock quickhacks for enemies at or below this rarity (inclusive).", enemyRarityOptions, settings.ProgressionEnemyRarityNPCsCombat, 1, function(state)
        settings.ProgressionEnemyRarityNPCsCombat = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", "NPCs - Control", "Unlock quickhacks for enemies at or below this rarity (inclusive).", enemyRarityOptions, settings.ProgressionEnemyRarityNPCsControl, 1, function(state)
        settings.ProgressionEnemyRarityNPCsControl = state
        SaveSettings()
    end)
    nativeSettings.addSelectorString("/BetterNetrunning/ProgressionEnemyRarity", "NPCs - Ultimate", "Unlock quickhacks for enemies at or below this rarity (inclusive).", enemyRarityOptions, settings.ProgressionEnemyRarityNPCsUltimate, 1, function(state)
        settings.ProgressionEnemyRarityNPCsUltimate = state
        SaveSettings()
    end)
end

function ApplyBreachUnconsciousActionChoice()
    local map = {[1] = "Choice1", [2] = "Choice2", [3] = "Choice3", [4] = "Choice4"}
    local idx = settings.BreachUnconsciousActionChoice or 3
    if map[idx] == nil then idx = 3 end
    TweakDB:SetFlat("Interactions.BreachUnconsciousOfficer.action", map[idx])
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
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionAlwaysBasicDevices;", function() return settings.ProgressionAlwaysBasicDevices end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionAlwaysCameras;", function() return settings.ProgressionAlwaysCameras end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionAlwaysTurrets;", function() return settings.ProgressionAlwaysTurrets end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionAlwaysNPCsCovert;", function() return settings.ProgressionAlwaysNPCsCovert end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionAlwaysNPCsCombat;", function() return settings.ProgressionAlwaysNPCsCombat end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionAlwaysNPCsControl;", function() return settings.ProgressionAlwaysNPCsControl end)
    Override("BetterNetrunningConfig.BetterNetrunningSettings", "ProgressionAlwaysNPCsUltimate;", function() return settings.ProgressionAlwaysNPCsUltimate end)
end

return true