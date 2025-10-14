import HackthePlanetConfig.*
import BetterNetrunning.CustomHacking.*
import BetterNetrunning.*
import BetterNetrunningConfig.*
import BetterNetrunning.Common.*
import BetterNetrunning.RadialUnlock.*

@wrapMethod(ScriptableDeviceComponentPS)
protected func OnTogglePersonalLink(evt: ref<TogglePersonalLink>) -> EntityNotificationType {
  let player = this.GetLocalPlayer();
  let lookedAtObject: ref<Device> = GameInstance.GetTargetingSystem(player.GetGame()).GetLookAtObject(player) as Device;
  
  if HackthePlanetSettings.HackthePlanet() {
    if IsDefined(lookedAtObject) {
      if Equals(GetLocalizedText(lookedAtObject.GetDeviceName()),"Computer") || Equals(GetLocalizedText(lookedAtObject.GetDeviceName()),"Spontaneous Craving Satisfaction Machine") || Equals(GetLocalizedText(lookedAtObject.GetDeviceName()),"Weapon Vending Machine") || Equals(GetLocalizedText(lookedAtObject.GetDeviceName()),"Confession Booth") || Equals(GetLocalizedText(lookedAtObject.GetDeviceName()),"Ice Machine") || Equals(GetLocalizedText(lookedAtObject.GetDeviceName()),"Arcade Machine")  || Equals(GetLocalizedText(lookedAtObject.GetDeviceName()),"Pachinko Machine") {
        this.m_minigameDefinition = t"minigame.ComputerRemoteBreachEasy";
      }
    }
  }
  
  return wrappedMethod(evt);
}

@wrapMethod(ScriptableDeviceComponentPS)
public const func GetMinigameDefinition() -> TweakDBID {
  let vanilla: TweakDBID = wrappedMethod();
  
  if !TDBID.IsValid(vanilla) {
    return t"minigame.ComputerRemoteBreachEasy";
  }
  
  return vanilla;
}

@wrapMethod(ScriptableDeviceComponentPS)
public const func GetNetworkSizeCount() -> Int32 {
  let vanilla: Int32 = wrappedMethod();
  
  if vanilla <= 0 {
    return 1;
  }
  
  return vanilla;
}

@wrapMethod(SharedGameplayPS)
public const func GetNetworkName() -> String {
  let vanilla: String = wrappedMethod();
  
  if Equals(vanilla, "") || !IsStringValid(vanilla) {
    return "Local Network";
  }
  
  return vanilla;
}

@wrapMethod(Device)
private final func DisplayConnectionWindowOnPlayerHUD(shouldDisplay: Bool, attempt: Int32) -> Void {
  if shouldDisplay {
    let networkName: String = this.GetDevicePS().GetNetworkName();
    let connectionsCount: Int32 = this.GetDevicePS().GetNetworkSizeCount();
    let minigameID: TweakDBID = this.GetDevicePS().GetMinigameDefinition();
    
    if !TDBID.IsValid(minigameID) {
      minigameID = t"minigame.ComputerRemoteBreachEasy";
    }
    if connectionsCount <= 0 {
      connectionsCount = 1;
    }
    
    let networkBB: ref<IBlackboard> = this.GetNetworkBlackboard();
    let networkDef: ref<NetworkBlackboardDef> = this.GetNetworkBlackboardDef();
    
    networkBB.SetInt(networkDef.DevicesCount, connectionsCount);
    networkBB.SetBool(networkDef.OfficerBreach, false);
    networkBB.SetString(networkDef.NetworkName, networkName);
    networkBB.SetVariant(networkDef.MinigameDef, ToVariant(minigameID));
    networkBB.SetInt(networkDef.Attempt, attempt);
    networkBB.SetEntityID(networkDef.DeviceID, this.GetEntityID());
    networkBB.FireCallbacks();
  } else {
    wrappedMethod(shouldDisplay, attempt);
  }
}

