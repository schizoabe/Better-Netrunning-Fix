module BetterNetrunning

import BetterNetrunningConfig.*

/*
 * Adds new daemons and controls where they are available
 * Optionally allows access to all daemons through access points
 * Optionally removes Datamine V1 and V2 daemons from access points
 */
@replaceMethod(MinigameGenerationRuleScalingPrograms)
public final func FilterPlayerPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {
  let data: ConnectedClassTypes;
  let i: Int32;
  let miniGameActionRecord: wref<MinigameAction_Record>;
  // let deviceHasBeenBreached: Bool; // Unused variable
  let connectedToNetwork: Bool;
  this.InjectBetterNetrunningPrograms(programs);
  // Store the entity being breached in the minigame blackboard, for use in the access point logic
  this.m_blackboardSystem.Get(GetAllBlackboardDefs().HackingMinigame).SetVariant(GetAllBlackboardDefs().HackingMinigame.Entity, ToVariant(this.m_entity));
  if (this.m_entity as GameObject).IsPuppet() {
    data = (this.m_entity as ScriptedPuppet).GetMasterConnectedClassTypes();
    // deviceHasBeenBreached = false;
    connectedToNetwork = true;
    //Log(NameToString((this.m_entity as ScriptedPuppet).GetPS().GetDeviceLink().GetParentDevice().GetClassName()));
  } else {
    data = (this.m_entity as Device).GetDevicePS().CheckMasterConnectedClassTypes();
    // deviceHasBeenBreached = (this.m_entity as Device).GetDevicePS().WasHackingMinigameSucceeded();
    connectedToNetwork = (this.m_entity as Device).GetDevicePS().IsConnectedToPhysicalAccessPoint();
  };
  i = ArraySize(Deref(programs)) - 1;
  while i >= 0 {
    miniGameActionRecord = TweakDBInterface.GetMinigameActionRecord(Deref(programs)[i].actionID);
    if !IsNameValid(Deref(programs)[i].programName) || Equals(Deref(programs)[i].programName, n"None") {
      ArrayErase(Deref(programs), i);
    } else {
      // Remove breaching programs when not connected to a network
      if !connectedToNetwork &&
        (Deref(programs)[i].actionID == t"MinigameAction.UnlockQuickhacks"
      || Deref(programs)[i].actionID == t"MinigameAction.UnlockNPCQuickhacks"
      || Deref(programs)[i].actionID == t"MinigameAction.UnlockCameraQuickhacks"
      || Deref(programs)[i].actionID == t"MinigameAction.UnlockTurretQuickhacks") {
        ArrayErase(Deref(programs), i);
      } else {
        // Device backdoor
        if (IsDefined(this.m_entity as Device) && !IsDefined(this.m_entity as AccessPoint)) &&
          (Deref(programs)[i].actionID == t"MinigameAction.NetworkDataMineLootAllMaster"
        || Deref(programs)[i].actionID == t"MinigameAction.UnlockNPCQuickhacks"
        || Deref(programs)[i].actionID == t"MinigameAction.UnlockTurretQuickhacks") {
          ArrayErase(Deref(programs), i);
        } else {
          // Access point
          if !BetterNetrunningSettings.AllowAllDaemonsOnAccessPoints() && !this.m_isRemoteBreach &&
             NotEquals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.AccessPoint)
          && Deref(programs)[i].actionID != t"MinigameAction.UnlockQuickhacks"
          && Deref(programs)[i].actionID != t"MinigameAction.UnlockNPCQuickhacks"
          && Deref(programs)[i].actionID != t"MinigameAction.UnlockCameraQuickhacks"
          && Deref(programs)[i].actionID != t"MinigameAction.UnlockTurretQuickhacks" {
            ArrayErase(Deref(programs), i);
          } else {
            // Non-netrunner NPC
            if this.m_isRemoteBreach && !(IsDefined(this.m_entity as ScriptedPuppet) && (this.m_entity as ScriptedPuppet).IsNetrunnerPuppet()) &&
              (Equals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.AccessPoint)
            || Deref(programs)[i].actionID == t"MinigameAction.UnlockCameraQuickhacks"
            || Deref(programs)[i].actionID == t"MinigameAction.UnlockTurretQuickhacks") {
              ArrayErase(Deref(programs), i);
            } else {
              if (Equals(miniGameActionRecord.Category().Type(), gamedataMinigameCategory.CameraAccess) || Deref(programs)[i].actionID == t"MinigameAction.UnlockCameraQuickhacks") && !data.surveillanceCamera {
                ArrayErase(Deref(programs), i);
              } else {
                if (Equals(miniGameActionRecord.Category().Type(), gamedataMinigameCategory.TurretAccess) || Deref(programs)[i].actionID == t"MinigameAction.UnlockTurretQuickhacks") && !data.securityTurret {
                  ArrayErase(Deref(programs), i);
                } else {
                  if (Equals(miniGameActionRecord.Type().Type(), gamedataMinigameActionType.NPC) || Deref(programs)[i].actionID == t"MinigameAction.UnlockNPCQuickhacks") && !data.puppet {
                    ArrayErase(Deref(programs), i);
                  } else {
                    // Disables lower-tier datamine daemons if disabled in the mod settings
                    if BetterNetrunningSettings.DisableDatamineOneTwo() && (Equals(Deref(programs)[i].actionID, t"MinigameAction.NetworkDataMineLootAllAdvanced") || Equals(Deref(programs)[i].actionID, t"MinigameAction.NetworkDataMineLootAll")) {
                      ArrayErase(Deref(programs), i);
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
    i -= 1;
  };
}

/*
 * Enables a cut feature that requires you to breach the network before you can use quickhacks
 * (Overrides TweakDB setting)
 */
@replaceMethod(NetworkSystem)
public final const func QuickHacksExposedByDefault() -> Bool {
  return false;
}

/*
 * Optionally removes turret disable quickhack
 */
@replaceMethod(SecurityTurretControllerPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
  let currentAction: ref<ScriptableDeviceAction>;
  if Equals(this.GetDurabilityState(), EDeviceDurabilityState.NOMINAL) {
    super.GetQuickHackActions(actions, context);
    currentAction = this.ActionSetDeviceAttitude();
    currentAction.SetObjectActionID(t"DeviceAction.TurretOverrideAttitudeClassLvl5Hack");
    currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
    currentAction.SetDurationValue(currentAction.GetDurationTime());
    currentAction.SetInactiveWithReason(this.IsON(), "LocKey#7005");
    currentAction.SetInactiveWithReason(this.IsAttitudeFromContextHostile(), "LocKey#7010");
    ArrayPush(actions, currentAction);
    currentAction = this.ActionSetDeviceAttitude();
    currentAction.SetObjectActionID(t"DeviceAction.TurretOverrideAttitudeClassHack");
    currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
    currentAction.SetDurationValue(currentAction.GetDurationTime());
    currentAction.SetInactiveWithReason(this.IsON(), "LocKey#7005");
    currentAction.SetInactiveWithReason(this.IsAttitudeFromContextHostile(), "LocKey#7010");
    ArrayPush(actions, currentAction);
    currentAction = this.ActionToggleTakeOverControl();
    currentAction.SetObjectActionID(t"DeviceAction.TakeControlClassHack");
    currentAction.SetInactiveWithReason(this.m_canPlayerTakeOverControl, "LocKey#7006");
    currentAction.SetInactiveWithReason(this.IsON(), "LocKey#7005");
    currentAction.SetInactiveWithReason(!PlayerPuppet.IsSwimming(GetPlayer(this.GetGameInstance())), "LocKey#7003");
    currentAction.SetInactiveWithReason(PlayerPuppet.GetSceneTier(GetPlayer(this.GetGameInstance())) <= 1, "LocKey#7003");
    ArrayPush(actions, currentAction);
    currentAction = this.ActionSetDeviceTagKillMode();
    currentAction.SetObjectActionID(t"DeviceAction.SetDeviceTagKillMode");
    currentAction.SetInactiveWithReason(!this.IsInTagKillMode(), "LocKey#7004");
    ArrayPush(actions, currentAction);
    if !BetterNetrunningSettings.BlockTurretDisableQuickhack() {
      currentAction = this.ActionQuickHackToggleON();
      currentAction.SetObjectActionID(t"DeviceAction.TurretToggleStateClassHack");
      currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
      currentAction.SetDurationValue(currentAction.GetDurationTime());
      currentAction.SetInactiveWithReason(this.IsOFFTimed(), "LocKey#7005");
      ArrayPush(actions, currentAction);
      currentAction = this.ActionQuickHackToggleON();
      currentAction.SetObjectActionID(t"DeviceAction.TurretToggleStateClassLvl2Hack");
      currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
      currentAction.SetDurationValue(currentAction.GetDurationTime());
      currentAction.SetInactiveWithReason(this.IsOFFTimed(), "LocKey#7005");
      ArrayPush(actions, currentAction);
      currentAction = this.ActionQuickHackToggleON();
      currentAction.SetObjectActionID(t"DeviceAction.TurretToggleStateClassLvl3Hack");
      currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
      currentAction.SetDurationValue(currentAction.GetDurationTime());
      currentAction.SetInactiveWithReason(this.IsOFFTimed(), "LocKey#7005");
      ArrayPush(actions, currentAction);
      currentAction = this.ActionQuickHackToggleON();
      currentAction.SetObjectActionID(t"DeviceAction.TurretToggleStateClassLvl4Hack");
      currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
      currentAction.SetDurationValue(currentAction.GetDurationTime());
      currentAction.SetInactiveWithReason(this.IsOFFTimed(), "LocKey#7005");
      ArrayPush(actions, currentAction);
      currentAction = this.ActionQuickHackToggleON();
      currentAction.SetObjectActionID(t"DeviceAction.TurretToggleStateClassLvl5Hack");
      currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
      currentAction.SetDurationValue(currentAction.GetDurationTime());
      currentAction.SetInactiveWithReason(this.IsOFFTimed(), "LocKey#7005");
      ArrayPush(actions, currentAction);
    }
  };
  this.FinalizeGetQuickHackActions(actions, context);
}

/*
 * Optionally removes camera disable quickhack
 */
@replaceMethod(SurveillanceCameraControllerPS)
protected func GetQuickHackActions(out actions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
  let currentAction: ref<ScriptableDeviceAction>;
  if Equals(this.GetDurabilityState(), EDeviceDurabilityState.NOMINAL) {
    super.GetQuickHackActions(actions, context);
    currentAction = this.ActionToggleTakeOverControl();
    currentAction.SetObjectActionID(t"DeviceAction.TakeControlCameraClassHack");
    currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
    currentAction.SetDurationValue(currentAction.GetDurationTime());
    currentAction.SetInactiveWithReason(this.m_canPlayerTakeOverControl && Equals(this.GetDurabilityState(), EDeviceDurabilityState.NOMINAL), "LocKey#7004");
    currentAction.SetInactiveWithReason(!PlayerPuppet.IsSwimming(GetPlayer(this.GetGameInstance())), "LocKey#7003");
    currentAction.SetInactiveWithReason(PlayerPuppet.GetSceneTier(GetPlayer(this.GetGameInstance())) <= 1, "LocKey#7003");
    ArrayPush(actions, currentAction);
    currentAction = this.ActionForceIgnoreTargets();
    currentAction.SetObjectActionID(t"DeviceAction.OverrideAttitudeClassHack");
    currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
    currentAction.SetDurationValue(currentAction.GetDurationTime());
    currentAction.SetInactiveWithReason(this.IsON(), "LocKey#7005");
    currentAction.SetInactiveWithReason(this.GetBehaviourCanDetectIntruders(), "LocKey#7007");
    currentAction.SetInactiveWithReason(this.IsAttitudeFromContextHostile(), "LocKey#7008");
    ArrayPush(actions, currentAction);
    currentAction = this.ActionForceIgnoreTargets();
    currentAction.SetObjectActionID(t"DeviceAction.OverrideAttitudeClassLvl3Hack");
    currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
    currentAction.SetDurationValue(currentAction.GetDurationTime());
    currentAction.SetInactiveWithReason(this.IsON(), "LocKey#7005");
    currentAction.SetInactiveWithReason(this.GetBehaviourCanDetectIntruders(), "LocKey#7007");
    currentAction.SetInactiveWithReason(this.IsAttitudeFromContextHostile(), "LocKey#7008");
    ArrayPush(actions, currentAction);
    currentAction = this.ActionForceIgnoreTargets();
    currentAction.SetObjectActionID(t"DeviceAction.OverrideAttitudeClassLvl4Hack");
    currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
    currentAction.SetDurationValue(currentAction.GetDurationTime());
    currentAction.SetInactiveWithReason(this.IsON(), "LocKey#7005");
    currentAction.SetInactiveWithReason(this.GetBehaviourCanDetectIntruders(), "LocKey#7007");
    currentAction.SetInactiveWithReason(this.IsAttitudeFromContextHostile(), "LocKey#7008");
    ArrayPush(actions, currentAction);
    currentAction = this.ActionForceIgnoreTargets();
    currentAction.SetObjectActionID(t"DeviceAction.OverrideAttitudeClassLvl5Hack");
    currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
    currentAction.SetDurationValue(currentAction.GetDurationTime());
    currentAction.SetInactiveWithReason(this.IsON(), "LocKey#7005");
    currentAction.SetInactiveWithReason(this.GetBehaviourCanDetectIntruders(), "LocKey#7007");
    currentAction.SetInactiveWithReason(this.IsAttitudeFromContextHostile(), "LocKey#7008");
    ArrayPush(actions, currentAction);
    if !BetterNetrunningSettings.BlockCameraDisableQuickhack() {
      currentAction = this.ActionQuickHackToggleON();
      currentAction.SetObjectActionID(t"DeviceAction.ToggleStateClassHack");
      currentAction.SetExecutor(GetPlayer(this.GetGameInstance()));
      currentAction.SetDurationValue(currentAction.GetDurationTime());
      ArrayPush(actions, currentAction);
    }
  };
  this.FinalizeGetQuickHackActions(actions, context);
}

/*
 * Controls which quickhacks are enabled on devices while network is not breached
 */
@addMethod(ScriptableDeviceComponentPS)
public final func SetActionsInactiveUnbreached(actions: script_ref<array<ref<DeviceAction>>>) -> Void {
  let sAction: ref<ScriptableDeviceAction>;
  let i: Int32 = 0;
  let isCamera: Bool = IsDefined(this as SurveillanceCameraControllerPS);
  let isTurret: Bool = IsDefined(this as SecurityTurretControllerPS);
  let allowCameras: Bool = ShouldUnlockHackDevice(this.GetGameInstance(), BetterNetrunningSettings.ProgressionAlwaysCameras(), BetterNetrunningSettings.ProgressionCyberdeckCameras(), BetterNetrunningSettings.ProgressionIntelligenceCameras());
  let allowTurrets: Bool = ShouldUnlockHackDevice(this.GetGameInstance(), BetterNetrunningSettings.ProgressionAlwaysTurrets(), BetterNetrunningSettings.ProgressionCyberdeckTurrets(), BetterNetrunningSettings.ProgressionIntelligenceTurrets());
  let allowBasicDevices: Bool = ShouldUnlockHackDevice(this.GetGameInstance(), BetterNetrunningSettings.ProgressionAlwaysBasicDevices(), BetterNetrunningSettings.ProgressionCyberdeckBasicDevices(), BetterNetrunningSettings.ProgressionIntelligenceBasicDevices());
  let allowPing: Bool = BetterNetrunningSettings.AlwaysAllowPing();
  let allowDistraction: Bool = BetterNetrunningSettings.AlwaysAllowDistract();
  while i < ArraySize(Deref(actions)) {
    sAction = (Deref(actions)[i] as ScriptableDeviceAction);
    if !(Equals(sAction.GetClassName(), n"PingDevice") && allowPing) &&
      !(Equals(sAction.GetClassName(), n"QuickHackDistraction") && allowDistraction) &&
      !(!(isCamera || isTurret) && allowBasicDevices) &&
      !(isCamera && allowCameras) &&
      !(isTurret && allowTurrets) {
      sAction.SetInactive();
      sAction.SetInactiveReason("LocKey#7021");
    };
    i += 1;
  };
}

@replaceMethod(ScriptableDeviceComponentPS)
protected final func FinalizeGetQuickHackActions(outActions: script_ref<array<ref<DeviceAction>>>, const context: script_ref<GetActionsContext>) -> Void {
  let currentAction: ref<ScriptableDeviceAction>;
  if NotEquals(this.GetDurabilityState(), EDeviceDurabilityState.NOMINAL) {
    return;
  };
  if this.m_disableQuickHacks {
    if ArraySize(Deref(outActions)) > 0 {
      ArrayClear(Deref(outActions));
    };
    return;
  };
  if this.IsConnectedToBackdoorDevice() {
    currentAction = this.ActionRemoteBreach();
    //currentAction.SetInactiveWithReason(!this.IsBreached(), "LocKey#27728");
    ArrayPush(Deref(outActions), currentAction);
    currentAction = this.ActionPing();
    currentAction.SetInactiveWithReason(!this.GetNetworkSystem().HasActivePing(this.GetMyEntityID()), "LocKey#49279");
    ArrayPush(Deref(outActions), currentAction);
  } else {
    if this.HasNetworkBackdoor() {
      currentAction = this.ActionPing();
      currentAction.SetInactiveWithReason(!this.GetNetworkSystem().HasActivePing(this.GetMyEntityID()), "LocKey#49279");
      ArrayPush(Deref(outActions), currentAction);
    };
  };
  if this.IsUnpowered() {
    ScriptableDeviceComponentPS.SetActionsInactiveAll(outActions, "LocKey#7013");
  };
  if !Deref(context).ignoresRPG {
    this.EvaluateActionsRPGAvailabilty(outActions, context);
    this.SetActionIllegality(outActions, this.m_illegalActions.quickHacks);
    this.MarkActionsAsQuickHacks(outActions);
    this.SetActionsQuickHacksExecutioner(outActions);
  };
}

@replaceMethod(ScriptableDeviceComponentPS)
public final func GetRemoteActions(out outActions: array<ref<DeviceAction>>, const context: script_ref<GetActionsContext>) -> Void {
  if this.m_disableQuickHacks || this.IsDisabled() {
    return;
  };
  this.GetQuickHackActions(outActions, context);
  if this.IsLockedViaSequencer() {
    ScriptableDeviceComponentPS.SetActionsInactiveAll(outActions, "LocKey#7021", n"RemoteBreach");
  } else {
    if !this.IsQuickHacksExposed() {
      this.SetActionsInactiveUnbreached(outActions);
    }
  }
}

/*
 * Enable quickhacks when device is not connected to access point
 */
@replaceMethod(DeviceComponentPS)
public final const func IsQuickHacksExposed() -> Bool {
  if (BetterNetrunningSettings.UnlockIfNoAccessPoint() && !this.IsConnectedToPhysicalAccessPoint()) {
    return true;
  }
  //Log("Device EntityID Hash: " + ToString(EntityID.GetHash(this.GetOwnerEntityWeak().GetEntityID())));
  if this.IsWhiteListedForHacks() {
    return true;
  }
  return this.m_exposeQuickHacks;
}

/*
 * Returns true if the current device should automatically have quickhacks unlocked (for use in cases when breaching is not possible, generally for quest reasons)
 */
@addMethod(DeviceComponentPS)
protected final func IsWhiteListedForHacks() -> Bool {
  // Could possibly have hash conflicts
  let entityIDHash: Uint32 = EntityID.GetHash(this.GetOwnerEntityWeak().GetEntityID());
  // Tutorial screen
  return Equals(entityIDHash, 3892895673u)
  // Tutorial camera
      || Equals(entityIDHash, 4150525907u)
  // Scav haunt door
      || Equals(entityIDHash, 244659214u)
  // "The Gift" surveillance camera
      || Equals(entityIDHash, 1323405640u);
}

/*
 * Enable quickhacks when NPC is not connected to access point
 */
@replaceMethod(ScriptedPuppetPS)
public final const func IsQuickHacksExposed() -> Bool {
  if Equals(this.GetOwnerEntity().GetAttitudeTowards(GetPlayer(this.GetGameInstance())), EAIAttitude.AIA_Friendly) {
    return false;
  };
  if !this.IsConnectedToAccessPoint() || (BetterNetrunningSettings.UnlockIfNoAccessPoint() && !this.GetDeviceLink().IsConnectedToPhysicalAccessPoint()) {
    return true;
  }
  if GetFact(this.GetGameInstance(), n"cheat_expose_npc_quick_hacks") > 0 {
    return true;
  };
  return this.m_quickHacksExposed;
}

/*
 * Allows quickhack menu to open when devices are not connected to an access point
 */
@replaceMethod(Device)
public const func CanRevealRemoteActionsWheel() -> Bool {
  return this.ShouldRegisterToHUD() && !this.GetDevicePS().IsDisabled() && this.GetDevicePS().HasPlaystyle(EPlaystyle.NETRUNNER);
}

/*
 * Controls which quickhacks are enabled on NPCs
 */
@replaceMethod(ScriptedPuppetPS)
public final const func GetAllChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>, puppetActions: script_ref<array<ref<PuppetAction>>>) -> Void {
  let actionType: gamedataObjectActionType;
  let isRemote: Bool;
  let puppetAction: ref<PuppetAction>;
  // let isBreached: Bool = this.IsBreached(); // Unused variable
  let isQuickHackExposed: Bool = this.IsQuickHacksExposed();
  let attiudeTowardsPlayer: EAIAttitude = this.GetOwnerEntity().GetAttitudeTowards(GetPlayer(this.GetGameInstance()));
  let isPuppetActive: Bool = ScriptedPuppet.IsActive(this.GetOwnerEntity());
  let instigator: wref<GameObject> = Deref(context).processInitiatorObject;
  let allowCovert: Bool = ShouldUnlockHackNPC(this.GetGameInstance(), this.GetOwnerEntityWeak(), BetterNetrunningSettings.ProgressionAlwaysNPCsCovert(), BetterNetrunningSettings.ProgressionCyberdeckNPCsCovert(), BetterNetrunningSettings.ProgressionIntelligenceNPCsCovert(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsCovert());
  let allowCombat: Bool = ShouldUnlockHackNPC(this.GetGameInstance(), this.GetOwnerEntityWeak(), BetterNetrunningSettings.ProgressionAlwaysNPCsCombat(), BetterNetrunningSettings.ProgressionCyberdeckNPCsCombat(), BetterNetrunningSettings.ProgressionIntelligenceNPCsCombat(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsCombat());
  let allowControl: Bool = ShouldUnlockHackNPC(this.GetGameInstance(), this.GetOwnerEntityWeak(), BetterNetrunningSettings.ProgressionAlwaysNPCsControl(), BetterNetrunningSettings.ProgressionCyberdeckNPCsControl(), BetterNetrunningSettings.ProgressionIntelligenceNPCsControl(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsControl());
  let allowUltimate: Bool = ShouldUnlockHackNPC(this.GetGameInstance(), this.GetOwnerEntityWeak(), BetterNetrunningSettings.ProgressionAlwaysNPCsUltimate(), BetterNetrunningSettings.ProgressionCyberdeckNPCsUltimate(), BetterNetrunningSettings.ProgressionIntelligenceNPCsUltimate(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsUltimate());
  let allowPing: Bool = (BetterNetrunningSettings.AlwaysAllowPing() || allowCovert);
  let allowWhistle: Bool = (BetterNetrunningSettings.AlwaysAllowWhistle() || allowCovert);
  let i: Int32 = 0;
  while i < ArraySize(Deref(actions)) {
    actionType = Deref(actions)[i].ObjectActionType().Type();
    switch actionType {
      case gamedataObjectActionType.Payment:
      case gamedataObjectActionType.Item:
      case gamedataObjectActionType.Direct:
        isRemote = false;
        break;
      case gamedataObjectActionType.MinigameUpload:
      case gamedataObjectActionType.VehicleQuickHack:
      case gamedataObjectActionType.PuppetQuickHack:
      case gamedataObjectActionType.DeviceQuickHack:
      case gamedataObjectActionType.Remote:
        isRemote = true;
        break;
      default:
        isRemote = false;
    };
    if isRemote && Equals(Deref(context).requestType, gamedeviceRequestType.Remote) {
      if !TweakDBInterface.GetBool(Deref(actions)[i].GetID() + t".isQuickHack", false) {
      } else {
        puppetAction = this.GetAction(Deref(actions)[i]);
        puppetAction.SetExecutor(instigator);
        puppetAction.RegisterAsRequester(PersistentID.ExtractEntityID(this.GetID()));
        puppetAction.SetObjectActionID(Deref(actions)[i].GetID());
        puppetAction.SetUp(this);
        if puppetAction.IsQuickHack() {
          //if (puppetAction as AccessBreach) != null && isBreached {
          //  puppetAction.SetInactiveWithReason(!isBreached, "LocKey#27728");
          //} else {
            // if !isQuickHackExposed && !isBreached && !this.IsWhiteListedForHacks() &&
            if !isQuickHackExposed && !this.IsWhiteListedForHacks() &&
              !(Equals(puppetAction.GetObjectActionRecord().HackCategory().EnumName(), n"CovertHack") && allowCovert) &&
              !(Equals(puppetAction.GetObjectActionRecord().HackCategory().EnumName(), n"DamageHack") && allowCombat) &&
              !(Equals(puppetAction.GetObjectActionRecord().HackCategory().EnumName(), n"ControlHack") && allowControl) &&
              !(Equals(puppetAction.GetObjectActionRecord().HackCategory().EnumName(), n"UltimateHack") && allowUltimate) &&
              !(IsDefined(puppetAction as PingSquad) && allowPing) &&
              !(Equals(puppetAction.GetObjectActionRecord().ActionName(), n"Whistle") && allowWhistle) {
              if NotEquals(attiudeTowardsPlayer, EAIAttitude.AIA_Friendly) {
                //puppetAction.SetInactiveWithReason(false, "LocKey#7017");
                puppetAction.SetInactiveWithReason(false, "LocKey#7021");
              } else {
                puppetAction.SetInactiveWithReason(false, "LocKey#27694");
              };
            } else {
              if !isPuppetActive || this.Sts_Ep1_12_ActiveForQHack_Hack() {
                puppetAction.SetInactiveWithReason(false, "LocKey#7018");
              };
            };
          //};
          ArrayPush(Deref(puppetActions), puppetAction);
        };
      };
    };
    i += 1;
  };
}

/*
 * Returns true if the current puppet should automatically have quickhacks unlocked (for use in cases when breaching is not possible, generally for quest reasons)
 */
@addMethod(ScriptedPuppetPS)
protected final func IsWhiteListedForHacks() -> Bool {
  let puppet: wref<ScriptedPuppet> = this.GetOwnerEntity() as ScriptedPuppet;
  let recordID: TweakDBID = puppet.GetRecordID();
  // Tutorial Fix: Courtesy of KiroKobra (AKA 'Phantum Jak' on Discord)
  return recordID == t"Character.q000_tutorial_course_01_patroller"
      || recordID == t"Character.q000_tutorial_course_02_enemy_02"
      || recordID == t"Character.q000_tutorial_course_02_enemy_03"
      || recordID == t"Character.q000_tutorial_course_02_enemy_04"
      || recordID == t"Character.q000_tutorial_course_03_guard_01"
      || recordID == t"Character.q000_tutorial_course_03_guard_02"
      || recordID == t"Character.q000_tutorial_course_03_guard_03";
}

/*
 * Prevents NPCs from being disconnected from the network when incapacitated
 */
@replaceMethod(ScriptedPuppet)
protected func OnIncapacitated() -> Void {
  let incapacitatedEvent: ref<IncapacitatedEvent>;
  // let link: ref<PuppetDeviceLinkPS>; // Unused variable
  if this.IsIncapacitated() {
    return;
  };
  if !StatusEffectSystem.ObjectHasStatusEffectWithTag(this, n"CommsNoiseIgnore") {
    incapacitatedEvent = new IncapacitatedEvent();
    GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, incapacitatedEvent, 0.50);
  };
  this.m_securitySupportListener = null;
  //this.RemoveLink();
  this.EnableLootInteractionWithDelay(this);
  this.EnableInteraction(n"Grapple", false);
  this.EnableInteraction(n"TakedownLayer", false);
  this.EnableInteraction(n"AerialTakedown", false);
  this.EnableInteraction(n"NewPerkFinisherLayer", false);
  StatusEffectHelper.RemoveAllStatusEffectsByType(this, gamedataStatusEffectType.Cloaked);
  if this.IsBoss() {
    this.EnableInteraction(n"BossTakedownLayer", false);
  } else {
    if this.IsMassive() {
      this.EnableInteraction(n"MassiveTargetTakedownLayer", false);
    };
  };
  this.RevokeAllTickets();
  this.GetSensesComponent().ToggleComponent(false);
  this.GetBumpComponent().Toggle(false);
  this.UpdateQuickHackableState(false);
  if this.IsPerformingCallReinforcements() {
    this.HidePhoneCallDuration(gamedataStatPoolType.CallReinforcementProgress);
  };
  this.GetPuppetPS().SetWasIncapacitated(true);
  /*link = this.GetDeviceLink();
  if IsDefined(link) {
    link.NotifyAboutSpottingPlayer(false);
    GameInstance.GetPersistencySystem(this.GetGame()).QueuePSEvent(link.GetID(), link.GetClassName(), new DestroyLink());
  };*/
  this.ProcessQuickHackQueueOnDefeat();
  CachedBoolValue.SetDirty(this.m_isActiveCached);
}

/*
 * Removes NPCs from network upon death
 * (maybe unnecessary, added to prevent possible bugs)
 */
@replaceMethod(ScriptedPuppet)
protected func OnDied() -> Void {
  let link: ref<PuppetDeviceLinkPS>;
  StatusEffectHelper.RemoveStatusEffect(this, t"BaseStatusEffect.Defeated");
  this.GetPuppetPS().SetIsDead(true);
  this.OnIncapacitated();
  this.RemoveLink();
  link = this.GetDeviceLink() as PuppetDeviceLinkPS;
  if IsDefined(link) {
    link.NotifyAboutSpottingPlayer(false);
    GameInstance.GetPersistencySystem(this.GetGame()).QueuePSEvent(link.GetID(), link.GetClassName(), new DestroyLink());
  };
  CachedBoolValue.SetDirty(this.m_isActiveCached);
  QuickHackableQueueHelper.RemoveQuickhackQueue(this.m_gameplayRoleComponent, this.m_currentlyUploadingAction);
}

@addMethod(DeviceComponentPS)
public final func IsConnectedToPhysicalAccessPoint() -> Bool {
  let sharedGameplayPS: ref<SharedGameplayPS> = this as SharedGameplayPS;
  if !IsDefined(sharedGameplayPS) {
    return false;
  }

  let apControllers: array<ref<AccessPointControllerPS>> = sharedGameplayPS.GetAccessPoints();
  return ArraySize(apControllers) > 0;

  // Original method that checks for actual access points instead of just any AP controller
  // for currentAPController in apControllers {
  //   let children: array<ref<DeviceComponentPS>>;
  //   currentAPController.GetChildren(children);
  //   for childDevice in children {
  //     if IsDefined(childDevice.GetOwnerEntityWeak() as AccessPoint) {
  //       return true;
  //     }
  //   }
  // }
}

/*
 * Used to control the unlocking of quickhacks after performing a network breach
 */
@wrapMethod(ScriptedPuppetPS)
public final const func GetValidChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>, objectActionsCallbackController: wref<gameObjectActionsCallbackController>, checkPlayerQuickHackList: Bool, choices: script_ref<array<InteractionChoice>>) -> Void {
	if BetterNetrunningSettings.AllowBreachingUnconsciousNPCs() && this.IsConnectedToAccessPoint() && (!BetterNetrunningSettings.UnlockIfNoAccessPoint() || this.GetDeviceLink().IsConnectedToPhysicalAccessPoint()) && !this.m_betterNetrunningWasDirectlyBreached {
    ArrayPush(Deref(actions), TweakDBInterface.GetObjectActionRecord(t"Takedown.BreachUnconsciousOfficer"));
  }
	wrappedMethod(actions, context, objectActionsCallbackController, checkPlayerQuickHackList, choices);
}

@addField(ScriptedPuppetPS)
public persistent let m_betterNetrunningWasDirectlyBreached: Bool;

@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedBasic: Bool;

@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedNPCs: Bool;

@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedCameras: Bool;

@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedTurrets: Bool;

/*
 * Used to control the unlocking of quickhacks after performing a network breach
 */
@replaceMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  let baseMoney: Float;
  let baseShardDropChance: Float;
  let craftingMaterial: Bool;
  let i: Int32;
  let lootAllAdvancedID: TweakDBID;
  let lootAllID: TweakDBID;
  let lootAllMasterID: TweakDBID;
  let lootQ003: TweakDBID;
  let markForErase: Bool;
  let shouldLoot: Bool;
  let TS: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
  let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().HackingMinigame);
  let minigamePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms));
  this.CheckMasterRunnerAchievement(ArraySize(minigamePrograms));
  this.FilterRedundantPrograms(minigamePrograms);
  lootQ003 = t"MinigameAction.NetworkLootQ003";
  lootAllID = t"MinigameAction.NetworkDataMineLootAll";
  lootAllAdvancedID = t"MinigameAction.NetworkDataMineLootAllAdvanced";
  lootAllMasterID = t"MinigameAction.NetworkDataMineLootAllMaster";
  let basicAccessID: TweakDBID = t"MinigameAction.UnlockQuickhacks";
  let cameraAccessID: TweakDBID = t"MinigameAction.UnlockCameraQuickhacks";
  let turretAccessID: TweakDBID = t"MinigameAction.UnlockTurretQuickhacks";
  let npcAccessID: TweakDBID = t"MinigameAction.UnlockNPCQuickhacks";
  let unlockDeviceQuickhacks: Bool = false;
  let unlockCameraQuickhacks: Bool = false;
  let unlockTurretQuickhacks: Bool = false;
  let unlockNPCQuickhacks: Bool = false;
  baseMoney = 0.00;
  craftingMaterial = false;
  baseShardDropChance = 0.00;
  i = ArraySize(minigamePrograms) - 1;
  while i >= 0 {
    if minigamePrograms[i] == t"minigame_v2.FindAnna" {
      AddFact(this.GetPlayerMainObject().GetGame(), n"Kab08Minigame_program_uploaded");
    } else {
      if minigamePrograms[i] == lootQ003 {
        TS.GiveItemByItemQuery(this.GetPlayerMainObject(), t"Query.Q003CyberdeckProgram");
      } else {
        if minigamePrograms[i] == lootAllID || minigamePrograms[i] == lootAllAdvancedID || minigamePrograms[i] == lootAllMasterID {
          if minigamePrograms[i] == lootAllID {
            baseMoney += 1.00;
          } else {
            if minigamePrograms[i] == lootAllAdvancedID {
              baseMoney += 1.00;
              craftingMaterial = true;
            } else {
              if minigamePrograms[i] == lootAllMasterID {
                baseShardDropChance += 1.00;
              };
            };
          };
          shouldLoot = true;
          markForErase = true;
        } else {
          if minigamePrograms[i] == basicAccessID {
            unlockDeviceQuickhacks = true;
          } else if minigamePrograms[i] == npcAccessID {
            unlockNPCQuickhacks = true;
          } else if minigamePrograms[i] == cameraAccessID {
            unlockCameraQuickhacks = true;
          } else if minigamePrograms[i] == turretAccessID {
            unlockTurretQuickhacks = true;
          }
        }
      };
    };
    i -= 1;
  };
  if markForErase {
    ArrayErase(minigamePrograms, i);
    minigameBB.SetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms, ToVariant(minigamePrograms));
  };
  if shouldLoot {
    this.ProcessLoot(baseMoney, craftingMaterial, baseShardDropChance, TS);
  };
  this.ProcessMinigameNetworkActions(this);
  i = 0;
  // Extract the entity that was breached
  let entity: wref<Entity> = FromVariant<wref<Entity>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity));
  if IsDefined(entity as ScriptedPuppet) {
    (entity as ScriptedPuppet).GetPS().m_betterNetrunningWasDirectlyBreached = true;
  }
  /*let entityIsPuppet: Bool = IsDefined(entity as ScriptedPuppet);
  let puppetSquad: array<wref<Entity>>;
  if entityIsPuppet {
    let squadInterface: ref<SquadScriptInterface>;
    AISquadHelper.GetSquadMemberInterface((entity as ScriptedPuppet), squadInterface);
    puppetSquad = squadInterface.ListMembersWeak();
  }*/
  //Log("BREACHED THROUGH: " + NameToString(entity.GetClassName()));
  let setBreachedSubnetEvent: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  setBreachedSubnetEvent.breachedBasic = unlockDeviceQuickhacks;
  setBreachedSubnetEvent.breachedNPCs = unlockNPCQuickhacks;
  setBreachedSubnetEvent.breachedCameras = unlockCameraQuickhacks;
  setBreachedSubnetEvent.breachedTurrets = unlockTurretQuickhacks;
  while i < ArraySize(Deref(devices)) {
    if BetterNetrunningSettings.EnableClassicMode() {
      this.QueuePSEvent(Deref(devices)[i], this.ActionSetExposeQuickHacks());
    } else if IsDefined(Deref(devices)[i] as PuppetDeviceLinkPS) || IsDefined(Deref(devices)[i] as CommunityProxyPS) {
      if unlockNPCQuickhacks {
        this.QueuePSEvent(Deref(devices)[i], this.ActionSetExposeQuickHacks());
      }
    } else if IsDefined(Deref(devices)[i].GetOwnerEntityWeak() as SurveillanceCamera) {
      if unlockCameraQuickhacks {
        this.QueuePSEvent(Deref(devices)[i], this.ActionSetExposeQuickHacks());
      }
    } else if IsDefined(Deref(devices)[i].GetOwnerEntityWeak() as SecurityTurret) {
      if unlockTurretQuickhacks {
        this.QueuePSEvent(Deref(devices)[i], this.ActionSetExposeQuickHacks());
      }
    } else {
      if unlockDeviceQuickhacks {
        this.QueuePSEvent(Deref(devices)[i], this.ActionSetExposeQuickHacks());
      }
    }
    this.ProcessMinigameNetworkActions(Deref(devices)[i]);
    this.QueuePSEvent(Deref(devices)[i], setBreachedSubnetEvent);
    i += 1;
  };
  if baseMoney >= 1.00 && this.ShouldRewardMoney() {
    this.RewardMoney(baseMoney);
  };
  RPGManager.GiveReward(this.GetGameInstance(), t"RPGActionRewards.Hacking", Cast<StatsObjectID>(this.GetMyEntityID()));
}

@addMethod(MinigameGenerationRuleScalingPrograms)
public final func InjectBetterNetrunningPrograms(programs: script_ref<array<MinigameProgramData>>) -> Void {
  if BetterNetrunningSettings.EnableClassicMode() {
    return;
  }
  let device: ref<SharedGameplayPS>;
  if IsDefined(this.m_entity as ScriptedPuppet) {
    //accessPoint = (this.m_entity as ScriptedPuppet).GetPS().GetAccessPoint().GetMainframe();
    device = (this.m_entity as ScriptedPuppet).GetPS().GetDeviceLink()/*.GetParentDevice().GetBackdoorAccessPoint().GetMainframe()*/;
  } else {
    device = (this.m_entity as Device).GetDevicePS()/*.GetBackdoorAccessPoint().GetMainframe()*/;
  }
  if !device.m_betterNetrunningBreachedTurrets {
    let turretAccessProgram: MinigameProgramData;
    turretAccessProgram.actionID = t"MinigameAction.UnlockTurretQuickhacks";
    turretAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, turretAccessProgram);
  }
  if !device.m_betterNetrunningBreachedCameras {
    let cameraAccessProgram: MinigameProgramData;
    cameraAccessProgram.actionID = t"MinigameAction.UnlockCameraQuickhacks";
    cameraAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, cameraAccessProgram);
  }
  if !device.m_betterNetrunningBreachedNPCs {
    let npcAccessProgram: MinigameProgramData;
    npcAccessProgram.actionID = t"MinigameAction.UnlockNPCQuickhacks";
    npcAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, npcAccessProgram);
  }
  if !device.m_betterNetrunningBreachedBasic {
    let basicAccessProgram: MinigameProgramData;
    basicAccessProgram.actionID = t"MinigameAction.UnlockQuickhacks";
    basicAccessProgram.programName = n"LocKey#34844";
    ArrayInsert(Deref(programs), 0, basicAccessProgram);
  }
  /*let cameraShutdown: MinigameProgramData;
  cameraShutdown.actionID = t"MinigameAction.NetworkCameraShutdown";
  cameraShutdown.programName = n"LocKey#34844";
  ArrayPush(Deref(programs), cameraShutdown);*/
}

