// -----------------------------------------------------------------------------
// RemoteBreach Daemon Implementation
// -----------------------------------------------------------------------------
// Implements daemon action classes (DeviceDaemonAction, VehicleDaemonAction)
// and their execution logic for RemoteBreach minigames.
//
// RESPONSIBILITIES:
// - Define DeviceDaemonAction class (Computer + Generic Device + Vehicle handling)
// - Define VehicleDaemonAction class (Vehicle-specific handling)
// - Implement ExecuteProgramSuccess() for each daemon type
// - Update device unlock state and StateSystem tracking
// - Trigger network unlock cascades
//
// DAEMON EXECUTION FLOW:
// 1. Player completes daemon in RemoteBreach minigame
// 2. ExecuteProgramSuccess() called
// 3. Detect target type (Computer/Device/Vehicle)
// 4. Apply daemon effects (set flags, unlock network)
// 5. Mark device as breached in StateSystem
//
// NOTE: Daemon registration is in DaemonRegistration.reds
// -----------------------------------------------------------------------------

module BetterNetrunning.CustomHacking

import BetterNetrunning.*
import BetterNetrunning.Common.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

// -----------------------------------------------------------------------------
// Device Daemon Program Actions (Computer + Generic Devices)
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions.Programs"))
public class DeviceDaemonAction extends HackProgramAction {
    private let m_daemonTypeStr: String;

    public func SetDaemonType(daemonTypeStr: String) -> Void {
        this.m_daemonTypeStr = daemonTypeStr;
    }

    // ==================== Template Method Pattern ====================
    // Unified daemon execution flow - eliminates duplicate code in 3 Process* methods

    protected func ExecuteProgramSuccess() -> Void {
        let player: ref<PlayerPuppet> = this.GetPlayer();
        if !IsDefined(player) {
            BNLog("[DeviceDaemonAction] ERROR: Player not defined");
            return;
        }

        let gameInstance: GameInstance = player.GetGame();
        BNLog("[DeviceDaemonAction] Daemon execution started: " + this.m_daemonTypeStr);

        // Try each target type in priority order: Computer -> Device -> Vehicle
        let computerPS: wref<ComputerControllerPS> = this.GetComputerFromStateSystem(gameInstance);
        if IsDefined(computerPS) {
            BNLog("[DeviceDaemonAction] Target: Computer");
            this.ProcessDaemonWithStrategy(computerPS, gameInstance, ComputerUnlockStrategy.Create());
            return;
        }

        let devicePS: wref<ScriptableDeviceComponentPS> = this.GetDeviceFromStateSystem(gameInstance);
        if IsDefined(devicePS) {
            let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(devicePS);
            BNLog("[DeviceDaemonAction] Target: Device (type=" + ToString(EnumInt(deviceType)) + ")");
            this.ProcessDaemonWithStrategy(devicePS, gameInstance, DeviceUnlockStrategy.Create());
            return;
        }

        let vehiclePS: wref<VehicleComponentPS> = this.GetVehicleFromStateSystem(gameInstance);
        if IsDefined(vehiclePS) {
            BNLog("[DeviceDaemonAction] Target: Vehicle");
            this.ProcessDaemonWithStrategy(vehiclePS, gameInstance, VehicleUnlockStrategy.Create());
            return;
        }

        BNLog("[DeviceDaemonAction] ERROR: No valid target found");
    }

    // ==================== Template Method Core ====================
    // Replaces ProcessComputerDaemon(), ProcessDeviceDaemon(), ProcessVehicleDaemon()
    // Reduces 200+ lines to 30 lines via Strategy Pattern

    private func ProcessDaemonWithStrategy(
        sourcePS: ref<DeviceComponentPS>,
        gameInstance: GameInstance,
        strategy: ref<IDaemonUnlockStrategy>
    ) -> Void {
        BNLog("[ProcessDaemonWithStrategy] Executing unlock strategy");

        // Step 1: Get SharedGameplayPS for breach flag management
        let sharedPS: ref<SharedGameplayPS> = sourcePS as SharedGameplayPS;
        if !IsDefined(sharedPS) {
            BNLog("[ProcessDaemonWithStrategy] ERROR: Cannot cast to SharedGameplayPS");
            return;
        }

        // Step 2: Determine device type for flag selection
        let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(sourcePS);

        // Step 3: Set breach flag for this daemon's device type
        DeviceTypeUtils.SetBreached(deviceType, sharedPS, true);
        BNLog("[ProcessDaemonWithStrategy] Breach flag set for device type: " + ToString(EnumInt(deviceType)));

        // Step 4: Mark device as breached in StateSystem (for persistence)
        let stateSystem: ref<IScriptable> = strategy.GetStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            strategy.MarkBreached(stateSystem, sourcePS.GetID(), gameInstance);
        }

