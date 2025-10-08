// -----------------------------------------------------------------------------
// RemoteBreach System
// -----------------------------------------------------------------------------
// Core infrastructure for RemoteBreach functionality.
//
// CONTENTS:
// - RemoteBreachStateSystem: Computer RemoteBreach state management
// - DeviceRemoteBreachStateSystem: Device RemoteBreach state management
// - VehicleRemoteBreachStateSystem: Vehicle RemoteBreach state management
// - DaemonTypes: Daemon type constants (Basic, NPC, Camera, Turret)
// - StateSystemUtils: Helper functions for accessing StateSystems
// -----------------------------------------------------------------------------

module BetterNetrunning.CustomHacking

import BetterNetrunning.*
import BetterNetrunningConfig.*
import BetterNetrunning.Common.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

// -----------------------------------------------------------------------------
// Base RemoteBreach Action with Dynamic RAM Cost Support
// -----------------------------------------------------------------------------

// Base class for all RemoteBreach actions with dynamic RAM cost calculation
@if(ModuleExists("HackingExtensions"))
public abstract class BaseRemoteBreachAction extends CustomAccessBreach {
    public let m_calculatedRAMCost: Int32; // Dynamic RAM cost

    // Override GetCost to return calculated RAM cost
    public func GetCost() -> Int32 {
        // Always return the calculated cost (or 0 if not set)
        return this.m_calculatedRAMCost;
    }

    // Override PayCost to consume RAM
    public func PayCost(opt checkForOverclockedState: Bool) -> Bool {
        if this.m_calculatedRAMCost <= 0 {
            return true; // No cost to pay
        }

        let executor: ref<GameObject> = this.GetExecutor();
        if !IsDefined(executor) {
            return false;
        }

        let statPoolSystem: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(executor.GetGame());
        let executorID: StatsObjectID = Cast<StatsObjectID>(executor.GetEntityID());
        let currentRAM: Float = statPoolSystem.GetStatPoolValue(executorID, gamedataStatPoolType.Memory, false);
        let costFloat: Float = Cast<Float>(this.m_calculatedRAMCost);

        // Check if player has enough RAM
        if currentRAM < costFloat {
            return false;
        }

        // Deduct RAM
        let newRAM: Float = currentRAM - costFloat;
        statPoolSystem.RequestSettingStatPoolValue(executorID, gamedataStatPoolType.Memory, newRAM, executor, false);

        return true;
    }

    // Override CanPayCost to check if player has enough RAM
    public func CanPayCost(opt user: ref<GameObject>, opt checkForOverclockedState: Bool) -> Bool {
        if this.m_calculatedRAMCost <= 0 {
            return true; // No cost required
        }

        let executor: ref<GameObject>;
        if IsDefined(user) {
            executor = user;
        } else {
            executor = this.GetExecutor();
        }

        if !IsDefined(executor) {
            return false;
        }

        let statPoolSystem: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(executor.GetGame());
        let executorID: StatsObjectID = Cast<StatsObjectID>(executor.GetEntityID());
        let currentRAM: Float = statPoolSystem.GetStatPoolValue(executorID, gamedataStatPoolType.Memory, false);

        return currentRAM >= Cast<Float>(this.m_calculatedRAMCost);
    }

    // Override IsPossible to lock action when insufficient RAM
    public func IsPossible(target: wref<GameObject>, opt actionRecord: wref<ObjectAction_Record>, opt objectActionsCallbackController: wref<gameObjectActionsCallbackController>) -> Bool {
        // First check base prerequisites
        if !super.IsPossible(target, actionRecord, objectActionsCallbackController) {
            return false;
        }

        // Then check if player has enough RAM
        return this.CanPayCost();
    }
}