/*
 * Gets the top-level access point on the network
 */
@addMethod(AccessPointControllerPS)
public func GetMainframe() -> ref<AccessPointControllerPS> {
  let parents: array<ref<DeviceComponentPS>>;
  this.GetParents(parents);
  let i: Int32 = 0;
  while i < ArraySize(parents) {
    if IsDefined(parents[i] as AccessPointControllerPS) {
      return (parents[i] as AccessPointControllerPS).GetMainframe();
    };
    i += 1;
  };
  return this;
}

/*
 * Still allow device daemons to be uploaded when all devices of that type are disabled
 */
@replaceMethod(AccessPointControllerPS)
public final const func CheckConnectedClassTypes() -> ConnectedClassTypes {
  let data: ConnectedClassTypes;
  let puppet: ref<GameObject>;
  let slaves: array<ref<DeviceComponentPS>> = this.GetImmediateSlaves();
  let i: Int32 = 0;
  while i < ArraySize(slaves) {
    //Log("AP Slave: " + NameToString(slaves[i].GetClassName()));
    if data.surveillanceCamera && data.securityTurret && data.puppet {
      break;
    };
    //if IsDefined(slaves[i] as ScriptableDeviceComponentPS) && (!(slaves[i] as ScriptableDeviceComponentPS).IsON() || (slaves[i] as ScriptableDeviceComponentPS).IsBroken()) {
    //} else {
      if !data.surveillanceCamera && IsDefined(slaves[i] as SurveillanceCameraControllerPS) {
        data.surveillanceCamera = true;
      } else {
        if !data.securityTurret && IsDefined(slaves[i] as SecurityTurretControllerPS) {
          data.securityTurret = true;
        } else {
          if !data.puppet && IsDefined(slaves[i] as PuppetDeviceLinkPS) {
            puppet = slaves[i].GetOwnerEntityWeak() as GameObject;
            if IsDefined(puppet) && puppet.IsActive() {
              data.puppet = true;
            };
          };
        };
      };
    //};
    i += 1;
  };
  return data;
}

