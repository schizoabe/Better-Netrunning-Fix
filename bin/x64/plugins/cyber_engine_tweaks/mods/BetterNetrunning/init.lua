-- -----------------------------------------------------------------------------
-- Better Netrunning - Main Entry Point
-- -----------------------------------------------------------------------------
-- Handles: Module loading and initialization
-- -----------------------------------------------------------------------------

-- Load modules
local SettingsManager = require("settingsManager")
local TweakDBSetup = require("tweakdbSetup")
local NativeSettingsUI = require("nativeSettingsUI")
local RemoteBreach = require("remoteBreach")

-- Initialize MOD
registerForEvent("onInit", function()
    print("[Better Netrunning] Initializing...")

    -- Load settings from file
    SettingsManager.Load()

    -- Setup NativeSettings UI
    local nativeSettings = GetMod("nativeSettings")
    if nativeSettings then
        NativeSettingsUI.Build(nativeSettings, SettingsManager, TweakDBSetup)
        SettingsManager.OverrideConfigFunctions()
    else
        print("[Better Netrunning] NativeSettings not found")
    end

    -- Configure TweakDB
    TweakDBSetup.SetupAccessPrograms()
    TweakDBSetup.SetupUnconsciousBreach()
    TweakDBSetup.ApplyBreachingHotkey(SettingsManager.Get("BreachingHotkey"))

    -- Setup Remote Breach feature
    if RemoteBreach and RemoteBreach.Setup then
        local success = RemoteBreach.Setup()
        if success then
            print("[Better Netrunning] Remote Breach enabled")
        end
    end
    print("[Better Netrunning] Initialization complete")
end)

return true