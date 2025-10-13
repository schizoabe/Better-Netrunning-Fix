
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
            RemoteBreachUtils.RecordBreachPosition(devicePS, this.GetGame());
            RemoteBreachUtils.UnlockNPCsInRange(devicePS, this.GetGame());

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
