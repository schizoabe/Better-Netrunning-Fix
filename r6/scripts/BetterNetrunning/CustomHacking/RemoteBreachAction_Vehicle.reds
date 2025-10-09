// -----------------------------------------------------------------------------
// RemoteBreach Action - Vehicle
// -----------------------------------------------------------------------------
// Vehicle-specific RemoteBreach action implementation.
// Defines VehicleRemoteBreachAction class for Vehicle devices.
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
// Vehicle Remote Breach Action
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public class VehicleRemoteBreachAction extends BaseRemoteBreachAction {
    private let m_vehiclePS: ref<VehicleComponentPS>;

    public func GetInteractionDescription() -> String {
        return "Remote Breach";
    }

    public func GetTweakDBChoiceRecord() -> String {
        return "Remote Breach";
    }

    public func SetVehiclePS(vehiclePS: ref<VehicleComponentPS>) -> Void {
        this.m_vehiclePS = vehiclePS;
    }

    public func InitializePrograms() -> Void {

        if !IsDefined(this.m_vehiclePS) {
            return;
        }

        let gameInstance: GameInstance = this.m_vehiclePS.GetGameInstance();
        let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);
        let stateSystem: ref<VehicleRemoteBreachStateSystem> = StateSystemUtils.GetVehicleStateSystem(gameInstance);

        if IsDefined(stateSystem) {
            let availableDaemons: String = "basic";
            stateSystem.SetCurrentVehicle(this.m_vehiclePS, availableDaemons);
        }
    }
}

// -----------------------------------------------------------------------------
// Vehicle Component Extensions
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
@addMethod(VehicleComponentPS)
private final func ActionCustomVehicleRemoteBreach() -> ref<VehicleRemoteBreachAction> {
    let action: ref<VehicleRemoteBreachAction> = new VehicleRemoteBreachAction();
    action.SetVehiclePS(this);
    RemoteBreachActionHelper.Initialize(action, this, n"VehicleRemoteBreach");

    // Set Vehicle-specific minigame ID (Basic daemon only)
    let difficulty: GameplayDifficulty = RemoteBreachActionHelper.GetCurrentDifficulty();
    RemoteBreachActionHelper.SetMinigameDefinition(action, MinigameTargetType.Vehicle, difficulty, this);

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
@wrapMethod(VehicleComponentPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
    wrappedMethod(actions, context);
    RemoteBreachActionHelper.RemoveTweakDBRemoteBreach(actions, n"VehicleRemoteBreachAction");

    // Check if Vehicle RemoteBreach is enabled AND UnlockIfNoAccessPoint is disabled
    if !BetterNetrunningSettings.RemoteBreachEnabledVehicle() || BetterNetrunningSettings.UnlockIfNoAccessPoint() {
        return;
    }

    let vehicleEntity: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(vehicleEntity) {
        return;
    }

    let vehicleID: EntityID = vehicleEntity.GetEntityID();
    let stateSystem: ref<VehicleRemoteBreachStateSystem> = StateSystemUtils.GetVehicleStateSystem(this.GetGameInstance());

    if IsDefined(stateSystem) && stateSystem.IsVehicleBreached(vehicleID) {
        return;
    }

    let breachAction: ref<VehicleRemoteBreachAction> = this.ActionCustomVehicleRemoteBreach();
    ArrayPush(actions, breachAction);
}
