// -----------------------------------------------------------------------------
// Daemon Unlock Strategy Interfaces
// -----------------------------------------------------------------------------
// Provides abstraction layer for daemon unlock execution.
// Implements Strategy Pattern to eliminate duplicate daemon processing logic.
//
// DESIGN RATIONALE:
// - Strategy Pattern: Encapsulates unlock algorithms per target type
// - DRY Principle: Eliminates 150+ lines of duplicate code
// - Open/Closed: Easy to add new daemon types without modifying core logic
//
// ARCHITECTURE:
// DeviceDaemonAction.ExecuteProgramSuccess()
//   └─> ProcessDaemonBase()  [Template Method]
//        ├─> SetBreached()  [Common]
//        ├─> MarkBreached()  [StateSystem - varies by type]
//        ├─> ExecuteUnlock()  [Strategy - varies by daemon]
//        └─> RecordBreachPosition()  [Common]
//
// USAGE:
// let strategy: ref<IDaemonUnlockStrategy> = ComputerUnlockStrategy.Create();
// this.ProcessDaemonBase(sharedPS, gameInstance, strategy);
// -----------------------------------------------------------------------------

module BetterNetrunning.CustomHacking

import BetterNetrunning.*
import BetterNetrunning.Common.*

// ==================== Strategy Interface ====================

// Abstract interface for daemon unlock execution
// Each target type (Computer/Device/Vehicle) implements this
public abstract class IDaemonUnlockStrategy {

  // Executes unlock logic for specific daemon type
  // Called after breach flags are set and StateSystem is updated
  public func ExecuteUnlock(
    daemonType: String,
    deviceType: DeviceType,
    sourcePS: ref<DeviceComponentPS>,
    gameInstance: GameInstance
  ) -> Void {}

  // Gets StateSystem for breach tracking
  // Each target type has different StateSystem
  public func GetStateSystem(gameInstance: GameInstance) -> ref<IScriptable> {
    return null;
  }

  // Marks device as breached in StateSystem
  // Implementation varies by target type
  public func MarkBreached(stateSystem: ref<IScriptable>, deviceID: PersistentID, gameInstance: GameInstance) -> Void {}
}

// ==================== Computer Unlock Strategy ====================

@if(ModuleExists("HackingExtensions"))
public class ComputerUnlockStrategy extends IDaemonUnlockStrategy {

  public func ExecuteUnlock(
    daemonType: String,
    deviceType: DeviceType,
    sourcePS: ref<DeviceComponentPS>,
    gameInstance: GameInstance
  ) -> Void {
    BNLog("[ComputerUnlockStrategy] Executing unlock for daemon: " + daemonType);

    let computerPS: ref<ComputerControllerPS> = sourcePS as ComputerControllerPS;
    if !IsDefined(computerPS) {
      BNLog("[ComputerUnlockStrategy] ERROR: Cannot cast to ComputerControllerPS");
      return;
    }

    // Determine unlock flags based on daemon type
    let unlockBasic: Bool = Equals(daemonType, DaemonTypes.Basic());
    let unlockNPCs: Bool = Equals(daemonType, DaemonTypes.NPC());
    let unlockCameras: Bool = Equals(daemonType, DaemonTypes.Camera());
    let unlockTurrets: Bool = Equals(daemonType, DaemonTypes.Turret());

    BNLog("[ComputerUnlockStrategy] Flags - Basic:" + ToString(unlockBasic) + " NPCs:" + ToString(unlockNPCs) + " Cameras:" + ToString(unlockCameras) + " Turrets:" + ToString(unlockTurrets));

    // Execute network unlock
    ComputerRemoteBreachUtils.UnlockNetworkDevices(
      computerPS,
      unlockBasic,
      unlockNPCs,
      unlockCameras,
      unlockTurrets
    );

    // Unlock NPCs in radius if NPC daemon
    if unlockNPCs {
      RemoteBreachUtils.UnlockNPCsInRange(computerPS, gameInstance);
    }

    // Record breach position for radial unlock
    RemoteBreachUtils.RecordBreachPosition(computerPS, gameInstance);
    BNLog("[ComputerUnlockStrategy] Unlock completed");
  }

  public func GetStateSystem(gameInstance: GameInstance) -> ref<IScriptable> {
    return StateSystemUtils.GetComputerStateSystem(gameInstance);
  }

  public func MarkBreached(stateSystem: ref<IScriptable>, deviceID: PersistentID, gameInstance: GameInstance) -> Void {
    let remoteBreachSystem: ref<RemoteBreachStateSystem> = stateSystem as RemoteBreachStateSystem;
    if IsDefined(remoteBreachSystem) {
      remoteBreachSystem.MarkComputerBreached(deviceID);
    }
  }

  public static func Create() -> ref<ComputerUnlockStrategy> {
    return new ComputerUnlockStrategy();
  }
}

// ==================== Device Unlock Strategy ====================

@if(ModuleExists("HackingExtensions"))
public class DeviceUnlockStrategy extends IDaemonUnlockStrategy {

