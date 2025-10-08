-- -----------------------------------------------------------------------------
-- Better Netrunning - Remote Breach TweakDB Setup
-- -----------------------------------------------------------------------------
-- Configures CustomHackingSystem minigame for remote breach
-- Requires: CustomHackingSystem v1.3.0+
-- -----------------------------------------------------------------------------

RemoteBreach = {}

function RemoteBreach.Setup()
    -- Check if CustomHackingSystem is available
    local CustomHackingSystem = GetMod("CustomHackingSystem")

    if not CustomHackingSystem then
        print("[BetterNetrunning] CustomHackingSystem not found - Remote Breach feature disabled")
        return false
    end

    print("[BetterNetrunning] Setting up Remote Breach minigame...")

    local api = CustomHackingSystem.API

    -- Create minigame category
    local betterNetrunningCategory = api.CreateHackingMinigameCategory("BetterNetrunning")

    -- Create program action type
    local remoteBreachRewardType = api.CreateProgramActionType("RemoteBreachRewards")

    -- Create UI elements
    -- =========================================================================
    -- Create Program Actions for Daemon Programs
    -- =========================================================================
    -- These Program Actions are used by the REDscript DeviceDaemonAction/VehicleDaemonAction
    -- to trigger gameplay when daemon programs are completed

    local daemonRewardType = api.CreateProgramActionType("RemoteBreachDaemonRewards")

    local daemonUIIcon = api.CreateUIIcon(
        "BreachProtocol",
        "base\\gameplay\\gui\\common\\icons\\quickhacks_icons.inkatlas"
    )

    -- Basic Daemon UI - Using BetterNetrunning's LocKey for consistency
    local unlockBasicUI = api.CreateProgramActionUI(
        "BN_UnlockBasicUI",
        LocKey("Better-Netrunning-Basic-Access-Name"),  -- Matches AccessPointBreach daemon
        LocKey("Better-Netrunning-Basic-Access-Description"),
        daemonUIIcon
    )

    -- NPC Daemon UI - Using BetterNetrunning's LocKey for consistency
    local unlockNPCUI = api.CreateProgramActionUI(
        "BN_UnlockNPCUI",
        LocKey("Better-Netrunning-NPC-Access-Name"),  -- Matches AccessPointBreach daemon
        LocKey("Better-Netrunning-NPC-Access-Description"),
        daemonUIIcon
    )

    -- Camera Daemon UI - Using BetterNetrunning's LocKey for consistency
    local unlockCameraUI = api.CreateProgramActionUI(
        "BN_UnlockCameraUI",
        LocKey("Better-Netrunning-Camera-Access-Name"),  -- Matches AccessPointBreach daemon
        LocKey("Better-Netrunning-Camera-Access-Description"),
        daemonUIIcon
    )

    -- Turret Daemon UI - Using BetterNetrunning's LocKey for consistency
    local unlockTurretUI = api.CreateProgramActionUI(
        "BN_UnlockTurretUI",
        LocKey("Better-Netrunning-Turret-Access-Name"),  -- Matches AccessPointBreach daemon
        LocKey("Better-Netrunning-Turret-Access-Description"),
        daemonUIIcon
    )

    -- Create Program Actions (these will be registered in REDscript with DeviceDaemonAction)
    local unlockBasicProgramAction = api.CreateProgramAction(
        "BN_RemoteBreach_UnlockBasic",
        daemonRewardType,
        betterNetrunningCategory,
        unlockBasicUI,
        0
    )
    print("[BetterNetrunning] Created ProgramAction: " .. unlockBasicProgramAction)

    local unlockNPCProgramAction = api.CreateProgramAction(
        "BN_RemoteBreach_UnlockNPC",
        daemonRewardType,
        betterNetrunningCategory,
        unlockNPCUI,
        10
    )
    print("[BetterNetrunning] Created ProgramAction: " .. unlockNPCProgramAction)

    local unlockCameraProgramAction = api.CreateProgramAction(
        "BN_RemoteBreach_UnlockCamera",
        daemonRewardType,
        betterNetrunningCategory,
        unlockCameraUI,
        5
    )

    local unlockTurretProgramAction = api.CreateProgramAction(
        "BN_RemoteBreach_UnlockTurret",
        daemonRewardType,
        betterNetrunningCategory,
        unlockTurretUI,
        15
    )

    -- Create daemon programs using the ProgramAction objects
    local unlockBasicProgram = api.CreateProgram(
        "BN_UnlockQuickhacks",
        unlockBasicProgramAction,  -- Pass the ProgramAction object, not a string
        4  -- buffer size
    )

    local unlockNPCProgram = api.CreateProgram(
        "BN_UnlockNPCQuickhacks",
        unlockNPCProgramAction,  -- Pass the ProgramAction object, not a string
        5  -- buffer size
    )

    local unlockCameraProgram = api.CreateProgram(
        "BN_UnlockCameraQuickhacks",
        unlockCameraProgramAction,  -- Pass the ProgramAction object, not a string
        4  -- buffer size
    )

    local unlockTurretProgram = api.CreateProgram(
        "BN_UnlockTurretQuickhacks",
        unlockTurretProgramAction,  -- Pass the ProgramAction object, not a string
        6  -- buffer size
    )

    print("[BetterNetrunning] Created daemon program actions and programs for RemoteBreach")

    -- =========================================================================
    -- Computer RemoteBreach Minigames (Basic + Camera Daemons)
    -- =========================================================================
    -- Computer devices have network access, supporting Basic and Camera daemons
    local computerMinigameEasy = api.CreateHackingMinigame(
        "ComputerRemoteBreachEasy",
        20.00,  -- timeLimit: 20 seconds
        5,      -- gridSize: 5x5
        -20,    -- extraDifficulty: easier
        7,      -- bufferSize
        {
            unlockBasicProgram,
            unlockCameraProgram
        },
        {}
    )

    local computerMinigameMedium = api.CreateHackingMinigame(
        "ComputerRemoteBreachMedium",
        25.00,  -- timeLimit: 25 seconds
        6,      -- gridSize: 6x6
        10,     -- extraDifficulty: moderate
        8,      -- bufferSize
        {
            unlockBasicProgram,
            unlockCameraProgram
        },
        {}
    )

    local computerMinigameHard = api.CreateHackingMinigame(
        "ComputerRemoteBreachHard",
        30.00,  -- timeLimit: 30 seconds
        7,      -- gridSize: 7x7
        30,     -- extraDifficulty: hard
        9,      -- bufferSize
        {
            unlockBasicProgram,
            unlockCameraProgram
        },
        {}
    )

    -- =========================================================================
    -- Generic Device RemoteBreach Minigames (Basic Daemon Only)
    -- =========================================================================
    -- Generic devices (doors, terminals, etc.) support only Basic daemon
    local deviceMinigameEasy = api.CreateHackingMinigame(
        "DeviceRemoteBreachEasy",
        20.00,
        5,
        -20,
        7,
        {
            unlockBasicProgram
        },
        {}
    )

    local deviceMinigameMedium = api.CreateHackingMinigame(
        "DeviceRemoteBreachMedium",
        25.00,
        6,
        10,
        8,
        {
            unlockBasicProgram
        },
        {}
    )

    local deviceMinigameHard = api.CreateHackingMinigame(
        "DeviceRemoteBreachHard",
        30.00,
        7,
        30,
        9,
        {
            unlockBasicProgram
        },
        {}
    )

    -- =========================================================================
    -- Camera RemoteBreach Minigames (Basic + Camera Daemons)
    -- =========================================================================
    -- Camera devices support Basic and Camera-specific daemons
    local cameraMinigameEasy = api.CreateHackingMinigame(
        "CameraRemoteBreachEasy",
        20.00,
        5,
        -20,
        7,
        {
            unlockBasicProgram,
            unlockCameraProgram
        },
        {}
    )

    local cameraMinigameMedium = api.CreateHackingMinigame(
        "CameraRemoteBreachMedium",
        25.00,
        6,
        10,
        8,
        {
            unlockBasicProgram,
            unlockCameraProgram
        },
        {}
    )

    local cameraMinigameHard = api.CreateHackingMinigame(
        "CameraRemoteBreachHard",
        30.00,
        7,
        30,
        9,
        {
            unlockBasicProgram,
            unlockCameraProgram
        },
        {}
    )

    -- =========================================================================
    -- Turret RemoteBreach Minigames (Basic + Turret Daemons)
    -- =========================================================================
    -- Turret devices support Basic and Turret-specific daemons
    local turretMinigameEasy = api.CreateHackingMinigame(
        "TurretRemoteBreachEasy",
        20.00,
        5,
        -20,
        7,
        {
            unlockBasicProgram,
            unlockTurretProgram
        },
        {}
    )

    local turretMinigameMedium = api.CreateHackingMinigame(
        "TurretRemoteBreachMedium",
        25.00,
        6,
        10,
        8,
        {
            unlockBasicProgram,
            unlockTurretProgram
        },
        {}
    )

    local turretMinigameHard = api.CreateHackingMinigame(
        "TurretRemoteBreachHard",
        30.00,
        7,
        30,
        9,
        {
            unlockBasicProgram,
            unlockTurretProgram
        },
        {}
    )

    -- =========================================================================
    -- Vehicle RemoteBreach Minigames (Basic Daemon Only)
    -- =========================================================================
    local vehicleMinigameEasy = api.CreateHackingMinigame(
        "VehicleRemoteBreachEasy",
        20.00,
        5,
        -20,
        7,
        {
            unlockBasicProgram
        },
        {}
    )

    local vehicleMinigameMedium = api.CreateHackingMinigame(
        "VehicleRemoteBreachMedium",
        25.00,
        6,
        10,
        8,
        {
            unlockBasicProgram
        },
        {}
    )

    local vehicleMinigameHard = api.CreateHackingMinigame(
        "VehicleRemoteBreachHard",
        30.00,
        7,
        30,
        9,
        {
            unlockBasicProgram
        },
        {}
    )

    -- =========================================================================
    -- CRITICAL: Register TweakDB entries to map REDscript TweakDBIDs to Lua minigames
    -- =========================================================================
    -- REDscript uses t"Minigame.ComputerRemoteBreachMedium" (TweakDBID)
    -- CustomHackingSystem uses "CustomHackingSystemMinigame.ComputerRemoteBreachMedium" (Lua minigame name)
    -- We need to clone TweakDB records to create aliases

    -- Computer minigames (Basic + Camera)
    TweakDB:CloneRecord("Minigame.ComputerRemoteBreachEasy", "CustomHackingSystemMinigame.ComputerRemoteBreachEasy")
    TweakDB:CloneRecord("Minigame.ComputerRemoteBreachMedium", "CustomHackingSystemMinigame.ComputerRemoteBreachMedium")
    TweakDB:CloneRecord("Minigame.ComputerRemoteBreachHard", "CustomHackingSystemMinigame.ComputerRemoteBreachHard")

    -- Generic Device minigames (Basic only)
    TweakDB:CloneRecord("Minigame.DeviceRemoteBreachEasy", "CustomHackingSystemMinigame.DeviceRemoteBreachEasy")
    TweakDB:CloneRecord("Minigame.DeviceRemoteBreachMedium", "CustomHackingSystemMinigame.DeviceRemoteBreachMedium")
    TweakDB:CloneRecord("Minigame.DeviceRemoteBreachHard", "CustomHackingSystemMinigame.DeviceRemoteBreachHard")

    -- Camera minigames (Basic + Camera)
    TweakDB:CloneRecord("Minigame.CameraRemoteBreachEasy", "CustomHackingSystemMinigame.CameraRemoteBreachEasy")
    TweakDB:CloneRecord("Minigame.CameraRemoteBreachMedium", "CustomHackingSystemMinigame.CameraRemoteBreachMedium")
    TweakDB:CloneRecord("Minigame.CameraRemoteBreachHard", "CustomHackingSystemMinigame.CameraRemoteBreachHard")

    -- Turret minigames (Basic + Turret)
    TweakDB:CloneRecord("Minigame.TurretRemoteBreachEasy", "CustomHackingSystemMinigame.TurretRemoteBreachEasy")
    TweakDB:CloneRecord("Minigame.TurretRemoteBreachMedium", "CustomHackingSystemMinigame.TurretRemoteBreachMedium")
    TweakDB:CloneRecord("Minigame.TurretRemoteBreachHard", "CustomHackingSystemMinigame.TurretRemoteBreachHard")

    -- Vehicle minigames (Basic only)
    TweakDB:CloneRecord("Minigame.VehicleRemoteBreachEasy", "CustomHackingSystemMinigame.VehicleRemoteBreachEasy")
    TweakDB:CloneRecord("Minigame.VehicleRemoteBreachMedium", "CustomHackingSystemMinigame.VehicleRemoteBreachMedium")
    TweakDB:CloneRecord("Minigame.VehicleRemoteBreachHard", "CustomHackingSystemMinigame.VehicleRemoteBreachHard")

    print("[BetterNetrunning] TweakDB entries created for minigame mapping (Minigame.* → CustomHackingSystemMinigame.*)")

    print("[BetterNetrunning] Remote Breach minigame setup complete (Phase 6 - Device-type-specific)")
    print("  - Category: " .. betterNetrunningCategory)
    print("  - Computer Minigames: Easy/Medium/Hard (Basic + Camera)")
    print("  - Generic Device Minigames: Easy/Medium/Hard (Basic only)")
    print("  - Camera Minigames: Easy/Medium/Hard (Basic + Camera)")
    print("  - Turret Minigames: Easy/Medium/Hard (Basic + Turret)")
    print("  - Vehicle Minigames: Easy/Medium/Hard (Basic only)")
    print("  - Computer Easy: " .. computerMinigameEasy)
    print("  - Device Easy: " .. deviceMinigameEasy)
    print("  - Camera Easy: " .. cameraMinigameEasy)
    print("  - Turret Easy: " .. turretMinigameEasy)
    print("  - Vehicle Easy: " .. vehicleMinigameEasy)


    return true
end

return RemoteBreach

