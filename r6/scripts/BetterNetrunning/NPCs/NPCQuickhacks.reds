module BetterNetrunning.NPCs

import BetterNetrunningConfig.*
import BetterNetrunning.Common.*
import BetterNetrunning.Progression.*

/*
 * ============================================================================
 * NPC QUICKHACKS MODULE
 * ============================================================================
 *
 * PURPOSE:
 * Controls NPC quickhack availability based on breach status and player
 * progression requirements.
 *
 * FUNCTIONALITY:
 * - Progressive unlock system (Cyberdeck tier, Intelligence stat, Enemy Rarity)
 * - Network isolation detection -> auto-unlock for isolated NPCs
 * - Category-based restrictions (Covert, Combat, Control, Ultimate)
 * - Special always-allowed quickhacks (Ping, Whistle)
 * - Tutorial NPC whitelist (bypass progression for tutorial flow)
 *
 * ARCHITECTURE:
 * - Shallow nesting (max 2 levels) using Extract Method pattern
 * - Continue Pattern for cleaner control flow
 *
 * ============================================================================
 */

/*
 * Controls NPC quickhack availability based on breach status and progression
 *
 * VANILLA DIFF: Complete rewrite to implement progressive unlock system
 * - Progressive unlock via ShouldUnlockHackNPC() (checks Cyberdeck tier, Intelligence, Enemy Rarity)
 * - Network isolation detection -> auto-unlock for isolated NPCs
 * - Category-based restrictions (Covert, Combat, Control, Ultimate, Ping, Whistle)
 *
 * ARCHITECTURE: Shallow nesting (max 2 levels) using Continue Pattern + Extract Method
 */
@replaceMethod(ScriptedPuppetPS)
public final const func GetAllChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>, puppetActions: script_ref<array<ref<PuppetAction>>>) -> Void {
  // Step 1: Calculate NPC permissions (breach state + progression)
  let permissions: NPCHackPermissions = this.CalculateNPCHackPermissions();

  // Step 2: Get activity state
  let isPuppetActive: Bool = ScriptedPuppet.IsActive(this.GetOwnerEntity());
  let attiudeTowardsPlayer: EAIAttitude = this.GetOwnerEntity().GetAttitudeTowards(GetPlayer(this.GetGameInstance()));
  let instigator: wref<GameObject> = Deref(context).processInitiatorObject;

  // Step 3: Process all actions
  let i: Int32 = 0;
  while i < ArraySize(Deref(actions)) {
    // Early skip: Not a remote quickhack
    if this.IsRemoteQuickHackAction(Deref(actions)[i], context) {
      // Process quickhack action
      this.ProcessQuickhackAction(Deref(actions)[i], instigator, permissions, isPuppetActive, attiudeTowardsPlayer, puppetActions);
    }
    i += 1;
  }
}

// Helper: Process a single quickhack action (reduced nesting)
@addMethod(ScriptedPuppetPS)
private final func ProcessQuickhackAction(
  action: wref<ObjectAction_Record>,
  instigator: wref<GameObject>,
  permissions: NPCHackPermissions,
  isPuppetActive: Bool,
  attiudeTowardsPlayer: EAIAttitude,
  puppetActions: script_ref<array<ref<PuppetAction>>>
) -> Void {
  let puppetAction: ref<PuppetAction> = this.CreatePuppetAction(action, instigator);

  // Early skip: Not a quickhack
  if !puppetAction.IsQuickHack() {
    return;
  }

  // Apply progressive unlock restrictions
  if this.ShouldQuickhackBeInactive(puppetAction, permissions) {
    this.SetQuickhackInactiveReason(puppetAction, attiudeTowardsPlayer);
  } else if !isPuppetActive || this.Sts_Ep1_12_ActiveForQHack_Hack() {
    puppetAction.SetInactiveWithReason(false, "LocKey#7018");
  }

  ArrayPush(Deref(puppetActions), puppetAction);
}

// ==================== Permission Calculation ====================

