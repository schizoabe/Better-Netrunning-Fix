-- -----------------------------------------------------------------------------
-- Better Netrunning - TweakDB Setup
-- -----------------------------------------------------------------------------
-- Handles: TweakDB configuration for Access Programs and Breach Actions
-- -----------------------------------------------------------------------------

local TweakDBSetup = {}

-- Setup Access Programs (4 programs)
function TweakDBSetup.SetupAccessPrograms()
    TweakDBSetup.CreateAccessProgram(
        "NetworkBasicAccess",
        "UnlockQuickhacks",
        LocKey("Better-Netrunning-Basic-Access-Name"),
        LocKey("Better-Netrunning-Basic-Access-Description"),
        "ChoiceCaptionParts.BreachProtocolIcon",
        20.0
    )

    TweakDBSetup.CreateAccessProgram(
        "NetworkNPCAccess",
        "UnlockNPCQuickhacks",
        LocKey("Better-Netrunning-NPC-Access-Name"),
        LocKey("Better-Netrunning-NPC-Access-Description"),
        "ChoiceCaptionParts.PingIcon",
        60.0
    )

    TweakDBSetup.CreateAccessProgram(
        "NetworkCameraAccess",
        "UnlockCameraQuickhacks",
        LocKey("Better-Netrunning-Camera-Access-Name"),
        LocKey("Better-Netrunning-Camera-Access-Description"),
        "ChoiceCaptionParts.CameraShutdownIcon",
        40.0
    )

    TweakDBSetup.CreateAccessProgram(
        "NetworkTurretAccess",
        "UnlockTurretQuickhacks",
        LocKey("Better-Netrunning-Turret-Access-Name"),
        LocKey("Better-Netrunning-Turret-Access-Description"),
        "ChoiceCaptionParts.TurretShutdownIcon",
        70.0
    )

    print("[Better Netrunning] Access Programs configured")
end

-- Create Access Program (TweakDB operation)
function TweakDBSetup.CreateAccessProgram(interactionName, actionName, caption, description, icon, complexity)
    -- Configure Interaction
    TweakDB:CloneRecord("Interactions."..interactionName, "Interactions.NetworkGainAccessProgram")
    TweakDB:SetFlat("Interactions."..interactionName..".caption", caption)
    TweakDB:SetFlat("Interactions."..interactionName..".captionIcon", icon)
    TweakDB:SetFlat("Interactions."..interactionName..".description", description)

    -- Configure MinigameAction
    TweakDB:CloneRecord("MinigameAction."..actionName, "MinigameAction.NetworkLowerICEMajor")
    TweakDB:SetFlat("MinigameAction."..actionName..".objectActionType", "ObjectActionType.MinigameUpload")
    TweakDB:SetFlat("MinigameAction."..actionName..".objectActionUI", "Interactions."..interactionName)
    TweakDB:SetFlat("MinigameAction."..actionName..".completionEffects", {})
    TweakDB:SetFlat("MinigameAction."..actionName..".complexity", complexity)
    TweakDB:SetFlat("MinigameAction."..actionName..".type", "MinigameAction.Both")
end

-- Setup Unconscious NPC Breach
function TweakDBSetup.SetupUnconsciousBreach()
    TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.instigatorPrereqs", {
        "QuickHack.RemoteBreach_inline0",
        "QuickHack.QuickHack_inline3",
        "Takedown.GeneralStateChecks",
        "Takedown.IsPlayerInExploration",
        "Takedown.IsPlayerInAcceptableGroundLocomotionState",
        "Takedown.PlayerNotInSafeZone",
        "Takedown.GameplayRestrictions",
        "Takedown.BreachUnconsciousOfficer_inline0",
        "Takedown.BreachUnconsciousOfficer_inline1",
        "Takedown.BreachUnconsciousOfficer_inline2"
    })

    TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.targetActivePrereqs", {
        "Prereqs.QuickHackUploadingPrereq",
        "Prereqs.ConnectedToBackdoorActive"
    })

    TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.targetPrereqs", {
        "Takedown.BreachUnconsciousOfficer_inline4"
    })

    TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.startEffects", {
        "QuickHack.QuickHack_inline12",
        "QuickHack.QuickHack_inline13"
    })

    TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.completionEffects", {
        "QuickHack.QuickHack_inline4",
        "QuickHack.QuickHack_inline8",
        "QuickHack.QuickHack_inline10",
        "QuickHack.QuickHack_inline11"
    })

    TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.actionName", "RemoteBreach")
    TweakDB:SetFlat("Takedown.BreachUnconsciousOfficer.activationTime", {})

    print("[Better Netrunning] Unconscious Breach configured")
end

-- Apply Breaching Hotkey
function TweakDBSetup.ApplyBreachingHotkey(hotkey)
    local map = {[1] = "Choice1", [2] = "Choice2", [3] = "Choice3", [4] = "Choice4"}
    local idx = hotkey or 3
    if map[idx] == nil then
        idx = 3
    end
    TweakDB:SetFlat("Interactions.BreachUnconsciousOfficer.action", map[idx])
end

return TweakDBSetup
