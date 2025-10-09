// -----------------------------------------------------------------------------
// RemoteBreach Action - Computer
// -----------------------------------------------------------------------------
// Computer-specific RemoteBreach action implementation.
// Defines RemoteBreachAction class for Computer devices.
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
// Computer Remote Breach Action
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
public class RemoteBreachAction extends BaseRemoteBreachAction {
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

    public func SetComputerPS(computerPS: ref<ComputerControllerPS>) -> Void {
        this.m_devicePS = computerPS;
    }

    public func InitializePrograms() -> Void {

        if !IsDefined(this.m_devicePS) {
            return;
        }

        let computerPS: ref<ComputerControllerPS> = this.m_devicePS as ComputerControllerPS;

        if !IsDefined(computerPS) {
            return;
        }

        let gameInstance: GameInstance = computerPS.GetGameInstance();
        let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);

        if IsDefined(stateSystem) {
            stateSystem.SetCurrentComputer(computerPS);
        }
    }
}

// -----------------------------------------------------------------------------
// Computer Controller Extensions
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
@addMethod(ComputerControllerPS)
private final func ActionCustomRemoteBreach() -> ref<RemoteBreachAction> {
    let action: ref<RemoteBreachAction> = new RemoteBreachAction();
    action.SetComputerPS(this);
    RemoteBreachActionHelper.Initialize(action, this, n"RemoteBreach");

    // Set Computer-specific minigame ID
    let difficulty: GameplayDifficulty = RemoteBreachActionHelper.GetCurrentDifficulty();
    RemoteBreachActionHelper.SetMinigameDefinition(action, MinigameTargetType.Computer, difficulty, this);

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
@wrapMethod(ComputerControllerPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
    wrappedMethod(actions, context);
    RemoteBreachActionHelper.RemoveTweakDBRemoteBreach(actions, n"RemoteBreachAction");

    // Check if Computer RemoteBreach is enabled AND UnlockIfNoAccessPoint is disabled
    if !BetterNetrunningSettings.RemoteBreachEnabledComputer() || BetterNetrunningSettings.UnlockIfNoAccessPoint() {
        return;
    }

    // Check if this computer is already breached via RemoteBreach StateSystem
    let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(this.GetGameInstance());

    if IsDefined(stateSystem) && stateSystem.IsComputerBreached(this.GetID()) {
        return;
    }

    let breachAction: ref<RemoteBreachAction> = this.ActionCustomRemoteBreach();
    ArrayPush(actions, breachAction);
}