// Helper: Calculates NPC hack permissions based on breach state and progression



@addMethod(ScriptedPuppetPS)
private final func CalculateNPCHackPermissions() -> NPCHackPermissions {
  let permissions: NPCHackPermissions;
  let gameInstance: GameInstance = this.GetGameInstance();
  let npc: wref<GameObject> = this.GetOwnerEntityWeak() as GameObject;
  let puppet: wref<ScriptedPuppet> = this.GetOwnerEntity() as ScriptedPuppet;

  // Check breach status (m_quickHacksExposed is breach state, not menu visibility)
  permissions.isBreached = this.m_quickHacksExposed;

  // Check if NPC is connected to any network
  let isConnectedToNetwork: Bool = this.IsConnectedToAccessPoint();

  // Auto-unlock if not connected to any network (isolated enemies)
/*   if !isConnectedToNetwork {
    permissions.isBreached = true;
  } */

  // Evaluate progression-based unlock conditions for hack categories
  permissions.allowCovert = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsCovert(), BetterNetrunningSettings.ProgressionCyberdeckNPCsCovert(), BetterNetrunningSettings.ProgressionIntelligenceNPCsCovert(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsCovert());
  permissions.allowCombat = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsCombat(), BetterNetrunningSettings.ProgressionCyberdeckNPCsCombat(), BetterNetrunningSettings.ProgressionIntelligenceNPCsCombat(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsCombat());
  permissions.allowControl = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsControl(), BetterNetrunningSettings.ProgressionCyberdeckNPCsControl(), BetterNetrunningSettings.ProgressionIntelligenceNPCsControl(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsControl());
  permissions.allowUltimate = ShouldUnlockHackNPC(gameInstance, npc, BetterNetrunningSettings.AlwaysNPCsUltimate(), BetterNetrunningSettings.ProgressionCyberdeckNPCsUltimate(), BetterNetrunningSettings.ProgressionIntelligenceNPCsUltimate(), BetterNetrunningSettings.ProgressionEnemyRarityNPCsUltimate());
  permissions.allowPing = BetterNetrunningSettings.AlwaysAllowPing() || permissions.allowCovert;
  permissions.allowWhistle = BetterNetrunningSettings.AlwaysAllowWhistle() || permissions.allowCovert;

  if IsDefined(puppet) && (puppet.IsCrowd() || puppet.IsVendor()) {
      // Crowds/vendors REQUIRE breach (no auto-unlock from progression)
      // Only breach status unlocks their hacks
      if !permissions.isBreached {
          permissions.allowCovert = false;
          permissions.allowCombat = false;
          permissions.allowControl = false;
          permissions.allowUltimate = false;
          permissions.allowPing = BetterNetrunningSettings.AlwaysAllowPing() || permissions.allowCovert;
          permissions.allowWhistle = BetterNetrunningSettings.AlwaysAllowWhistle() || permissions.allowCovert;
      };
  };


  return permissions;
}





//pierre

// ==================== Action Processing ====================

// Helper: Checks if action is a remote quickhack type
@addMethod(ScriptedPuppetPS)
private final func IsRemoteQuickHackAction(action: wref<ObjectAction_Record>, const context: script_ref<GetActionsContext>) -> Bool {
  if !Equals(Deref(context).requestType, gamedeviceRequestType.Remote) {
    return false;
  }
  let actionType: gamedataObjectActionType = action.ObjectActionType().Type();
  let isRemoteType: Bool = Equals(actionType, gamedataObjectActionType.MinigameUpload)
                        || Equals(actionType, gamedataObjectActionType.VehicleQuickHack)
                        || Equals(actionType, gamedataObjectActionType.PuppetQuickHack)
                        || Equals(actionType, gamedataObjectActionType.DeviceQuickHack)
                        || Equals(actionType, gamedataObjectActionType.Remote);
  return isRemoteType && TweakDBInterface.GetBool(action.GetID() + t".isQuickHack", false);
}

