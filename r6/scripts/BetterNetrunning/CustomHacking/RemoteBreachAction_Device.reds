// -----------------------------------------------------------------------------
// RemoteBreach Action - Device
// -----------------------------------------------------------------------------
// Generic device RemoteBreach action implementation.
// Defines DeviceRemoteBreachAction class for generic devices (TV, Jukebox, etc).
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
// Device Remote Breach Action
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public class DeviceRemoteBreachAction extends BaseRemoteBreachAction {
    private let m_devicePS: ref<ScriptableDeviceComponentPS>;

    public func GetInteractionDescription() -> String {
        return "Remote Breach";
    }

    public func GetTweakDBChoiceRecord() -> String {
        return "Remote Breach";
    }

    public func SetDevicePS(devicePS: ref<ScriptableDeviceComponentPS>) -> Void {
        this.m_devicePS = devicePS;
    }

    public func InitializePrograms() -> Void {

        if !IsDefined(this.m_devicePS) {
            return;
        }

        let gameInstance: GameInstance = this.m_devicePS.GetGameInstance();
        let stateSystem: ref<DeviceRemoteBreachStateSystem> = StateSystemUtils.GetDeviceStateSystem(gameInstance);

        if IsDefined(stateSystem) {
            let availableDaemons: String = this.GetAvailableDaemonsForDevice();
            stateSystem.SetCurrentDevice(this.m_devicePS, availableDaemons);
        }
    }

    private func GetAvailableDaemonsForDevice() -> String {

        // Camera: basic + camera daemon
        if DaemonFilterUtils.IsCamera(this.m_devicePS) {
            return "basic,camera";
        }

        // Turret: basic + turret daemon
        if DaemonFilterUtils.IsTurret(this.m_devicePS) {
            return "basic,turret";
        }

        // Terminal: basic + npc daemon
        if IsDefined(this.m_devicePS as TerminalControllerPS) {
            return "basic,npc";
        }

        // Default: basic only
        return "basic";
    }
}

// -----------------------------------------------------------------------------
// Device Extensions
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
@addMethod(ScriptableDeviceComponentPS)
private final func ActionCustomDeviceRemoteBreach() -> ref<DeviceRemoteBreachAction> {
    let action: ref<DeviceRemoteBreachAction> = new DeviceRemoteBreachAction();
    action.SetDevicePS(this);
    RemoteBreachActionHelper.Initialize(action, this, n"DeviceRemoteBreach");

    // Set Device-specific minigame ID
    let difficulty: GameplayDifficulty = RemoteBreachActionHelper.GetCurrentDifficulty();
    RemoteBreachActionHelper.SetMinigameDefinition(action, MinigameTargetType.Device, difficulty, this);

    // Directly call InitializePrograms() on the concrete type
    action.InitializePrograms();

    // CRITICAL: Register with CustomHackingSystem
    let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance());
    let hackSystem: ref<CustomHackingSystem> = container.Get(n"HackingExtensions.CustomHackingSystem") as CustomHackingSystem;

    if IsDefined(hackSystem) {
        hackSystem.RegisterDeviceAction(action);
    }

    return action;
}

@if(ModuleExists("HackingExtensions"))
@wrapMethod(ScriptableDeviceComponentPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
    wrappedMethod(actions, context);
    RemoteBreachActionHelper.RemoveTweakDBRemoteBreach(actions, n"DeviceRemoteBreachAction");

    if DaemonFilterUtils.IsComputer(this) || IsDefined(this as VehicleComponentPS) {
        return;
    }

    if !BetterNetrunningSettings.UnlockIfNoAccessPoint() {
        let deviceEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
        if !IsDefined(deviceEntity) {
            return;
        }

        let deviceID: EntityID = deviceEntity.GetEntityID();
        let stateSystem: ref<DeviceRemoteBreachStateSystem> = StateSystemUtils.GetDeviceStateSystem(this.GetGameInstance());

        if IsDefined(stateSystem) && stateSystem.IsDeviceBreached(deviceID) {
            return;
        }

        let breachAction: ref<DeviceRemoteBreachAction> = this.ActionCustomDeviceRemoteBreach();
        ArrayPush(actions, breachAction);
    }
}
