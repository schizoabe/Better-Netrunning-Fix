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
        // Use proper Computer minigame ID (capitalized) - defaulting to Medium difficulty
        this.m_minigameDefinition = t"Minigame.ComputerRemoteBreachMedium";
      }
    }
  }
  
  return wrappedMethod(evt);
}

@wrapMethod(ScriptableDeviceComponentPS)
public const func GetMinigameDefinition() -> TweakDBID {
  let vanilla: TweakDBID = wrappedMethod();
  
  if !TDBID.IsValid(vanilla) {
    // Use proper Computer minigame ID (capitalized) - defaulting to Medium difficulty
    return t"Minigame.ComputerRemoteBreachMedium";
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
      // Use proper Computer minigame ID (capitalized) - defaulting to Medium difficulty
      minigameID = t"Minigame.ComputerRemoteBreachMedium";
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
            
            // Record breach position (always do this)
            RemoteBreachUtils.RecordBreachPosition(devicePS, this.GetGame());
            
            // Use Better Netrunning's existing radial unlock functions based on completed daemons
            if unlockFlags.unlockBasic {

                BNLog("[HackthePlanet -> BetterNetrunning] Unlocking nearby devices...");
                RemoteBreachUtils.UnlockDevicesInRadius(devicePS, this.GetGame());
                BNLog("[HackthePlanet -> BetterNetrunning] Devices unlocked");
            }
            
            if unlockFlags.unlockNPCs {
                BNLog("[HackthePlanet -> BetterNetrunning] Unlocking nearby npcs...");
                RemoteBreachUtils.UnlockNPCsInRange(devicePS, this.GetGame());
                BNLog("[HackthePlanet -> BetterNetrunning] NPCs unlocked...");
            }

            if BetterNetrunningSettings.EnableDebugLog() {
                BNLog("[HackthePlanet -> BetterNetrunning] Recorded virtual AP breach and triggered radial unlock for device: " +
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

  if BetterNetrunningSettings.EnableDebugLog() {
    BNLog(s"[HackthePlanet] Parsing unlock flags from \(ArraySize(activePrograms)) active programs");
  }

  let i: Int32 = 0;
  while i < ArraySize(activePrograms) {
    let programID: TweakDBID = activePrograms[i];
    
    if BetterNetrunningSettings.EnableDebugLog() {
      BNLog(s"[HackthePlanet] Program \(i): " + TDBID.ToStringDEBUG(programID));
    }

    // Check for BOTH vanilla and Better Netrunning program IDs
    
    // Basic/Root daemon
    if Equals(programID, t"MinigameAction.UnlockQuickhacks") || 
       Equals(programID, t"MinigameProgramAction.BN_RemoteBreach_UnlockBasic") {
      flags.unlockBasic = true;
      if BetterNetrunningSettings.EnableDebugLog() {
        BNLog("[HackthePlanet] Found Basic daemon");
      }
    } 
    // NPC daemon
    else if Equals(programID, t"MinigameAction.UnlockNPCQuickhacks") || 
            Equals(programID, t"MinigameProgramAction.BN_RemoteBreach_UnlockNPC") {
      flags.unlockNPCs = true;
      if BetterNetrunningSettings.EnableDebugLog() {
        BNLog("[HackthePlanet] Found NPC daemon");
      }
    } 
    // Camera daemon
    else if Equals(programID, t"MinigameAction.UnlockCameraQuickhacks") || 
            Equals(programID, t"MinigameProgramAction.BN_RemoteBreach_UnlockCamera") {
      flags.unlockCameras = true;
      if BetterNetrunningSettings.EnableDebugLog() {
        BNLog("[HackthePlanet] Found Camera daemon");
      }
    } 
    // Turret daemon
    else if Equals(programID, t"MinigameAction.UnlockTurretQuickhacks") || 
            Equals(programID, t"MinigameProgramAction.BN_RemoteBreach_UnlockTurret") {
      flags.unlockTurrets = true;
      if BetterNetrunningSettings.EnableDebugLog() {
        BNLog("[HackthePlanet] Found Turret daemon");
      }
    }

    i += 1;
  }

  if BetterNetrunningSettings.EnableDebugLog() {
    BNLog("[HackthePlanet] Unlock flags - Basic: " + ToString(flags.unlockBasic) +
          ", NPCs: " + ToString(flags.unlockNPCs) +
          ", Cameras: " + ToString(flags.unlockCameras) +
          ", Turrets: " + ToString(flags.unlockTurrets));
  }

  return flags;
}