/*
 * Prevent failed puppet breach from alerting enemies
 */
@replaceMethod(ScriptedPuppet)
protected cb func OnAccessPointMiniGameStatus(evt: ref<AccessPointMiniGameStatus>) -> Bool {
  let easeOutCurve: CName;
  let emptyID: EntityID;
  let deviceLink: ref<PuppetDeviceLinkPS> = this.GetDeviceLink();
  if IsDefined(deviceLink) {
    deviceLink.PerformNPCBreach(evt.minigameState);
    /*if Equals(evt.minigameState, HackingMinigameState.Failed) {
      deviceLink.TriggerSecuritySystemNotification(this.GetWorldPosition(), GameInstance.GetPlayerSystem(this.GetGame()).GetLocalPlayerControlledGameObject() as PlayerPuppet, ESecurityNotificationType.ALARM);
    };*/
  };
  this.GetNetworkBlackboard().SetString(this.GetNetworkBlackboardDef().NetworkName, "");
  this.GetNetworkBlackboard().SetEntityID(this.GetNetworkBlackboardDef().DeviceID, emptyID);
  easeOutCurve = TweakDBInterface.GetCName(t"timeSystem.nanoWireBreach.easeOutCurve", n"DiveEaseOut");
  GameInstance.GetTimeSystem(this.GetGame()).UnsetTimeDilation(n"NetworkBreach", easeOutCurve);
  QuickhackModule.RequestRefreshQuickhackMenu(this.GetGame(), this.GetEntityID());
}

