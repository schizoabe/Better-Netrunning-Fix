// -----------------------------------------------------------------------------
// RemoteBreach Daemon Registration
// -----------------------------------------------------------------------------
// Registers daemon actions (DeviceDaemonAction, VehicleDaemonAction) with
// CustomHackingSystem during game initialization.
//
// RESPONSIBILITIES:
// - Register 8 daemon actions (4 Device + 4 Vehicle) with CustomHackingSystem
// - Hook PlayerPuppet.OnGameAttached to ensure system initialization order
//
// DAEMON TYPES:
// - Basic: UnlockQuickhacks (devices/vehicles in network)
// - NPC: UnlockNPCQuickhacks (NPCs in range)
// - Camera: UnlockCameraQuickhacks (cameras in network)
// - Turret: UnlockTurretQuickhacks (turrets in network)
//
// NOTE: Daemon implementation is in DaemonImplementation.reds
// -----------------------------------------------------------------------------

module BetterNetrunning.CustomHacking

import BetterNetrunning.*
import BetterNetrunning.Common.*

@if(ModuleExists("HackingExtensions"))
import HackingExtensions.*

@if(ModuleExists("HackingExtensions.Programs"))
import HackingExtensions.Programs.*

// -----------------------------------------------------------------------------
// Register daemon actions after CustomHackingSystem initializes
// -----------------------------------------------------------------------------

@if(ModuleExists("HackingExtensions"))
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
    // CRITICAL: Call wrappedMethod() FIRST to ensure CustomHackingSystem is initialized
    let result: Bool = wrappedMethod();

    // Register BetterNetrunning daemon actions
    this.RegisterBetterNetrunningDaemons();

    return result;
}

@if(ModuleExists("HackingExtensions"))
@addMethod(PlayerPuppet)
private func RegisterBetterNetrunningDaemons() -> Void {
    let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(this.GetGame());
    let hackingSystem: ref<CustomHackingSystem> = container.Get(n"HackingExtensions.CustomHackingSystem") as CustomHackingSystem;

    if !IsDefined(hackingSystem) {
        return;
    }

    // Register Device daemon actions for RemoteBreach minigames
    // Using MinigameProgramAction prefix to match Lua CreateProgramAction() behavior
    let unlockBasicAction: ref<DeviceDaemonAction> = new DeviceDaemonAction();
    unlockBasicAction.SetDaemonType(DaemonTypes.Basic());
    hackingSystem.AddProgramAction(t"MinigameProgramAction.BN_RemoteBreach_UnlockBasic", unlockBasicAction);

    let unlockNPCAction: ref<DeviceDaemonAction> = new DeviceDaemonAction();
    unlockNPCAction.SetDaemonType(DaemonTypes.NPC());
    hackingSystem.AddProgramAction(t"MinigameProgramAction.BN_RemoteBreach_UnlockNPC", unlockNPCAction);

    let unlockCameraAction: ref<DeviceDaemonAction> = new DeviceDaemonAction();
    unlockCameraAction.SetDaemonType(DaemonTypes.Camera());
    hackingSystem.AddProgramAction(t"MinigameProgramAction.BN_RemoteBreach_UnlockCamera", unlockCameraAction);

    let unlockTurretAction: ref<DeviceDaemonAction> = new DeviceDaemonAction();
    unlockTurretAction.SetDaemonType(DaemonTypes.Turret());
    hackingSystem.AddProgramAction(t"MinigameProgramAction.BN_RemoteBreach_UnlockTurret", unlockTurretAction);

    // Register Vehicle daemon actions for RemoteBreach minigames
    let vehicleUnlockBasicAction: ref<VehicleDaemonAction> = new VehicleDaemonAction();
    vehicleUnlockBasicAction.SetDaemonType(DaemonTypes.Basic());
    hackingSystem.AddProgramAction(t"MinigameProgramAction.BN_VehicleRemoteBreach_UnlockBasic", vehicleUnlockBasicAction);

    let vehicleUnlockNPCAction: ref<VehicleDaemonAction> = new VehicleDaemonAction();
    vehicleUnlockNPCAction.SetDaemonType(DaemonTypes.NPC());
    hackingSystem.AddProgramAction(t"MinigameProgramAction.BN_VehicleRemoteBreach_UnlockNPC", vehicleUnlockNPCAction);

    let vehicleUnlockCameraAction: ref<VehicleDaemonAction> = new VehicleDaemonAction();
    vehicleUnlockCameraAction.SetDaemonType(DaemonTypes.Camera());
    hackingSystem.AddProgramAction(t"MinigameProgramAction.BN_VehicleRemoteBreach_UnlockCamera", vehicleUnlockCameraAction);

    let vehicleUnlockTurretAction: ref<VehicleDaemonAction> = new VehicleDaemonAction();
    vehicleUnlockTurretAction.SetDaemonType(DaemonTypes.Turret());
    hackingSystem.AddProgramAction(t"MinigameProgramAction.BN_VehicleRemoteBreach_UnlockTurret", vehicleUnlockTurretAction);
}