// -----------------------------------------------------------------------------
// Global State Management Systems (ScriptableSystem Singleton Pattern)
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public class RemoteBreachStateSystem extends ScriptableSystem {
    // Store current computer being remotely breached (weak reference to avoid memory leaks)
    private let m_currentComputerPS: wref<ComputerControllerPS>;

    // Track breached computers
    private let m_breachedComputers: array<PersistentID>;

    // Store ComputerPS reference
    public func SetCurrentComputer(computerPS: wref<ComputerControllerPS>) -> Void {
        this.m_currentComputerPS = computerPS;
    }

    // Retrieve stored ComputerPS reference
    public func GetCurrentComputer() -> wref<ComputerControllerPS> {
        return this.m_currentComputerPS;
    }

    // Clear stored reference
    public func ClearCurrentComputer() -> Void {
        this.m_currentComputerPS = null;
    }

    // Mark computer as breached
    public func MarkComputerBreached(computerID: PersistentID) -> Void {
        if !ArrayContains(this.m_breachedComputers, computerID) {
            ArrayPush(this.m_breachedComputers, computerID);
        }
    }

    // Check if computer is already breached
    public func IsComputerBreached(computerID: PersistentID) -> Bool {
        return ArrayContains(this.m_breachedComputers, computerID);
    }
}

@if(ModuleExists("HackingExtensions"))
public class DeviceRemoteBreachStateSystem extends ScriptableSystem {
    private let m_currentDevicePS: wref<ScriptableDeviceComponentPS>;
    private let m_availableDaemons: String;
    private let m_breachedDevices: array<EntityID>;

    public func SetCurrentDevice(devicePS: ref<ScriptableDeviceComponentPS>, availableDaemons: String) -> Void {
        this.m_currentDevicePS = devicePS;
        this.m_availableDaemons = availableDaemons;
    }

    public func GetCurrentDevice() -> wref<ScriptableDeviceComponentPS> {
        return this.m_currentDevicePS;
    }

    public func GetAvailableDaemons() -> String {
        return this.m_availableDaemons;
    }

    public func ClearCurrentDevice() -> Void {
        this.m_currentDevicePS = null;
        this.m_availableDaemons = "";
    }

    // Track breached devices
    public func MarkDeviceBreached(deviceID: EntityID) -> Void {
        if !ArrayContains(this.m_breachedDevices, deviceID) {
            ArrayPush(this.m_breachedDevices, deviceID);
        }
    }

    public func IsDeviceBreached(deviceID: EntityID) -> Bool {
        return ArrayContains(this.m_breachedDevices, deviceID);
    }
}

@if(ModuleExists("HackingExtensions"))
public class VehicleRemoteBreachStateSystem extends ScriptableSystem {
    private let m_currentVehiclePS: wref<VehicleComponentPS>;
    private let m_availableDaemons: String;
    private let m_breachedVehicles: array<EntityID>;

    public func SetCurrentVehicle(vehiclePS: wref<VehicleComponentPS>, availableDaemons: String) -> Void {
        this.m_currentVehiclePS = vehiclePS;
        this.m_availableDaemons = availableDaemons;
    }

    public func GetCurrentVehicle() -> wref<VehicleComponentPS> {
        return this.m_currentVehiclePS;
    }

    public func GetAvailableDaemons() -> String {
        return this.m_availableDaemons;
    }

    public func ClearCurrentVehicle() -> Void {
        this.m_currentVehiclePS = null;
        this.m_availableDaemons = "";
    }

    public func MarkVehicleBreached(vehicleID: EntityID) -> Void {
        if !ArrayContains(this.m_breachedVehicles, vehicleID) {
            ArrayPush(this.m_breachedVehicles, vehicleID);
        }
    }

    public func IsVehicleBreached(vehicleID: EntityID) -> Bool {
        return ArrayContains(this.m_breachedVehicles, vehicleID);
    }
}

// -----------------------------------------------------------------------------
// Shared Utility Classes
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public abstract class DaemonTypes {
    public static func Basic() -> String { return "MinigameAction.UnlockQuickhacks"; }
    public static func NPC() -> String { return "MinigameAction.UnlockNPCQuickhacks"; }
    public static func Camera() -> String { return "MinigameAction.UnlockCameraQuickhacks"; }
    public static func Turret() -> String { return "MinigameAction.UnlockTurretQuickhacks"; }
}