public func CyberdeckQualityFromConfigValue(value: Int32) -> gamedataQuality {
  switch(value) {
    case 2:
      return gamedataQuality.CommonPlus;
    case 3:
      return gamedataQuality.Uncommon;
    case 4:
      return gamedataQuality.UncommonPlus;
    case 5:
      return gamedataQuality.Rare;
    case 6:
      return gamedataQuality.RarePlus;
    case 7:
      return gamedataQuality.Epic;
    case 8:
      return gamedataQuality.EpicPlus;
    case 9:
      return gamedataQuality.Legendary;
    case 10:
      return gamedataQuality.LegendaryPlus;
    case 11:
      return gamedataQuality.LegendaryPlusPlus;
  }
  return gamedataQuality.Invalid;
}

/*
 * Required because CDPR changed the enum values so they are no longer in order from lowest to highest (WHY!?!)
 */
public func CyberdeckQualityToRank(quality: gamedataQuality) -> Int32 {
  switch(quality) {
    case gamedataQuality.Common:
      return 1;
    case gamedataQuality.CommonPlus:
      return 2;
    case gamedataQuality.Uncommon:
      return 3;
    case gamedataQuality.UncommonPlus:
      return 4;
    case gamedataQuality.Rare:
      return 5;
    case gamedataQuality.RarePlus:
      return 6;
    case gamedataQuality.Epic:
      return 7;
    case gamedataQuality.EpicPlus:
      return 8;
    case gamedataQuality.Legendary:
      return 9;
    case gamedataQuality.LegendaryPlus:
      return 10;
    case gamedataQuality.LegendaryPlusPlus:
      return 11;
  }
  return 0;
}

