module BetterNetrunning.Breach

import BetterNetrunningConfig.*
import BetterNetrunning.Common.*

/*
 * Breach processing module for Access Point minigame completion
 * Handles program parsing, loot distribution, and network-wide unlock effects
 *
 * ARCHITECTURE:
 * - RefreshSlaves(): Main coordinator for breach completion
 * - Helper methods: Composed Method pattern for clarity
 * - Radial unlock integration: Records breach position for standalone devices
 *
 * FEATURES:
 * - Progressive unlock per device type (cameras, turrets, NPCs, basic devices)
 * - Datamine loot distribution (money, crafting materials, shards)
 * - Quest-specific program handling
 * - Network centroid calculation for radial unlock
 */

/*
 * Processes breach minigame results and unlocks quickhacks network-wide
 *
 * VERSION HISTORY:
 * - Release version: Simple breach state tracking without radial unlock
 * - Latest version: Added radial unlock system + network centroid calculation
 *
 * VANILLA DIFF: Complete rewrite to implement progressive unlock per device type
 * Handles loot rewards and progressive unlock per device type
 *
 * NEW FEATURES (Latest):
 * - Radial unlock: Records breach position for standalone device support (50m radius)
 * - Network centroid: Calculates average position of all devices for accurate breach location
 * - Isolated NPC detection: Auto-unlocks NPCs not connected to any network
 *
 * REFACTORED: Reduced from 95 lines with 5-level nesting to 30 lines with 2-level nesting
 * Using Composed Method pattern for improved readability
 */
@replaceMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  // Step 1: Get active minigame programs from blackboard
  let minigamePrograms: array<TweakDBID> = this.GetActiveMinigamePrograms();

  // Step 2: Process breach programs and extract rewards
  let lootResult: BreachLootResult = this.ProcessMinigamePrograms(minigamePrograms);

  // Step 3: Update blackboard and reward player
  this.UpdateMinigameBlackboard(minigamePrograms, lootResult);
  this.ProcessLootRewards(lootResult);

  // Step 4: Apply network-wide effects
  this.ApplyNetworkEffects(devices, lootResult.unlockFlags);

  // Step 5: Record breach position for radial unlock
  this.RecordNetworkBreachPosition(devices);

  // Step 6: Final rewards
  this.ProcessFinalRewards(lootResult);
}

// Helper: Gets hacking minigame blackboard (centralized access)
@addMethod(AccessPointControllerPS)
private final func GetMinigameBlackboard() -> ref<IBlackboard> {
  return GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().HackingMinigame);
}

// Helper: Retrieves active minigame programs from blackboard
@addMethod(AccessPointControllerPS)
private final func GetActiveMinigamePrograms() -> array<TweakDBID> {
  let minigameBB: ref<IBlackboard> = this.GetMinigameBlackboard();
  let minigamePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms));

  this.CheckMasterRunnerAchievement(ArraySize(minigamePrograms));
  this.FilterRedundantPrograms(minigamePrograms);

  return minigamePrograms;
}

// Helper: Updates blackboard with processed programs
@addMethod(AccessPointControllerPS)
private final func UpdateMinigameBlackboard(minigamePrograms: array<TweakDBID>, lootResult: BreachLootResult) -> Void {
  if !lootResult.markForErase {
    return;
  }

  ArrayErase(minigamePrograms, lootResult.eraseIndex);
  this.GetMinigameBlackboard().SetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms, ToVariant(minigamePrograms));
}

// Helper: Processes and rewards loot items
@addMethod(AccessPointControllerPS)
private final func ProcessLootRewards(lootResult: BreachLootResult) -> Void {
  if !lootResult.shouldLoot {
    return;
  }

  this.ProcessLoot(lootResult.baseMoney, lootResult.craftingMaterial, lootResult.baseShardDropChance, GameInstance.GetTransactionSystem(this.GetGameInstance()));
}

// Helper: Applies network-wide breach effects
@addMethod(AccessPointControllerPS)
private final func ApplyNetworkEffects(const devices: script_ref<array<ref<DeviceComponentPS>>>, unlockFlags: BreachUnlockFlags) -> Void {
  // Execute minigame actions on access point itself
  this.ProcessMinigameNetworkActions(this);

  // Mark directly breached NPC
  let entity: wref<Entity> = FromVariant<wref<Entity>>(this.GetMinigameBlackboard().GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity));
  if IsDefined(entity as ScriptedPuppet) {
    (entity as ScriptedPuppet).GetPS().m_betterNetrunningWasDirectlyBreached = true;
  }

  // Apply device-type-specific unlock to all network devices
  this.ApplyBreachUnlockToDevices(devices, unlockFlags);
}

// Helper: Records network centroid position for radial unlock
@addMethod(AccessPointControllerPS)
private final func RecordNetworkBreachPosition(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  let centroid: Vector4 = this.CalculateNetworkCentroid(devices);

  // Only record if we found valid devices
  if centroid.X >= -999000.0 {
    RecordAccessPointBreachByPosition(centroid, this.GetGameInstance());
  }
}