@if(ModuleExists("HackingExtensions"))
public abstract class StateSystemUtils {
    public static func GetComputerStateSystem(gameInstance: GameInstance) -> ref<RemoteBreachStateSystem> {
        return GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"BetterNetrunning.CustomHacking.RemoteBreachStateSystem") as RemoteBreachStateSystem;
    }

    public static func GetDeviceStateSystem(gameInstance: GameInstance) -> ref<DeviceRemoteBreachStateSystem> {
        return GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"BetterNetrunning.CustomHacking.DeviceRemoteBreachStateSystem") as DeviceRemoteBreachStateSystem;
    }

    public static func GetVehicleStateSystem(gameInstance: GameInstance) -> ref<VehicleRemoteBreachStateSystem> {
        return GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"BetterNetrunning.CustomHacking.VehicleRemoteBreachStateSystem") as VehicleRemoteBreachStateSystem;
    }

    public static func GetCustomHackingSystem(gameInstance: GameInstance) -> ref<CustomHackingSystem> {
        return GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"HackingExtensions.CustomHackingSystem") as CustomHackingSystem;
    }
}

@if(ModuleExists("HackingExtensions"))
public abstract class ProgramIDUtils {
    public static func ApplyProgramToSharedPS(programID: TweakDBID, sharedPS: ref<SharedGameplayPS>) -> Void {
        if programID == t"MinigameAction.UnlockQuickhacks" {
            sharedPS.m_betterNetrunningBreachedBasic = true;
        } else if programID == t"MinigameAction.UnlockNPCQuickhacks" {
            sharedPS.m_betterNetrunningBreachedNPCs = true;
        } else if programID == t"MinigameAction.UnlockCameraQuickhacks" {
            sharedPS.m_betterNetrunningBreachedCameras = true;
        } else if programID == t"MinigameAction.UnlockTurretQuickhacks" {
            sharedPS.m_betterNetrunningBreachedTurrets = true;
        }
    }

    public static func IsAnyDaemonCompleted(sharedPS: ref<SharedGameplayPS>) -> Bool {
        return sharedPS.m_betterNetrunningBreachedBasic
            || sharedPS.m_betterNetrunningBreachedNPCs
            || sharedPS.m_betterNetrunningBreachedCameras
            || sharedPS.m_betterNetrunningBreachedTurrets;
    }

    public static func CreateBreachEventFromProgram(programID: TweakDBID) -> ref<SetBreachedSubnet> {
        let event: ref<SetBreachedSubnet> = new SetBreachedSubnet();

        if programID == t"MinigameAction.UnlockQuickhacks" {
            event.breachedBasic = true;
        } else if programID == t"MinigameAction.UnlockNPCQuickhacks" {
            event.breachedNPCs = true;
        } else if programID == t"MinigameAction.UnlockCameraQuickhacks" {
            event.breachedCameras = true;
        } else if programID == t"MinigameAction.UnlockTurretQuickhacks" {
            event.breachedTurrets = true;
        }

        return event;
    }
}

@if(ModuleExists("HackingExtensions"))
public abstract class RemoteBreachUtils {
    public static func RecordBreachPosition(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Void {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return;
        }

        let devicePos: Vector4 = deviceEntity.GetWorldPosition();
        RecordAccessPointBreachByPosition(devicePos, gameInstance);
    }

    public static func UnlockNPCsInRange(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Void {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return;
        }

        let devicePos: Vector4 = deviceEntity.GetWorldPosition();
        let breachRadius: Float = 50.0;

        let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
        if !IsDefined(player) {
            return;
        }

        let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);
        if !IsDefined(targetingSystem) {
            return;
        }

        let query: TargetSearchQuery;
        query.searchFilter = TSF_And(TSF_All(TSFMV.Obj_Puppet), TSF_Not(TSFMV.Obj_Player));
        query.testedSet = TargetingSet.Complete;
        query.maxDistance = breachRadius * 2.0;
        query.filterObjectByDistance = true;
        query.includeSecondaryTargets = false;
        query.ignoreInstigator = true;

        let parts: array<TS_TargetPartInfo>;
        targetingSystem.GetTargetParts(player, query, parts);