  public func ExecuteUnlock(
    daemonType: String,
    deviceType: DeviceType,
    sourcePS: ref<DeviceComponentPS>,
    gameInstance: GameInstance
  ) -> Void {
    BNLog("[DeviceUnlockStrategy] Executing unlock for daemon: " + daemonType);

    let devicePS: ref<ScriptableDeviceComponentPS> = sourcePS as ScriptableDeviceComponentPS;
    if !IsDefined(devicePS) {
      BNLog("[DeviceUnlockStrategy] ERROR: Cannot cast to ScriptableDeviceComponentPS");
      return;
    }

    // Determine unlock flags based on daemon type
    let unlockBasic: Bool = Equals(daemonType, DaemonTypes.Basic());
    let unlockNPCs: Bool = Equals(daemonType, DaemonTypes.NPC());
    let unlockCameras: Bool = Equals(daemonType, DaemonTypes.Camera());
    let unlockTurrets: Bool = Equals(daemonType, DaemonTypes.Turret());

    BNLog("[DeviceUnlockStrategy] Flags - Basic:" + ToString(unlockBasic) + " NPCs:" + ToString(unlockNPCs) + " Cameras:" + ToString(unlockCameras) + " Turrets:" + ToString(unlockTurrets));

    // Execute radius unlock for Basic daemon
    if unlockBasic {
      RemoteBreachUtils.UnlockDevicesInRadius(devicePS, gameInstance);
    }

    // Unlock network devices
    this.UnlockDevicesInNetwork(devicePS, unlockBasic, unlockNPCs, unlockCameras, unlockTurrets);

    // Unlock NPCs in radius if NPC daemon
    if unlockNPCs {
      RemoteBreachUtils.UnlockNPCsInRange(devicePS, gameInstance);
    }

    // Record breach position for radial unlock
    RemoteBreachUtils.RecordBreachPosition(devicePS, gameInstance);
    BNLog("[DeviceUnlockStrategy] Unlock completed");
  }

  public func GetStateSystem(gameInstance: GameInstance) -> ref<IScriptable> {
    return StateSystemUtils.GetDeviceStateSystem(gameInstance);
  }

  public func MarkBreached(stateSystem: ref<IScriptable>, deviceID: PersistentID, gameInstance: GameInstance) -> Void {
    let deviceBreachSystem: ref<DeviceRemoteBreachStateSystem> = stateSystem as DeviceRemoteBreachStateSystem;
    let deviceEntity: wref<GameObject> = GameInstance.FindEntityByID(
      gameInstance,
      PersistentID.ExtractEntityID(deviceID)
    ) as GameObject;

    if IsDefined(deviceBreachSystem) && IsDefined(deviceEntity) {
      deviceBreachSystem.MarkDeviceBreached(deviceEntity.GetEntityID());
    }
  }

  // Helper: Unlock devices in network (AccessPoint children)
  private func UnlockDevicesInNetwork(
    devicePS: ref<ScriptableDeviceComponentPS>,
    unlockBasic: Bool,
    unlockNPCs: Bool,
    unlockCameras: Bool,
    unlockTurrets: Bool
  ) -> Void {
    let sharedPS: ref<SharedGameplayPS> = devicePS;
    if !IsDefined(sharedPS) {
      return;
    }

    let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();

    // If no AccessPoints, use radial unlock instead
    if ArraySize(apControllers) == 0 {
      let deviceEntity: wref<GameObject> = devicePS.GetOwnerEntityWeak() as GameObject;
      let gameInstance: GameInstance = devicePS.GetGameInstance();
      RemoteBreachUtils.UnlockNearbyNetworkDevices(
        deviceEntity,
        gameInstance,
        unlockBasic,
        unlockNPCs,
        unlockCameras,
        unlockTurrets,
        "UnlockDevicesInNetwork"
      );
      return;
    }

    // Unlock via AccessPoint children
    let i: Int32 = 0;
    while i < ArraySize(apControllers) {
      let apPS: ref<AccessPointControllerPS> = apControllers[i];
      if IsDefined(apPS) {
        let networkDevices: array<ref<DeviceComponentPS>>;
        apPS.GetChildren(networkDevices);

        let j: Int32 = 0;
        while j < ArraySize(networkDevices) {
          let device: ref<DeviceComponentPS> = networkDevices[j];
          if IsDefined(device) {
            this.ApplyUnlockToDevice(device, unlockBasic, unlockNPCs, unlockCameras, unlockTurrets);
          }
          j += 1;
        }
      }
      i += 1;
    }
  }

  // Helper: Apply unlock to single device based on type
  private func ApplyUnlockToDevice(
    device: ref<DeviceComponentPS>,
    unlockBasic: Bool,
    unlockNPCs: Bool,
    unlockCameras: Bool,
    unlockTurrets: Bool
  ) -> Void {
    let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;
    if !IsDefined(sharedPS) {
      return;
    }

    let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

    switch deviceType {
      case DeviceType.NPC:
        if unlockNPCs {
          sharedPS.m_betterNetrunningBreachedNPCs = true;
        }
        break;
      case DeviceType.Camera:
        if unlockCameras {
          sharedPS.m_betterNetrunningBreachedCameras = true;
        }
        break;
      case DeviceType.Turret:
        if unlockTurrets {
          sharedPS.m_betterNetrunningBreachedTurrets = true;
        }
        break;
      default: // DeviceType.Basic
        if unlockBasic {
          sharedPS.m_betterNetrunningBreachedBasic = true;
        }
        break;
    }
  }