public func CyberdeckConditionMet(gameInstance: GameInstance, value: Int32) -> Bool {
  let systemReplacementID: ItemID = EquipmentSystem.GetData(GetPlayer(gameInstance)).GetActiveItem(gamedataEquipmentArea.SystemReplacementCW);
  let itemRecord: wref<Item_Record> = RPGManager.GetItemRecord(systemReplacementID);
  let playerCyberdeckQuality: gamedataQuality = itemRecord.Quality().Type();
  let minQuality: gamedataQuality = CyberdeckQualityFromConfigValue(value);
  return CyberdeckQualityToRank(playerCyberdeckQuality) >= CyberdeckQualityToRank(minQuality);
}

public func CyberdeckConditionEnabled(value: Int32) -> Bool {
  return value > 1;
}

public func IntelligenceConditionMet(gameInstance: GameInstance, value: Int32) -> Bool {
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(gameInstance);
  let playerIntelligence: Int32 = Cast(statsSystem.GetStatValue(Cast(GetPlayer(gameInstance).GetEntityID()), gamedataStatType.Intelligence));
  return playerIntelligence >= value;
}

public func IntelligenceConditionEnabled(value: Int32) -> Bool {
  return value > 3;
}

public func NPCRarityToRank(rarity: gamedataNPCRarity) -> Int32 {
  switch rarity {
    case gamedataNPCRarity.Trash:
      return 1;
    case gamedataNPCRarity.Weak:
      return 2;
    case gamedataNPCRarity.Normal:
      return 3;
    case gamedataNPCRarity.Rare:
      return 4;
    case gamedataNPCRarity.Officer:
      return 5;
    case gamedataNPCRarity.Elite:
      return 6;
    case gamedataNPCRarity.Boss:
      return 7;
    case gamedataNPCRarity.MaxTac:
      return 8;
  }
  return 0;
}