        let idx: Int32 = 0;
        while idx < ArraySize(parts) {
            let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(parts[idx]).GetEntity() as GameObject;

            if IsDefined(entity) {
                let puppet: ref<NPCPuppet> = entity as NPCPuppet;

                if IsDefined(puppet) {
                    let puppetPos: Vector4 = puppet.GetWorldPosition();
                    let distance: Float = Vector4.Distance(devicePos, puppetPos);

                    if distance <= breachRadius {
                        let npcPS: ref<ScriptedPuppetPS> = puppet.GetPS();
                        if IsDefined(npcPS) {
                            npcPS.m_quickHacksExposed = true;
                        }
                    }
                }
            }

            idx += 1;
        }
    }

    public static func UnlockDevicesInRadius(devicePS: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Void {
        let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return;
        }

        let devicePos: Vector4 = deviceEntity.GetWorldPosition();
        let breachRadius: Float = 50.0;

        let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
        if !IsDefined(player) {
            return;
        }

        let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);
        if !IsDefined(targetingSystem) {
            return;
        }

        let query: TargetSearchQuery;
        query.searchFilter = TSF_All(TSFMV.Obj_Device);
        query.testedSet = TargetingSet.Complete;
        query.maxDistance = breachRadius * 2.0;
        query.filterObjectByDistance = true;
        query.includeSecondaryTargets = false;
        query.ignoreInstigator = true;

        let parts: array<TS_TargetPartInfo>;
        targetingSystem.GetTargetParts(player, query, parts);

        let idx: Int32 = 0;
        while idx < ArraySize(parts) {
            let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(parts[idx]).GetEntity() as GameObject;

            if IsDefined(entity) {
                let device: ref<Device> = entity as Device;

                if IsDefined(device) {
                    let deviceComp: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();

                    if IsDefined(deviceComp) {
                        let entityPos: Vector4 = entity.GetWorldPosition();
                        let distance: Float = Vector4.Distance(devicePos, entityPos);

                        if distance <= breachRadius {
                            let sharedPS: ref<SharedGameplayPS> = deviceComp;
                            if IsDefined(sharedPS) {
                                let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
                                let isNetworkConnected: Bool = ArraySize(apControllers) > 0;

                                if !isNetworkConnected {
                                    if DaemonFilterUtils.IsCamera(deviceComp) {
                                        sharedPS.m_betterNetrunningBreachedCameras = true;
                                    } else if DaemonFilterUtils.IsTurret(deviceComp) {
                                        sharedPS.m_betterNetrunningBreachedTurrets = true;
                                    } else {
                                        sharedPS.m_betterNetrunningBreachedBasic = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            idx += 1;
        }
    }

    // Unlock nearby network-connected devices (shared logic for Device and Vehicle RemoteBreach)
    public static func UnlockNearbyNetworkDevices(sourceEntity: wref<GameObject>, gameInstance: GameInstance, unlockBasic: Bool, unlockNPCs: Bool, unlockCameras: Bool, unlockTurrets: Bool, logPrefix: String) -> Void {
        if !IsDefined(sourceEntity) {
            return;
        }

        let sourcePos: Vector4 = sourceEntity.GetWorldPosition();
        let searchRadius: Float = 50.0;

        let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
        if !IsDefined(player) {
            return;
        }

        let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);
        if !IsDefined(targetingSystem) {
            return;
        }

        let query: TargetSearchQuery;
        query.searchFilter = TSF_All(TSFMV.Obj_Device);
        query.testedSet = TargetingSet.Complete;
        query.maxDistance = searchRadius * 2.0;
        query.filterObjectByDistance = true;
        query.includeSecondaryTargets = false;
        query.ignoreInstigator = true;

        let parts: array<TS_TargetPartInfo>;
        targetingSystem.GetTargetParts(player, query, parts);

        let i: Int32 = 0;
        let networkDeviceCount: Int32 = 0;
        while i < ArraySize(parts) {
            let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(parts[i]).GetEntity() as GameObject;
            if IsDefined(entity) {
                let device: ref<Device> = entity as Device;
                if IsDefined(device) {
                    let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
                    if IsDefined(devicePS) {
                        let deviceSharedPS: ref<SharedGameplayPS> = devicePS as SharedGameplayPS;
                        if IsDefined(deviceSharedPS) {
                            // Check if device is network-connected (has access points)
                            let apControllers: array<ref<AccessPointControllerPS>> = deviceSharedPS.GetAccessPoints();
                            if ArraySize(apControllers) > 0 {
                                // This is a network-connected device
                                let devicePos: Vector4 = entity.GetWorldPosition();
                                let distance: Float = Vector4.Distance(sourcePos, devicePos);

                                if distance <= searchRadius {
                                    networkDeviceCount += 1;
                                    let deviceName: String = ToString(entity.GetClassName());

                                    // Unlock based on device type and daemon flags
                                    if IsDefined(devicePS as PuppetDeviceLinkPS) || IsDefined(devicePS as CommunityProxyPS) {
                                        if unlockNPCs {
                                            deviceSharedPS.m_betterNetrunningBreachedNPCs = true;
                                        }
                                    } else if DaemonFilterUtils.IsCamera(devicePS) {
                                        if unlockCameras {
                                            deviceSharedPS.m_betterNetrunningBreachedCameras = true;
                                        }
                                    } else if DaemonFilterUtils.IsTurret(devicePS) {
                                        if unlockTurrets {
                                            deviceSharedPS.m_betterNetrunningBreachedTurrets = true;
                                        }
                                    } else {
                                        if unlockBasic {
                                            deviceSharedPS.m_betterNetrunningBreachedBasic = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            i += 1;
        }
    }
}

@if(ModuleExists("HackingExtensions"))
public abstract class ComputerRemoteBreachUtils {
    public static func UnlockNetworkDevices(computerPS: ref<ComputerControllerPS>, unlockBasic: Bool, unlockNPCs: Bool, unlockCameras: Bool, unlockTurrets: Bool) -> Void {
        let sharedPS: ref<SharedGameplayPS> = computerPS;
        if !IsDefined(sharedPS) {
            return;
        }

        let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
        let isStandaloneComputer: Bool = ArraySize(apControllers) == 0;

        if isStandaloneComputer {
            return;
        }

        let setBreachedEvent: ref<SetBreachedSubnet> = new SetBreachedSubnet();
        setBreachedEvent.breachedBasic = unlockBasic;
        setBreachedEvent.breachedNPCs = unlockNPCs;
        setBreachedEvent.breachedCameras = unlockCameras;
        setBreachedEvent.breachedTurrets = unlockTurrets;

        let i: Int32 = 0;
        while i < ArraySize(apControllers) {
            let apPS: ref<AccessPointControllerPS> = apControllers[i];
            if IsDefined(apPS) {
                let devices: array<ref<DeviceComponentPS>>;
                apPS.GetChildren(devices);

                let j: Int32 = 0;
                while j < ArraySize(devices) {
                    let device: ref<DeviceComponentPS> = devices[j];

                    if IsDefined(device) {
                        apPS.QueuePSEvent(device, setBreachedEvent);

                        // Use DeviceTypeUtils for centralized device type detection
                        let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);
                        let shouldUnlock: Bool = false;

                        switch deviceType {
                            case DeviceType.NPC:
                                shouldUnlock = unlockNPCs;
                                break;
                            case DeviceType.Camera:
                                shouldUnlock = unlockCameras;
                                break;
                            case DeviceType.Turret:
                                shouldUnlock = unlockTurrets;
                                break;
                            case DeviceType.Basic:
                                shouldUnlock = unlockBasic;
                                break;
                        }

                        if shouldUnlock {
                            apPS.QueuePSEvent(device, apPS.ActionSetExposeQuickHacks());
                        }
                    }

                    j += 1;
                }
            }
            i += 1;
        }
    }
}

// -----------------------------------------------------------------------------
// Minigame Definition Helper - Target-specific minigame IDs
// -----------------------------------------------------------------------------
// Provides difficulty-based minigame IDs for Computer/Device/Vehicle targets
// Centralizes minigame selection logic for consistent behavior across modules
// -----------------------------------------------------------------------------

public abstract class MinigameIDHelper {
    // Get minigame ID based on target type and difficulty
    // Returns appropriate TweakDBID for Computer/Device/Vehicle RemoteBreach
    public static func GetMinigameID(targetType: MinigameTargetType, difficulty: GameplayDifficulty, opt devicePS: ref<ScriptableDeviceComponentPS>) -> TweakDBID {
        switch targetType {
            case MinigameTargetType.Computer:
                return MinigameIDHelper.GetComputerMinigameID(difficulty);
            case MinigameTargetType.Device:
                return MinigameIDHelper.GetDeviceMinigameID(difficulty, devicePS);
            case MinigameTargetType.Vehicle:
                return MinigameIDHelper.GetVehicleMinigameID(difficulty);
            default:
                BNLog("[CustomHacking] ERROR: Unknown target type, defaulting to Device Medium");
                return t"Minigame.DeviceRemoteBreachMedium";
        }
    }

    // Computer RemoteBreach: Basic + Camera daemons
    private static func GetComputerMinigameID(difficulty: GameplayDifficulty) -> TweakDBID {
        switch difficulty {
            case GameplayDifficulty.Easy:
                return t"Minigame.ComputerRemoteBreachEasy";
            case GameplayDifficulty.Hard:
                return t"Minigame.ComputerRemoteBreachHard";
            default:
                return t"Minigame.ComputerRemoteBreachMedium";
        }
    }

    // Device RemoteBreach: Device-type-specific daemons
    // Generic devices: Basic only
    // Camera devices: Basic + Camera
    // Turret devices: Basic + Turret
    private static func GetDeviceMinigameID(difficulty: GameplayDifficulty, devicePS: ref<ScriptableDeviceComponentPS>) -> TweakDBID {
        // Determine device type and select appropriate minigame
        let minigameBase: String;

        if DaemonFilterUtils.IsCamera(devicePS) {
            minigameBase = "CameraRemoteBreach";
            BNLog("[CustomHacking] Camera device detected, using CameraRemoteBreach minigame");
        } else if DaemonFilterUtils.IsTurret(devicePS) {
            minigameBase = "TurretRemoteBreach";
            BNLog("[CustomHacking] Turret device detected, using TurretRemoteBreach minigame");
        } else {
            minigameBase = "DeviceRemoteBreach";
            BNLog("[CustomHacking] Generic device detected, using DeviceRemoteBreach minigame");
        }

        // Select difficulty-specific variant
        switch difficulty {
            case GameplayDifficulty.Easy:
                return TDBID.Create("Minigame." + minigameBase + "Easy");
            case GameplayDifficulty.Hard:
                return TDBID.Create("Minigame." + minigameBase + "Hard");
            default:
                return TDBID.Create("Minigame." + minigameBase + "Medium");
        }
    }

    // Vehicle RemoteBreach: Basic daemon only
    private static func GetVehicleMinigameID(difficulty: GameplayDifficulty) -> TweakDBID {
        switch difficulty {
            case GameplayDifficulty.Easy:
                return t"Minigame.VehicleRemoteBreachEasy";
            case GameplayDifficulty.Hard:
                return t"Minigame.VehicleRemoteBreachHard";
            default:
                return t"Minigame.VehicleRemoteBreachMedium";
        }
    }
}

// Difficulty enum for minigame selection
enum GameplayDifficulty {
    Easy = 0,
    Medium = 1,
    Hard = 2
}

// Target type enum for minigame selection
enum MinigameTargetType {
    Computer = 0,
    Device = 1,
    Vehicle = 2
}

// -----------------------------------------------------------------------------
// RemoteBreach Action Helper - Common initialization logic
// -----------------------------------------------------------------------------
// Centralizes RemoteBreachAction setup to ensure consistent behavior
// across Computer/Device/Vehicle modules
// -----------------------------------------------------------------------------

public abstract class RemoteBreachActionHelper {
    // Initialize RemoteBreachAction with proper minigame ID and dynamic RAM cost
    // Note: Uses CustomAccessBreach base class to support RemoteBreachAction, DeviceRemoteBreachAction, VehicleRemoteBreachAction
    public static func Initialize(action: ref<CustomAccessBreach>, devicePS: ref<ScriptableDeviceComponentPS>, actionName: CName) -> Void {
        action.clearanceLevel = DefaultActionsParametersHolder.GetInteractiveClearance();
        action.SetUp(devicePS);
        action.AddDeviceName(devicePS.GetDeviceName());

        // CRITICAL: Set ObjectActionID before CreateInteraction()
        // This registers the action with the device system
        action.SetObjectActionID(t"DeviceAction.RemoteBreach");

        action.CreateInteraction();

        // Set action name for identification
        action.actionName = actionName;

        // Set dynamic RAM cost (1/3 of player's max RAM)
        RemoteBreachActionHelper.SetDynamicRAMCost(action, devicePS);
    }

    // Calculate and set RAM cost based on configurable percentage of player's maximum RAM
    private static func SetDynamicRAMCost(action: ref<CustomAccessBreach>, devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
        let player: ref<PlayerPuppet> = GetPlayer(devicePS.GetGameInstance());
        if !IsDefined(player) {
            BNLog("[CustomHacking] [SetDynamicRAMCost] ERROR: Player not found, using default cost");
            return;
        }

        let statPoolSystem: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(devicePS.GetGameInstance());
        if !IsDefined(statPoolSystem) {
            BNLog("[CustomHacking] [SetDynamicRAMCost] ERROR: StatPoolsSystem not found, using default cost");
            return;
        }

        let playerID: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());

        // Get current RAM and max RAM capacity
        let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(devicePS.GetGameInstance());

        let currentRAM: Float = statPoolSystem.GetStatPoolValue(playerID, gamedataStatPoolType.Memory, false);
        let maxRAMCap: Float = statsSystem.GetStatValue(playerID, gamedataStatType.Memory);

        // Get configured percentage from settings (default: 35%)
        let costPercent: Int32 = BetterNetrunningSettings.RemoteBreachRAMCostPercent();
        let ramCost: Float = maxRAMCap * (Cast<Float>(costPercent) / 100.0);

        // Round to nearest integer
        let roundedCost: Int32 = Cast<Int32>(ramCost + 0.5);

        // Ensure minimum cost of 1
        if roundedCost < 1 {
            roundedCost = 1;
        }

        // Store the calculated cost (works for all BaseRemoteBreachAction subclasses)
        let remoteBreachAction: ref<BaseRemoteBreachAction> = action as BaseRemoteBreachAction;
        if IsDefined(remoteBreachAction) {
            remoteBreachAction.m_calculatedRAMCost = roundedCost;
        } else {
            BNLog("[CustomHacking] [SetDynamicRAMCost] WARNING: Action is not a BaseRemoteBreachAction, cost not set");
        }
    }

    // Set minigame definition based on target type and difficulty
    public static func SetMinigameDefinition(action: ref<CustomAccessBreach>, targetType: MinigameTargetType, difficulty: GameplayDifficulty, devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
        let minigameID: TweakDBID = MinigameIDHelper.GetMinigameID(targetType, difficulty, devicePS);

        // Critical: Call SetProperties() to properly initialize CustomAccessBreach
        // This is required for the action to appear in quickhack menu
        action.SetProperties(
            devicePS.GetDeviceName(),  // networkName
            1,                         // npcCount
            0,                         // attemptsCount
            true,                      // isRemote
            false,                     // isSuicide
            minigameID,               // minigameDefinition
            devicePS                   // targetHack
        );

        // Note: CreateInteraction() is already called in Initialize()
        // Calling it again here might cause issues

        BNLog("[CustomHacking] RemoteBreachAction minigame set: " + TDBID.ToStringDEBUG(minigameID));
    }

    // Get current game difficulty (placeholder - expand if difficulty detection needed)
    public static func GetCurrentDifficulty() -> GameplayDifficulty {
        // TODO: Implement difficulty detection from game settings
        // For now, default to Medium
        return GameplayDifficulty.Medium;
    }

    // Remove TweakDB-defined RemoteBreach from action list
    public static func RemoveTweakDBRemoteBreach(actions: script_ref<array<ref<DeviceAction>>>, actionName: CName) -> Void {
        let actionsArray: array<ref<DeviceAction>> = Deref(actions);
        let i: Int32 = ArraySize(actionsArray) - 1;

        while i >= 0 {
            let action: ref<DeviceAction> = actionsArray[i];
            if IsDefined(action) && Equals(action.actionName, actionName) {
                ArrayErase(actionsArray, i);
                BNLog("[CustomHacking] Removed TweakDB RemoteBreach action");
            }
            i -= 1;
        }

        actions = actionsArray;
    }
}
