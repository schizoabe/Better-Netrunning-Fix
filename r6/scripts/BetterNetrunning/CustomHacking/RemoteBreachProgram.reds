// -----------------------------------------------------------------------------
// RemoteBreach Program
// -----------------------------------------------------------------------------
// RemoteBreach program action implementations.
//
// CONTENTS:
// - RemoteBreachProgramActionBase: Base class for all RemoteBreach programs
// - RemoteBreachProgramAction: Easy difficulty program
// - RemoteBreachProgramActionMedium: Medium difficulty program
// - RemoteBreachProgramActionHard: Hard difficulty program
// - CustomHackingSystem initialization hooks
// -----------------------------------------------------------------------------

module BetterNetrunning.CustomHacking

import BetterNetrunning.*
import BetterNetrunning.Common.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

// -----------------------------------------------------------------------------
// Program Actions
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions.Programs"))
public abstract class RemoteBreachProgramActionBase extends HackProgramAction {
    private let m_devicePS: ref<ScriptableDeviceComponentPS>;
    private let m_lastBreachRange: Float;

    protected func GetBreachRangeForDifficulty() -> Float {
        return 50.0;
    }

    protected func ExecuteProgramSuccess() -> Void {

        let player: ref<PlayerPuppet> = this.GetPlayer();
        if !IsDefined(player) {
            return;
        }

        let gameInstance: GameInstance = player.GetGame();
        if !GameInstance.IsValid(gameInstance) {
            return;
        }

        this.m_devicePS = this.GetHackedDevice();

        if !IsDefined(this.m_devicePS) {
            let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);
            if IsDefined(stateSystem) {
                stateSystem.ClearCurrentComputer();
            }
            return;
        }

        this.m_lastBreachRange = this.GetBreachRangeForDifficulty();

        let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);
        if IsDefined(stateSystem) {
            stateSystem.ClearCurrentComputer();
        }
    }

    protected func ExecuteProgramFailure() -> Void {
    }

    private func GetHackedDevice() -> ref<ScriptableDeviceComponentPS> {
        if IsDefined(this.m_devicePS) {
            return this.m_devicePS;
        }

        let player: ref<PlayerPuppet> = this.GetPlayer();
        if IsDefined(player) {
            let gameInstance: GameInstance = player.GetGame();
            let stateSystem: ref<RemoteBreachStateSystem> = StateSystemUtils.GetComputerStateSystem(gameInstance);
            if IsDefined(stateSystem) {
                let stateComputerPS: wref<ComputerControllerPS> = stateSystem.GetCurrentComputer();
                if IsDefined(stateComputerPS) {
                    return stateComputerPS;
                }
            }
        }

        return null;
    }
}

// -----------------------------------------------------------------------------
// Difficulty-specific Program Actions
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions.Programs"))
public class RemoteBreachEasyProgramAction extends RemoteBreachProgramActionBase {
    protected func GetBreachRangeForDifficulty() -> Float {
        return 60.0;
    }
}

@if(ModuleExists("HackingExtensions.Programs"))
public class RemoteBreachMediumProgramAction extends RemoteBreachProgramActionBase {
    protected func GetBreachRangeForDifficulty() -> Float {
        return 50.0;
    }
}

@if(ModuleExists("HackingExtensions.Programs"))
public class RemoteBreachHardProgramAction extends RemoteBreachProgramActionBase {
    protected func GetBreachRangeForDifficulty() -> Float {
        return 40.0;
    }
}

// -----------------------------------------------------------------------------
// System Initialization
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
    wrappedMethod();

    let hackSystem: ref<CustomHackingSystem> = StateSystemUtils.GetCustomHackingSystem(this.GetGame());

    if IsDefined(hackSystem) {
        hackSystem.AddProgramAction(
            t"MinigameProgramAction.RemoteBreachEasy",
            new RemoteBreachEasyProgramAction()
        );

        hackSystem.AddProgramAction(
            t"MinigameProgramAction.RemoteBreachMedium",
            new RemoteBreachMediumProgramAction()
        );

        hackSystem.AddProgramAction(
            t"MinigameProgramAction.RemoteBreachHard",
            new RemoteBreachHardProgramAction()
        );

        let basicDaemon: ref<BetterNetrunningDaemonAction> = new BetterNetrunningDaemonAction();
        basicDaemon.SetDaemonType(DaemonTypes.Basic());
        hackSystem.AddProgramAction(
            t"MinigameAction.UnlockQuickhacks",
            basicDaemon
        );

        let npcDaemon: ref<BetterNetrunningDaemonAction> = new BetterNetrunningDaemonAction();
        npcDaemon.SetDaemonType(DaemonTypes.NPC());
        hackSystem.AddProgramAction(
            t"MinigameAction.UnlockNPCQuickhacks",
            npcDaemon
        );

        let cameraDaemon: ref<BetterNetrunningDaemonAction> = new BetterNetrunningDaemonAction();
        cameraDaemon.SetDaemonType(DaemonTypes.Camera());
        hackSystem.AddProgramAction(
            t"MinigameAction.UnlockCameraQuickhacks",
            cameraDaemon
        );

        let turretDaemon: ref<BetterNetrunningDaemonAction> = new BetterNetrunningDaemonAction();
        turretDaemon.SetDaemonType(DaemonTypes.Turret());
        hackSystem.AddProgramAction(
            t"MinigameAction.UnlockTurretQuickhacks",
            turretDaemon
        );
    }

    return true;
}