public func EnemyRarityConditionMet(gameInstance: GameInstance, enemy: wref<Entity>, value: Int32) -> Bool {
  let puppet: wref<ScriptedPuppet> = enemy as ScriptedPuppet;
  if !IsDefined(puppet) {
    return false;
  }
  let rarity: gamedataNPCRarity = puppet.GetNPCRarity();
  // Unlock when enemy rarity rank is less than or equal to configured rank (inclusive)
  return NPCRarityToRank(rarity) <= value;
}

public func EnemyRarityConditionEnabled(value: Int32) -> Bool {
  return value < 8;
}

public func ShouldUnlockHackNPC(gameInstance: GameInstance, enemy: wref<Entity>, alwaysAllow: Bool, cyberdeckValue: Int32, intelligenceValue: Int32, enemyRarityValue: Int32) -> Bool {
  if alwaysAllow {
    return true;
  }
  let useConditionCyberdeck: Bool = CyberdeckConditionEnabled(cyberdeckValue);
  let useConditionIntelligence: Bool = IntelligenceConditionEnabled(intelligenceValue);
  let useConditionEnemyRarity: Bool = EnemyRarityConditionEnabled(enemyRarityValue);
  if !useConditionCyberdeck && !useConditionIntelligence && !useConditionEnemyRarity {
    return false;
  }
  let requireAll: Bool = BetterNetrunningSettings.ProgressionRequireAll();
  let conditionCyberdeck: Bool = CyberdeckConditionMet(gameInstance, cyberdeckValue);
  let conditionIntelligence: Bool = IntelligenceConditionMet(gameInstance, intelligenceValue);
  let conditionEnemyRarity: Bool = EnemyRarityConditionMet(gameInstance, enemy, enemyRarityValue);
  if requireAll {
    return (!useConditionCyberdeck || conditionCyberdeck) && (!useConditionIntelligence || conditionIntelligence) && (!useConditionEnemyRarity || conditionEnemyRarity);
  } else {
    return (useConditionCyberdeck && conditionCyberdeck) || (useConditionIntelligence && conditionIntelligence) || (useConditionEnemyRarity && conditionEnemyRarity);
  }
}