@replaceMethod(Device)
protected cb func OnAccessPointMiniGameStatus(evt: ref<AccessPointMiniGameStatus>) -> Bool {
    this.GetDevicePS().HackingMinigameEnded(evt.minigameState);

    if Equals(evt.minigameState, HackingMinigameState.Succeeded) {
        this.SucceedGameplayObjective(this.GetDevicePS().GetBackdoorObjectiveData());

        let devicePS: ref<ScriptableDeviceComponentPS> = this.GetDevicePS();

        if IsDefined(devicePS) {
            // Get active programs from blackboard to determine which subnets to unlock
            let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGame()).Get(GetAllBlackboardDefs().HackingMinigame);
            let activePrograms: array<TweakDBID>;
            
            if IsDefined(minigameBB) {
                activePrograms = FromVariant<array<TweakDBID>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms));
            }
            
            // Parse which unlock daemons were completed
            let unlockFlags: BreachUnlockFlags = this.ParseHackthePlanetUnlockFlags(activePrograms);
            
            if BetterNetrunningSettings.EnableDebugLog() {
                BNLog("[HackthePlanet] Unlock flags - Basic: " + ToString(unlockFlags.unlockBasic) +
                      ", NPCs: " + ToString(unlockFlags.unlockNPCs) +
                      ", Cameras: " + ToString(unlockFlags.unlockCameras) +
                      ", Turrets: " + ToString(unlockFlags.unlockTurrets));
            }
            
            // Record breach position and unlock nearby devices with subnet filtering
            RemoteBreachUtils.RecordBreachPosition(devicePS, this.GetGame());
            this.UnlockNearbyDevicesWithSubnets(devicePS, unlockFlags);

            if BetterNetrunningSettings.EnableDebugLog() {
                BNLog("[HackthePlanet -> BetterNetrunning] Recorded virtual AP breach and triggered subnet-aware radial unlock for device: " +
                      ToString(devicePS.GetOwnerEntityWeak().GetEntityID()));
            };
        };

        this.EvaluateProximityMappinInteractionLayerState();
        this.EvaluateProximityRevealInteractionLayerState();
    } else {
        if Equals(evt.minigameState, HackingMinigameState.Failed) {
            this.GetDevicePS().TriggerSecuritySystemNotification(
                GameInstance.GetPlayerSystem(this.GetGame()).GetLocalPlayerControlledGameObject(),
                this.GetWorldPosition(),
                ESecurityNotificationType.ALARM
            );
        };
    };

    QuickhackModule.RequestRefreshQuickhackMenu(this.GetGame(), this.GetEntityID());
}

// Parse which unlock daemons were completed
@addMethod(Device)
private func ParseHackthePlanetUnlockFlags(activePrograms: array<TweakDBID>) -> BreachUnlockFlags {
  let flags: BreachUnlockFlags;

  let i: Int32 = 0;
  while i < ArraySize(activePrograms) {
    let programID: TweakDBID = activePrograms[i];

    if Equals(programID, t"MinigameAction.UnlockQuickhacks") {
      flags.unlockBasic = true;
    } else if Equals(programID, t"MinigameAction.UnlockNPCQuickhacks") {
      flags.unlockNPCs = true;
    } else if Equals(programID, t"MinigameAction.UnlockCameraQuickhacks") {
      flags.unlockCameras = true;
    } else if Equals(programID, t"MinigameAction.UnlockTurretQuickhacks") {
      flags.unlockTurrets = true;
    }

    i += 1;
  }

  return flags;
}

// Unlock nearby standalone devices with subnet filtering
@addMethod(Device)
private func UnlockNearbyDevicesWithSubnets(breachedDevicePS: ref<ScriptableDeviceComponentPS>, unlockFlags: BreachUnlockFlags) -> Void {
  let gameInstance: GameInstance = this.GetGame();
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);
  
  if !IsDefined(targetingSystem) || !IsDefined(player) {
    return;
  }
  
  let query: TargetSearchQuery;
  query.searchFilter = TSF_All(TSFMV.Obj_Device);
  query.testedSet = TargetingSet.Complete;
  query.maxDistance = 50.0;
  query.filterObjectByDistance = true;
  query.includeSecondaryTargets = false;
  query.ignoreInstigator = true;
  
  let parts: array<TS_TargetPartInfo>;
  targetingSystem.GetTargetParts(player, query, parts);
  
  let unlockedCount: Int32 = 0;
  let i: Int32 = 0;
  
  while i < ArraySize(parts) {
    let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(parts[i]).GetEntity() as GameObject;
    
    if IsDefined(entity) {
      let device: ref<Device> = entity as Device;
      if IsDefined(device) {
        let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
        if IsDefined(devicePS) {
          let sharedPS: ref<SharedGameplayPS> = devicePS;
          if IsDefined(sharedPS) {
            let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
            
            // Only unlock standalone devices (no AccessPoints)
            if ArraySize(apControllers) == 0 {
              // Get device type and check if it should be unlocked based on flags
              let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(devicePS);
              
              if this.ShouldUnlockDeviceType(deviceType, unlockFlags) {
                // Set the appropriate breach flag based on device type
                DeviceTypeUtils.SetBreached(deviceType, sharedPS, true);
                unlockedCount += 1;
              }
            }
          }
        }
      }
    }
    
    i += 1;
  }
  
  if unlockedCount > 0 && BetterNetrunningSettings.EnableDebugLog() {
    BNLog(s"[HackthePlanet] Unlocked \(unlockedCount) nearby standalone device(s) with subnet filtering");
  }
}

// Check if device type should be unlocked based on completed daemons
@addMethod(Device)
private func ShouldUnlockDeviceType(deviceType: DeviceType, unlockFlags: BreachUnlockFlags) -> Bool {
  // Check device type against unlock flags (same logic as Better Netrunning)
  if Equals(deviceType, DeviceType.Camera) {
    return unlockFlags.unlockCameras;
  } else if Equals(deviceType, DeviceType.Turret) {
    return unlockFlags.unlockTurrets;
  } else if Equals(deviceType, DeviceType.NPC) {
    return unlockFlags.unlockNPCs;
  } else {
    // All other device types use Basic flag
    return unlockFlags.unlockBasic;
  }
}