  public static func Create() -> ref<DeviceUnlockStrategy> {
    return new DeviceUnlockStrategy();
  }
}

// ==================== Vehicle Unlock Strategy ====================

@if(ModuleExists("HackingExtensions"))
public class VehicleUnlockStrategy extends IDaemonUnlockStrategy {

  public func ExecuteUnlock(
    daemonType: String,
    deviceType: DeviceType,
    sourcePS: ref<DeviceComponentPS>,
    gameInstance: GameInstance
  ) -> Void {
    BNLog("[VehicleUnlockStrategy] Executing unlock for daemon: " + daemonType);

    let vehiclePS: ref<VehicleComponentPS> = sourcePS as VehicleComponentPS;
    if !IsDefined(vehiclePS) {
      BNLog("[VehicleUnlockStrategy] ERROR: Cannot cast to VehicleComponentPS");
      return;
    }

    let vehicleEntity: wref<GameObject> = vehiclePS.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(vehicleEntity) {
      BNLog("[VehicleUnlockStrategy] ERROR: Vehicle entity not found");
      return;
    }

    // Determine unlock flags based on daemon type
    let unlockBasic: Bool = Equals(daemonType, DaemonTypes.Basic());
    let unlockNPCs: Bool = Equals(daemonType, DaemonTypes.NPC());
    let unlockCameras: Bool = Equals(daemonType, DaemonTypes.Camera());
    let unlockTurrets: Bool = Equals(daemonType, DaemonTypes.Turret());

    BNLog("[VehicleUnlockStrategy] Flags - Basic:" + ToString(unlockBasic) + " NPCs:" + ToString(unlockNPCs) + " Cameras:" + ToString(unlockCameras) + " Turrets:" + ToString(unlockTurrets));

    // Execute vehicle unlock in radius (for Basic daemon)
    if unlockBasic {
      this.UnlockVehiclesInRange(vehiclePS, gameInstance);
    }

    // Unlock nearby network devices
    RemoteBreachUtils.UnlockNearbyNetworkDevices(
      vehicleEntity,
      gameInstance,
      unlockBasic,
      unlockNPCs,
      unlockCameras,
      unlockTurrets,
      "UnlockNetworkDevicesFromVehicle"
    );

    // Record breach position for radial unlock
    RemoteBreachUtils.RecordBreachPosition(vehiclePS, gameInstance);
    BNLog("[VehicleUnlockStrategy] Unlock completed");
  }

  public func GetStateSystem(gameInstance: GameInstance) -> ref<IScriptable> {
    return StateSystemUtils.GetVehicleStateSystem(gameInstance);
  }

  public func MarkBreached(stateSystem: ref<IScriptable>, deviceID: PersistentID, gameInstance: GameInstance) -> Void {
    let vehicleBreachSystem: ref<VehicleRemoteBreachStateSystem> = stateSystem as VehicleRemoteBreachStateSystem;
    let vehicleEntity: wref<GameObject> = GameInstance.FindEntityByID(
      gameInstance,
      PersistentID.ExtractEntityID(deviceID)
    ) as GameObject;

    if IsDefined(vehicleBreachSystem) && IsDefined(vehicleEntity) {
      vehicleBreachSystem.MarkVehicleBreached(vehicleEntity.GetEntityID());
    }
  }

  // Helper: Unlock vehicles in range (50m radius)
  private func UnlockVehiclesInRange(vehiclePS: wref<VehicleComponentPS>, gameInstance: GameInstance) -> Void {
    let vehicleEntity: wref<GameObject> = vehiclePS.GetOwnerEntityWeak() as GameObject;
    if !IsDefined(vehicleEntity) {
      return;
    }

    let vehiclePos: Vector4 = vehicleEntity.GetWorldPosition();
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
        let vehicle: ref<VehicleObject> = entity as VehicleObject;

        if IsDefined(vehicle) {
          let vehPS: ref<VehicleComponentPS> = vehicle.GetVehiclePS();

          if IsDefined(vehPS) {
            let entityPos: Vector4 = entity.GetWorldPosition();
            let distance: Float = Vector4.Distance(vehiclePos, entityPos);

            if distance <= breachRadius {
              let vehSharedPS: ref<SharedGameplayPS> = vehPS;
              if IsDefined(vehSharedPS) {
                vehSharedPS.m_betterNetrunningBreachedBasic = true;
              }
            }
          }
        }
      }
      idx += 1;
    }
  }

  public static func Create() -> ref<VehicleUnlockStrategy> {
    return new VehicleUnlockStrategy();
  }
}