public func ShouldUnlockHackDevice(gameInstance: GameInstance, alwaysAllow: Bool, cyberdeckValue: Int32, intelligenceValue: Int32) -> Bool {
  if alwaysAllow {
    return true;
  }
  let useConditionCyberdeck: Bool = CyberdeckConditionEnabled(cyberdeckValue);
  let useConditionIntelligence: Bool = IntelligenceConditionEnabled(intelligenceValue);
  if !useConditionCyberdeck && !useConditionIntelligence {
    return false;
  }
  let requireAll: Bool = BetterNetrunningSettings.ProgressionRequireAll();
  let conditionCyberdeck: Bool = CyberdeckConditionMet(gameInstance, cyberdeckValue);
  let conditionIntelligence: Bool = IntelligenceConditionMet(gameInstance, intelligenceValue);
  if requireAll {
    return (!useConditionCyberdeck || conditionCyberdeck) && (!useConditionIntelligence || conditionIntelligence);
  } else {
    return (useConditionCyberdeck && conditionCyberdeck) || (useConditionIntelligence && conditionIntelligence);
  }
}

public class SetBreachedSubnet extends ActionBool {

  public let breachedBasic: Bool;
  public let breachedNPCs: Bool;
  public let breachedCameras: Bool;
  public let breachedTurrets: Bool;