// Helper: Calculates average position of all network devices
@addMethod(AccessPointControllerPS)
private final func CalculateNetworkCentroid(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Vector4 {
  let sumX: Float = 0.0;
  let sumY: Float = 0.0;
  let sumZ: Float = 0.0;
  let validDeviceCount: Int32 = 0;

  let i: Int32 = 0;
  while i < ArraySize(Deref(devices)) {
    let device: ref<DeviceComponentPS> = Deref(devices)[i];
    let deviceEntity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;

    if IsDefined(deviceEntity) {
      let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
      sumX += devicePosition.X;
      sumY += devicePosition.Y;
      sumZ += devicePosition.Z;
      validDeviceCount += 1;
    }
    i += 1;
  }

  // Return centroid if valid, otherwise return invalid position
  if validDeviceCount > 0 {
    return Vector4(sumX / Cast<Float>(validDeviceCount), sumY / Cast<Float>(validDeviceCount), sumZ / Cast<Float>(validDeviceCount), 1.0);
  }

  return Vector4(-999999.0, -999999.0, -999999.0, 1.0);
}

// Helper: Processes final rewards (money + XP)
@addMethod(AccessPointControllerPS)
private final func ProcessFinalRewards(lootResult: BreachLootResult) -> Void {
  if lootResult.baseMoney >= 1.00 && this.ShouldRewardMoney() {
    this.RewardMoney(lootResult.baseMoney);
  }
  RPGManager.GiveReward(this.GetGameInstance(), t"RPGActionRewards.Hacking", Cast<StatsObjectID>(this.GetMyEntityID()));
}

// Helper: Processes all uploaded breach programs and extracts loot/unlock data
@addMethod(AccessPointControllerPS)
private final func ProcessMinigamePrograms(minigamePrograms: array<TweakDBID>) -> BreachLootResult {
  let result: BreachLootResult;
  let TS: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());

  let i: Int32 = ArraySize(minigamePrograms) - 1;
  while i >= 0 {
    let programID: TweakDBID = minigamePrograms[i];

    // Quest-specific programs
    if programID == t"minigame_v2.FindAnna" {
      AddFact(this.GetPlayerMainObject().GetGame(), n"Kab08Minigame_program_uploaded");
    } else if programID == t"MinigameAction.NetworkLootQ003" {
      TS.GiveItemByItemQuery(this.GetPlayerMainObject(), t"Query.Q003CyberdeckProgram");
    }
    // Datamine loot programs
    else if programID == t"MinigameAction.NetworkDataMineLootAll"
         || programID == t"MinigameAction.NetworkDataMineLootAllAdvanced"
         || programID == t"MinigameAction.NetworkDataMineLootAllMaster" {
      this.ProcessLootProgram(programID, result);
    }
    // Device unlock programs
    else if programID == t"MinigameAction.UnlockQuickhacks"
         || programID == t"MinigameAction.UnlockNPCQuickhacks"
         || programID == t"MinigameAction.UnlockCameraQuickhacks"
         || programID == t"MinigameAction.UnlockTurretQuickhacks" {
      this.ProcessUnlockProgram(programID, result.unlockFlags);
    }
    i -= 1;
  }

  result.eraseIndex = i;
  return result;
}

// Helper: Processes loot program and updates result data
@addMethod(AccessPointControllerPS)
private final func ProcessLootProgram(programID: TweakDBID, result: script_ref<BreachLootResult>) -> Void {
  if programID == t"MinigameAction.NetworkDataMineLootAll" {
    Deref(result).baseMoney += 1.00;
  } else if programID == t"MinigameAction.NetworkDataMineLootAllAdvanced" {
    Deref(result).baseMoney += 1.00;
    Deref(result).craftingMaterial = true;
  } else if programID == t"MinigameAction.NetworkDataMineLootAllMaster" {
    Deref(result).baseShardDropChance += 1.00;
  }
  Deref(result).shouldLoot = true;
  Deref(result).markForErase = true;
}

// Helper: Processes unlock program and updates unlock flags
@addMethod(AccessPointControllerPS)
private final func ProcessUnlockProgram(programID: TweakDBID, flags: script_ref<BreachUnlockFlags>) -> Void {
  if programID == t"MinigameAction.UnlockQuickhacks" {
    Deref(flags).unlockBasic = true;
  } else if programID == t"MinigameAction.UnlockNPCQuickhacks" {
    Deref(flags).unlockNPCs = true;
  } else if programID == t"MinigameAction.UnlockCameraQuickhacks" {
    Deref(flags).unlockCameras = true;
  } else if programID == t"MinigameAction.UnlockTurretQuickhacks" {
    Deref(flags).unlockTurrets = true;
  }
}

// Helper: Unlocks quickhacks based on device type (using DeviceTypeUtils)
@addMethod(AccessPointControllerPS)
public final func ApplyDeviceTypeUnlock(device: ref<DeviceComponentPS>, unlockFlags: BreachUnlockFlags) -> Void {
  let sharedPS: ref<SharedGameplayPS> = device as SharedGameplayPS;
  if !IsDefined(sharedPS) {
    return;
  }

  // Use DeviceTypeUtils for centralized device type detection
  let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(device);

  // Check if this device type should be unlocked based on flags
  if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
    return;
  }

  // Unlock quickhacks and set breach flag
  this.QueuePSEvent(device, this.ActionSetExposeQuickHacks());
  DeviceTypeUtils.SetBreached(deviceType, sharedPS, true);
}