// Helper: Creates and initializes puppet action from record
@addMethod(ScriptedPuppetPS)
private final func CreatePuppetAction(action: wref<ObjectAction_Record>, instigator: wref<GameObject>) -> ref<PuppetAction> {
  let puppetAction: ref<PuppetAction> = this.GetAction(action);
  puppetAction.SetExecutor(instigator);
  puppetAction.RegisterAsRequester(PersistentID.ExtractEntityID(this.GetID()));
  puppetAction.SetObjectActionID(action.GetID());
  puppetAction.SetUp(this);
  return puppetAction;
}

// ==================== Permission Enforcement ====================

// Helper: Determines if quickhack should be inactive based on progression requirements
@addMethod(ScriptedPuppetPS)
private final func ShouldQuickhackBeInactive(puppetAction: ref<PuppetAction>, permissions: NPCHackPermissions) -> Bool {
  // All hacks available if breached or whitelisted
  if permissions.isBreached || this.IsWhiteListedForHacks() {
    return false;
  }

  // Check hack category against progression requirements
  let hackCategory: CName = puppetAction.GetObjectActionRecord().HackCategory().EnumName();
  if Equals(hackCategory, n"CovertHack") && permissions.allowCovert {
    return false;
  }
  if Equals(hackCategory, n"DamageHack") && permissions.allowCombat {
    return false;
  }
  if Equals(hackCategory, n"ControlHack") && permissions.allowControl {
    return false;
  }
  if Equals(hackCategory, n"UltimateHack") && permissions.allowUltimate {
    return false;
  }

  // Check special always-allowed quickhacks
  if IsDefined(puppetAction as PingSquad) && permissions.allowPing {
    return false;
  }
  if Equals(puppetAction.GetObjectActionRecord().ActionName(), n"Whistle") && permissions.allowWhistle {
    return false;
  }

  return true;
}

// Helper: Sets appropriate inactive reason message based on NPC attitude
@addMethod(ScriptedPuppetPS)
private final func SetQuickhackInactiveReason(puppetAction: ref<PuppetAction>, attiudeTowardsPlayer: EAIAttitude) -> Void {
  
  let puppet: wref<ScriptedPuppet> = this.GetOwnerEntity() as ScriptedPuppet;
  
  // CUSTOM: Crowds/vendors use breach message instead of attitude message PIERRE
  if IsDefined(puppet) && (puppet.IsCrowd() || puppet.IsVendor()) {
      puppetAction.SetInactiveWithReason(false, "LocKey#7021"); // "BREACH PROTOCOL REQUIRED"
      return;
  }
  // CUSTOM: Crowds/vendors use breach message instead of attitude message PIERRE

  if NotEquals(attiudeTowardsPlayer, EAIAttitude.AIA_Friendly) {
    puppetAction.SetInactiveWithReason(false, "LocKey#7021");
  } else {
    puppetAction.SetInactiveWithReason(false, "LocKey#27694");
  }
}


// ==================== Tutorial NPC Whitelist ====================

/*
 * Whitelist of tutorial NPCs that should have all quickhacks available
 * These NPCs bypass progression requirements for proper tutorial flow
 * Credit: KiroKobra (AKA 'Phantum Jak' on Discord)
 */
@addMethod(ScriptedPuppetPS)
protected final func IsWhiteListedForHacks() -> Bool {
  let puppet: wref<ScriptedPuppet> = this.GetOwnerEntity() as ScriptedPuppet;
  let recordID: TweakDBID = puppet.GetRecordID();
  return recordID == t"Character.q000_tutorial_course_01_patroller"
      || recordID == t"Character.q000_tutorial_course_02_enemy_02"
      || recordID == t"Character.q000_tutorial_course_02_enemy_03"
      || recordID == t"Character.q000_tutorial_course_02_enemy_04"
      || recordID == t"Character.q000_tutorial_course_03_guard_01"
      || recordID == t"Character.q000_tutorial_course_03_guard_02"
      || recordID == t"Character.q000_tutorial_course_03_guard_03";
}