  public final func SetProperties() -> Void {
    this.actionName = n"SetBreachedSubnet";
    this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(this.actionName, true, n"SetBreachedSubnet", n"SetBreachedSubnet");
  }

  public func GetTweakDBChoiceRecord() -> String {
    return "SetBreachedSubnet";
  }

  public final static func IsAvailable(device: ref<ScriptableDeviceComponentPS>) -> Bool {
    //return device.IsPowered();
    return true;
  }

  public final static func IsClearanceValid(clearance: ref<Clearance>) -> Bool {
    if Clearance.IsInRange(clearance, 2) {
      return true;
    };
    return false;
  }

  public final static func IsContextValid(const context: script_ref<GetActionsContext>) -> Bool {
    if Equals(Deref(context).requestType, gamedeviceRequestType.Direct) {
      return true;
    };
    return false;
  }

}

@addMethod(SharedGameplayPS)
public func OnSetBreachedSubnet(evt: ref<SetBreachedSubnet>) -> EntityNotificationType {
  if evt.breachedBasic {
    this.m_betterNetrunningBreachedBasic = true;
  }
  if evt.breachedNPCs {
    this.m_betterNetrunningBreachedNPCs = true;
  }
  if evt.breachedCameras {
    this.m_betterNetrunningBreachedCameras = true;
  }
  if evt.breachedTurrets {
    this.m_betterNetrunningBreachedTurrets = true;
  }
  return EntityNotificationType.SendThisEventToEntity;
  //return EntityNotificationType.DoNotNotifyEntity;
}