        // Step 5: Execute unlock logic (varies by target type - delegated to Strategy)
        strategy.ExecuteUnlock(this.m_daemonTypeStr, deviceType, sourcePS, gameInstance);
        BNLog("[ProcessDaemonWithStrategy] Unlock completed");
    }

    // ==================== StateSystem Accessors ====================

    private func GetComputerFromStateSystem(gameInstance: GameInstance) -> wref<ComputerControllerPS> {
        let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            return stateSystem.GetCurrentComputer();
        }
        return null;
    }

    private func GetDeviceFromStateSystem(gameInstance: GameInstance) -> wref<ScriptableDeviceComponentPS> {
        let stateSystem: ref<DeviceRemoteBreachStateSystem> = StateSystemUtils.GetDeviceStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            return stateSystem.GetCurrentDevice();
        }
        return null;
    }

    private func GetVehicleFromStateSystem(gameInstance: GameInstance) -> wref<VehicleComponentPS> {
        let stateSystem: ref<VehicleRemoteBreachStateSystem> = StateSystemUtils.GetVehicleStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            return stateSystem.GetCurrentVehicle();
        }
        return null;
    }

    // ==================== Failure Handler ====================

    protected func ExecuteProgramFailure() -> Void {
        // Silent failure - StateSystem remains for potential retry
    }
}

@if(ModuleExists("HackingExtensions.Programs"))
public class BetterNetrunningDaemonAction extends DeviceDaemonAction {}

// -----------------------------------------------------------------------------
// Vehicle Daemon Program Actions
// -----------------------------------------------------------------------------
// NOTE: VehicleDaemonAction uses the SAME Strategy Pattern as DeviceDaemonAction
// The only difference is ExecuteProgramSuccess() retrieves VehiclePS from VehicleStateSystem
// All unlock logic is delegated to VehicleUnlockStrategy

@if(ModuleExists("HackingExtensions.Programs"))
public class VehicleDaemonAction extends HackProgramAction {
    private let m_daemonTypeStr: String;

    public func SetDaemonType(daemonTypeStr: String) -> Void {
        this.m_daemonTypeStr = daemonTypeStr;
    }

    protected func ExecuteProgramSuccess() -> Void {
        let player: ref<PlayerPuppet> = this.GetPlayer();
        if !IsDefined(player) {
            BNLog("[VehicleDaemonAction] ERROR: Player not defined");
            return;
        }

        let gameInstance: GameInstance = player.GetGame();
        BNLog("[VehicleDaemonAction] Daemon execution started: " + this.m_daemonTypeStr);

        let stateSystem: ref<VehicleRemoteBreachStateSystem> = StateSystemUtils.GetVehicleStateSystem(gameInstance);

        if !IsDefined(stateSystem) {
            BNLog("[VehicleDaemonAction] ERROR: VehicleStateSystem not found");
            return;
        }

        let vehiclePS: wref<VehicleComponentPS> = stateSystem.GetCurrentVehicle();
        if !IsDefined(vehiclePS) {
            BNLog("[VehicleDaemonAction] ERROR: Vehicle not found in StateSystem");
            return;
        }

        BNLog("[VehicleDaemonAction] Target: Vehicle");
        // Delegate to Strategy Pattern (same as DeviceDaemonAction)
        this.ProcessDaemonWithStrategy(vehiclePS, gameInstance, VehicleUnlockStrategy.Create());
    }

    // Reuse same Template Method from DeviceDaemonAction
    private func ProcessDaemonWithStrategy(
        sourcePS: ref<DeviceComponentPS>,
        gameInstance: GameInstance,
        strategy: ref<IDaemonUnlockStrategy>
    ) -> Void {
        let sharedPS: ref<SharedGameplayPS> = sourcePS as SharedGameplayPS;
        if !IsDefined(sharedPS) {
            return;
        }

        let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(sourcePS);
        DeviceTypeUtils.SetBreached(deviceType, sharedPS, true);

        let stateSystem: ref<IScriptable> = strategy.GetStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            strategy.MarkBreached(stateSystem, sourcePS.GetID(), gameInstance);
        }

        strategy.ExecuteUnlock(this.m_daemonTypeStr, deviceType, sourcePS, gameInstance);
    }

    protected func ExecuteProgramFailure() -> Void {
        // Silent failure - StateSystem remains for potential retry
    }
}
