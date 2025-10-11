// ============================================================================
// BetterNetrunning - RemoteBreach Network Unlock Integration
// ============================================================================
// Extends RemoteBreach (CustomHackingSystem) to apply network effects similar
// to AccessPoint breach. Provides target device unlock + Radial Unlock support.
//
// FUNCTIONALITY:
// - Target device unlock: Immediate unlock of breached device
// - Network-wide unlock: Propagates unlock to all connected devices (same as AccessPoint breach)
// - Radial Unlock: Records breach position for standalone device support (50m radius)
// - NPC duplicate prevention: Tracks directly breached NPCs (m_betterNetrunningWasDirectlyBreached flag)
// - Loot rewards: Datamine programs provide money/crafting materials/shards
// - RadialBreach integration: Physical distance filtering (50m default)
//
// ARCHITECTURE:
// - Blackboard listener on HackingMinigame.State for completion detection
// - RemoteBreachStateSystem integration for target device retrieval
// - DeviceTypeUtils for unified device unlock logic
// - RadialUnlockSystem for position recording
// - TransactionSystem for loot rewards
// - RadialBreachGating for physical distance filtering
//
// DEPENDENCIES:
// - BetterNetrunning.Common.* (DeviceTypeUtils, BNLog)
// - BetterNetrunning.CustomHacking.* (RemoteBreachStateSystem variants)
// - BetterNetrunning.RadialUnlock.* (RecordAccessPointBreachByPosition, RadialBreachGating)
// ============================================================================

module BetterNetrunning.RadialUnlock

import BetterNetrunning.Common.*
import BetterNetrunning.CustomHacking.*
import BetterNetrunningConfig.*

// NOTE: RadialBreach integration is handled by RadialBreachGating.reds

// ============================================================================
// DATA STRUCTURES
// ============================================================================

// RemoteBreach loot reward accumulator (reduces parameter passing)
// Using struct instead of class to avoid ref<> requirement
public struct RemoteBreachLootData {
  let baseMoney: Float;
  let craftingMaterial: Bool;
  let baseShardDropChance: Float;
  let shouldLoot: Bool;
}
// No need for conditional import here - RadialBreachGating manages it

// ============================================================================
// PLAYER PUPPET EXTENSIONS - REMOTEBREACH LISTENER
// ============================================================================

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();

  // Register RemoteBreach completion listener
  this.RegisterRemoteBreachListener();

  return result;
}

// Register blackboard listener for RemoteBreach minigame completion
@addMethod(PlayerPuppet)
private func RegisterRemoteBreachListener() -> Void {
  let blackboardSystem: ref<BlackboardSystem> = GameInstance.GetBlackboardSystem(this.GetGame());
  let hackingBB: ref<IBlackboard> = blackboardSystem.Get(GetAllBlackboardDefs().HackingMinigame);

  if IsDefined(hackingBB) {
    // Listen for minigame state changes
    hackingBB.RegisterListenerInt(GetAllBlackboardDefs().HackingMinigame.State, this, n"OnRemoteBreachMinigameStateChanged");
  }
}

// Callback when hacking minigame state changes
@addMethod(PlayerPuppet)
protected cb func OnRemoteBreachMinigameStateChanged(value: Int32) -> Bool {
  let state: HackingMinigameState = IntEnum<HackingMinigameState>(value);

  // Only process on successful completion
  if Equals(state, HackingMinigameState.Succeeded) {
    this.ProcessRemoteBreachCompletion();
  }

  return true;
}

// ============================================================================
// MAIN PROCESSING LOGIC
// ============================================================================

// Process RemoteBreach completion and apply network unlock + rewards
// Functionality:
//   - Target device unlock + Radial Unlock position recording
//   - Network-wide device unlock (full parity with AP breach)
//   - NPC duplicate prevention + Loot reward system
@addMethod(PlayerPuppet)
private func ProcessRemoteBreachCompletion() -> Void {
  let gameInstance: GameInstance = this.GetGame();

  // 1. Check if this is a RemoteBreach minigame (not AccessPoint or Quickhack)
  if !this.IsRemoteBreachMinigame() {
    return;
  }

  BNLog("[RemoteBreach] Minigame completed, processing network unlock");

  // 2. Get active programs from blackboard
  let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gameInstance).Get(GetAllBlackboardDefs().HackingMinigame);
  let activePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms));

  // 2.5. Apply bonus daemons - using shared utility
  ApplyBonusDaemons(activePrograms, gameInstance, "[RemoteBreach]");

  // 3. Parse unlock flags from active programs
  let unlockFlags: BreachUnlockFlags = this.ParseRemoteBreachUnlockFlags(activePrograms);

  BNLog("[RemoteBreach] Parsed unlock flags - Basic: " + ToString(unlockFlags.unlockBasic) +
        ", NPCs: " + ToString(unlockFlags.unlockNPCs) +
        ", Cameras: " + ToString(unlockFlags.unlockCameras) +
        ", Turrets: " + ToString(unlockFlags.unlockTurrets));

  // 4. Get target device from RemoteBreachStateSystem
  let targetDevice: ref<ScriptableDeviceComponentPS> = this.GetRemoteBreachTargetDevice();

  if !IsDefined(targetDevice) {
    BNLog("[RemoteBreach] ERROR: Target device not found");
    return;
  }

  // 5. Apply unlock to target device
  this.ApplyRemoteBreachDeviceUnlock(targetDevice, unlockFlags);

  // 6. Get network devices
  let networkDevices: array<ref<DeviceComponentPS>> = this.GetRemoteBreachNetworkDevices(targetDevice);

  // 7. Apply unlock to network devices (with RadialBreach filtering)
  if ArraySize(networkDevices) > 0 {
    this.ApplyRemoteBreachNetworkUnlock(targetDevice, networkDevices, unlockFlags);
  }

  // 8. Mark directly breached NPC (prevent duplicate breach)
  this.MarkDirectlyBreachedNPC(targetDevice);

  // 9. Process loot rewards (reward system)
  this.ProcessRemoteBreachLoot(activePrograms);

  // 10. Record breach position for Radial Unlock system
  this.RecordRemoteBreachPosition(targetDevice);

  // 11. Unlock nearby standalone devices (PR #5 feature)
  let deviceEntity: wref<GameObject> = targetDevice.GetOwnerEntityWeak() as GameObject;
  if IsDefined(deviceEntity) {
    this.UnlockNearbyStandaloneDevices(deviceEntity.GetWorldPosition());
  }

  BNLog("[RemoteBreach] Network unlock complete");
}

// ============================================================================
// REMOTEBREACH DETECTION
// ============================================================================

// Check if current minigame is a RemoteBreach (not AccessPoint or Quickhack)
@addMethod(PlayerPuppet)
private func IsRemoteBreachMinigame() -> Bool {
  let gameInstance: GameInstance = this.GetGame();
  let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);

  // Check Computer RemoteBreach
  let computerSystem: ref<RemoteBreachStateSystem> = container.Get(n"BetterNetrunning.CustomHacking.RemoteBreachStateSystem") as RemoteBreachStateSystem;
  if IsDefined(computerSystem) {
    let currentComputer: wref<ComputerControllerPS> = computerSystem.GetCurrentComputer();
    if IsDefined(currentComputer) {
      return true;
    }
  }

  // Check Device RemoteBreach
  let deviceSystem: ref<DeviceRemoteBreachStateSystem> = container.Get(n"BetterNetrunning.CustomHacking.DeviceRemoteBreachStateSystem") as DeviceRemoteBreachStateSystem;
  if IsDefined(deviceSystem) {
    let currentDevice: wref<ScriptableDeviceComponentPS> = deviceSystem.GetCurrentDevice();
    if IsDefined(currentDevice) {
      return true;
    }
  }

  // Check Vehicle RemoteBreach
  let vehicleSystem: ref<VehicleRemoteBreachStateSystem> = container.Get(n"BetterNetrunning.CustomHacking.VehicleRemoteBreachStateSystem") as VehicleRemoteBreachStateSystem;
  if IsDefined(vehicleSystem) {
    let currentVehicle: wref<VehicleComponentPS> = vehicleSystem.GetCurrentVehicle();
    if IsDefined(currentVehicle) {
      return true;
    }
  }

  return false;
}

// ============================================================================
// PROGRAM PARSING
// ============================================================================

// Parse unlock flags from active minigame programs
@addMethod(PlayerPuppet)
private func ParseRemoteBreachUnlockFlags(activePrograms: array<TweakDBID>) -> BreachUnlockFlags {
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

// ============================================================================
// TARGET DEVICE RETRIEVAL
// ============================================================================

// Get RemoteBreach target device from state systems
@addMethod(PlayerPuppet)
private func GetRemoteBreachTargetDevice() -> ref<ScriptableDeviceComponentPS> {
  let gameInstance: GameInstance = this.GetGame();
  let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);

  // Try Computer RemoteBreach
  let computerSystem: ref<RemoteBreachStateSystem> = container.Get(n"BetterNetrunning.CustomHacking.RemoteBreachStateSystem") as RemoteBreachStateSystem;
  if IsDefined(computerSystem) {
    let currentComputer: wref<ComputerControllerPS> = computerSystem.GetCurrentComputer();
    if IsDefined(currentComputer) {
      return currentComputer;
    }
  }

  // Try Device RemoteBreach
  let deviceSystem: ref<DeviceRemoteBreachStateSystem> = container.Get(n"BetterNetrunning.CustomHacking.DeviceRemoteBreachStateSystem") as DeviceRemoteBreachStateSystem;
  if IsDefined(deviceSystem) {
    let currentDevice: wref<ScriptableDeviceComponentPS> = deviceSystem.GetCurrentDevice();
    if IsDefined(currentDevice) {
      return currentDevice;
    }
  }

  // Try Vehicle RemoteBreach
  let vehicleSystem: ref<VehicleRemoteBreachStateSystem> = container.Get(n"BetterNetrunning.CustomHacking.VehicleRemoteBreachStateSystem") as VehicleRemoteBreachStateSystem;
  if IsDefined(vehicleSystem) {
    let currentVehicle: wref<VehicleComponentPS> = vehicleSystem.GetCurrentVehicle();
    if IsDefined(currentVehicle) {
      return currentVehicle;
    }
  }

  return null;
}

// ============================================================================
// NETWORK DEVICE RETRIEVAL
// ============================================================================

// Get all network devices connected to RemoteBreach target device
// Uses GetAccessPoints() + GetChildren() API (same as AccessPoint breach)
// Architecture: Shallow nesting (max 2 levels) using helper methods
@addMethod(PlayerPuppet)
private func GetRemoteBreachNetworkDevices(
  targetDevice: ref<ScriptableDeviceComponentPS>
) -> array<ref<DeviceComponentPS>> {
  let networkDevices: array<ref<DeviceComponentPS>>;

  // ScriptableDeviceComponentPS extends SharedGameplayPS
  let sharedPS: ref<SharedGameplayPS> = targetDevice;
  if !IsDefined(sharedPS) {
    BNLog("[RemoteBreach] Target device is not SharedGameplayPS, no network devices");
    return networkDevices;
  }

  // Get all AccessPoints in network
  let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();
  if ArraySize(apControllers) == 0 {
    BNLog("[RemoteBreach] No AccessPoints found, target device is standalone");
    return networkDevices;
  }

  BNLog("[RemoteBreach] Found " + ToString(ArraySize(apControllers)) + " AccessPoint(s) in network");

  // Collect devices from all AccessPoints
  let i: Int32 = 0;
  while i < ArraySize(apControllers) {
    this.CollectAccessPointDevices(apControllers[i], i, networkDevices);
    i += 1;
  }

  BNLog("[RemoteBreach] Total network devices: " + ToString(ArraySize(networkDevices)));
  return networkDevices;
}

// Helper: Collect all devices from a single AccessPoint
@addMethod(PlayerPuppet)
private func CollectAccessPointDevices(
  apPS: ref<AccessPointControllerPS>,
  apIndex: Int32,
  out networkDevices: array<ref<DeviceComponentPS>>
) -> Void {
  if !IsDefined(apPS) {
    return;
  }

  let apDevices: array<ref<DeviceComponentPS>>;
  apPS.GetChildren(apDevices);

  BNLog("[RemoteBreach] AccessPoint " + ToString(apIndex) + " has " + ToString(ArraySize(apDevices)) + " device(s)");

  // Merge devices into main array
  let j: Int32 = 0;
  while j < ArraySize(apDevices) {
    ArrayPush(networkDevices, apDevices[j]);
    j += 1;
  }
}

// ============================================================================
// DEVICE UNLOCK LOGIC
// ============================================================================

// Apply unlock to RemoteBreach target device
@addMethod(PlayerPuppet)
private func ApplyRemoteBreachDeviceUnlock(targetDevice: ref<ScriptableDeviceComponentPS>, unlockFlags: BreachUnlockFlags) -> Void {
  let sharedPS: ref<SharedGameplayPS> = targetDevice;
  if !IsDefined(sharedPS) {
    BNLog("[RemoteBreach] Target device is not SharedGameplayPS, cannot unlock");
    return;
  }

  // Use DeviceTypeUtils for centralized device type detection
  let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(targetDevice);

  BNLog("[RemoteBreach] Target device type: " + EnumValueToString("DeviceType", Cast<Int64>(EnumInt(deviceType))));

  // Check if this device type should be unlocked based on flags
  if !DeviceTypeUtils.ShouldUnlockByFlags(deviceType, unlockFlags) {
    BNLog("[RemoteBreach] Device type not unlocked by current flags");
    return;
  }

  // Unlock quickhacks (reuse AccessPointControllerPS method via helper)
  let dummyAPPS: ref<AccessPointControllerPS> = new AccessPointControllerPS();
  dummyAPPS.QueuePSEvent(targetDevice, dummyAPPS.ActionSetExposeQuickHacks());

  // Set breach flag
  DeviceTypeUtils.SetBreached(deviceType, sharedPS, true);

  // Set breached subnet event (propagate unlock flags to device)
  let setBreachedSubnetEvent: ref<SetBreachedSubnet> = new SetBreachedSubnet();
  setBreachedSubnetEvent.breachedBasic = unlockFlags.unlockBasic;
  setBreachedSubnetEvent.breachedNPCs = unlockFlags.unlockNPCs;
  setBreachedSubnetEvent.breachedCameras = unlockFlags.unlockCameras;
  setBreachedSubnetEvent.breachedTurrets = unlockFlags.unlockTurrets;
  GameInstance.GetPersistencySystem(this.GetGame()).QueuePSEvent(targetDevice.GetID(), targetDevice.GetClassName(), setBreachedSubnetEvent);

  BNLog("[RemoteBreach] Target device unlocked successfully");
}

// ============================================================================
// NPC DUPLICATE BREACH PREVENTION
// ============================================================================

// Mark directly breached NPC to prevent duplicate breach (Device-based version)
@addMethod(PlayerPuppet)
private func MarkDirectlyBreachedNPC(targetDevice: ref<ScriptableDeviceComponentPS>) -> Void {
  // Check if target device is an NPC
  let npcPS: ref<ScriptedPuppetPS> = targetDevice as ScriptedPuppetPS;
  if IsDefined(npcPS) {
    npcPS.m_betterNetrunningWasDirectlyBreached = true;
    BNLog("[RemoteBreach] Marked NPC as directly breached (prevents unconscious breach)");
  }
}

// Mark directly breached NPC to prevent duplicate breach (Blackboard-based version)
@addMethod(PlayerPuppet)
private func MarkRemoteBreachedNPC(minigameBB: ref<IBlackboard>) -> Void {
  // Get entity from blackboard (same as AP breach)
  let entity: wref<Entity> = FromVariant<wref<Entity>>(minigameBB.GetVariant(GetAllBlackboardDefs().HackingMinigame.Entity));

  if IsDefined(entity as ScriptedPuppet) {
    (entity as ScriptedPuppet).GetPS().m_betterNetrunningWasDirectlyBreached = true;
    BNLog("[RemoteBreach] Marked NPC as directly breached (prevents unconscious breach)");
  }
}

// ============================================================================
// LOOT REWARD SYSTEM
// ============================================================================

// Process RemoteBreach loot rewards (datamine programs)
// Architecture: Separated Parse and Award phases for clarity
@addMethod(PlayerPuppet)
private func ProcessRemoteBreachLoot(activePrograms: array<TweakDBID>) -> Void {
  // Step 1: Parse loot programs
  let lootData: RemoteBreachLootData = this.ParseLootPrograms(activePrograms);

  // Step 2: Award rewards if any loot programs were uploaded
  if lootData.shouldLoot {
    this.AwardLootRewards(lootData);
  }
}

// Helper: Parse loot programs and accumulate reward data (reduced nesting)
@addMethod(PlayerPuppet)
private func ParseLootPrograms(activePrograms: array<TweakDBID>) -> RemoteBreachLootData {
  let lootData: RemoteBreachLootData;

  let i: Int32 = 0;
  while i < ArraySize(activePrograms) {
    let programID: TweakDBID = activePrograms[i];

    // Use switch for cleaner program type detection
    if Equals(programID, t"MinigameAction.NetworkDataMineLootAll") {
      lootData.baseMoney += 1.0;
      lootData.shouldLoot = true;
      BNLog("[RemoteBreach] Loot program: NetworkDataMineLootAll (money +1.0)");
    } else if Equals(programID, t"MinigameAction.NetworkDataMineLootAllAdvanced") {
      lootData.baseMoney += 1.0;
      lootData.craftingMaterial = true;
      lootData.shouldLoot = true;
      BNLog("[RemoteBreach] Loot program: NetworkDataMineLootAllAdvanced (money +1.0, crafting material)");
    } else if Equals(programID, t"MinigameAction.NetworkDataMineLootAllMaster") {
      lootData.baseShardDropChance += 1.0;
      lootData.shouldLoot = true;
      BNLog("[RemoteBreach] Loot program: NetworkDataMineLootAllMaster (shard drop +1.0)");
    }

    i += 1;
  }

  return lootData;
}

// Helper: Award loot rewards based on parsed data (reduced nesting)
@addMethod(PlayerPuppet)
private func AwardLootRewards(lootData: RemoteBreachLootData) -> Void {
  let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGame());
  let player: ref<GameObject> = this;

  // Award money
  if lootData.baseMoney > 0.0 {
    this.AwardMoney(transactionSystem, player, lootData.baseMoney);
  }

  // Award crafting material
  if lootData.craftingMaterial {
    this.AwardCraftingMaterial(transactionSystem, player);
  }

  // Award shard (chance-based)
  if lootData.baseShardDropChance > 0.0 {
    this.AwardShard(transactionSystem, player, lootData.baseShardDropChance);
  }
}

// Helper: Award money reward
@addMethod(PlayerPuppet)
private func AwardMoney(transactionSystem: ref<TransactionSystem>, player: ref<GameObject>, baseMoney: Float) -> Void {
  let moneyAmount: Int32 = RandRange(
    Cast<Int32>(150.0 * baseMoney),
    Cast<Int32>(450.0 * baseMoney)
  );
  transactionSystem.GiveItem(player, ItemID.CreateQuery(t"Items.money"), moneyAmount);
  BNLog("[RemoteBreach] Awarded money: " + ToString(moneyAmount) + " eddies");
}

// Helper: Award crafting material
@addMethod(PlayerPuppet)
private func AwardCraftingMaterial(transactionSystem: ref<TransactionSystem>, player: ref<GameObject>) -> Void {
  let materialAmount: Int32 = RandRange(1, 3);
  let materialID: TweakDBID = this.GetRandomCraftingMaterial();
  transactionSystem.GiveItem(player, ItemID.CreateQuery(materialID), materialAmount);
  BNLog("[RemoteBreach] Awarded crafting material: " + TDBID.ToStringDEBUG(materialID) + " x" + ToString(materialAmount));
}

// Helper: Award shard (chance-based)
@addMethod(PlayerPuppet)
private func AwardShard(transactionSystem: ref<TransactionSystem>, player: ref<GameObject>, baseShardDropChance: Float) -> Void {
  let shardRoll: Float = RandF();
  if shardRoll <= (0.3 * baseShardDropChance) {
    let shardID: TweakDBID = t"Items.SampleShard"; // Generic shard
    transactionSystem.GiveItem(player, ItemID.CreateQuery(shardID), 1);
    BNLog("[RemoteBreach] Awarded shard: " + TDBID.ToStringDEBUG(shardID));
  } else {
    BNLog("[RemoteBreach] Shard roll failed: " + ToString(shardRoll) + " > " + ToString(0.3 * baseShardDropChance));
  }
}

// Get random crafting material (same distribution as AP breach)
@addMethod(PlayerPuppet)
private func GetRandomCraftingMaterial() -> TweakDBID {
  let roll: Int32 = RandRange(0, 3);

  if roll == 0 {
    return t"Items.CommonMaterial1"; // Common material
  } else if roll == 1 {
    return t"Items.UncommonMaterial1"; // Uncommon material
  } else {
    return t"Items.RareMaterial1"; // Rare material
  }
}

// ============================================================================
// RADIAL UNLOCK INTEGRATION
// ============================================================================

// Record RemoteBreach position for Radial Unlock system (50m radius)
@addMethod(PlayerPuppet)
private func RecordRemoteBreachPosition(targetDevice: ref<ScriptableDeviceComponentPS>) -> Void {
  let deviceEntity: wref<GameObject> = targetDevice.GetOwnerEntityWeak() as GameObject;

  if !IsDefined(deviceEntity) {
    BNLog("[RemoteBreach] WARNING: Target device entity not found, cannot record position");
    return;
  }

  let devicePosition: Vector4 = deviceEntity.GetWorldPosition();

  // Record position for Radial Unlock system (enables 50m radius unlock)
  RecordAccessPointBreachByPosition(devicePosition, this.GetGame());

  BNLog("[RemoteBreach] Breach position recorded: (" +
        ToString(devicePosition.X) + ", " +
        ToString(devicePosition.Y) + ", " +
        ToString(devicePosition.Z) + ")");
  BNLog("[RemoteBreach] Standalone devices within 50m radius will be unlockable via Radial Unlock system");
}

// ============================================================================
// NEARBY STANDALONE DEVICE UNLOCK (PR #5 Feature)
// ============================================================================

/*
 * Unlock nearby standalone devices after breaching any device
 *
 * FEATURE: Auto-unlock standalone devices within 50m radius
 * RATIONALE: Extends RemoteBreach effectiveness to nearby isolated devices
 *
 * TODO: Maybe add NPC subnets here too to make hacking regular civilian NPCs lorefriendly. - Pierre
 */
@addMethod(PlayerPuppet)
private func UnlockNearbyStandaloneDevices(breachPosition: Vector4) -> Void {
  let gameInstance: GameInstance = this.GetGame();
  let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);

  if !IsDefined(targetingSystem) {
    BNLog("[RadialUnlock] TargetingSystem not available, cannot unlock nearby devices");
    return;
  }

  // Search for nearby devices
  let nearbyDevices: array<ref<ScriptableDeviceComponentPS>> = this.FindNearbyDevices(targetingSystem);

  if ArraySize(nearbyDevices) == 0 {
    BNLog("[RadialUnlock] No nearby devices found within 50m");
    return;
  }

  BNLog("[RadialUnlock] Found " + ToString(ArraySize(nearbyDevices)) + " nearby device(s)");

  // Filter and unlock standalone devices
  let unlockedCount: Int32 = this.UnlockStandaloneDevices(nearbyDevices);

  if unlockedCount > 0 {
    BNLog("[RadialUnlock] Auto-unlocked " + ToString(unlockedCount) + " standalone device(s) within 50m radius");
  } else {
    BNLog("[RadialUnlock] No standalone devices found (all are networked)");
  }
}

// Helper: Find all devices within 50m radius
@addMethod(PlayerPuppet)
private func FindNearbyDevices(
  targetingSystem: ref<TargetingSystem>
) -> array<ref<ScriptableDeviceComponentPS>> {
  let devices: array<ref<ScriptableDeviceComponentPS>>;

  // Setup device search query
  let query: TargetSearchQuery;
  query.searchFilter = TSF_All(TSFMV.Obj_Device);
  query.testedSet = TargetingSet.Complete;
  query.maxDistance = 50.0; // Match radial breach radius
  query.filterObjectByDistance = true;
  query.includeSecondaryTargets = false;
  query.ignoreInstigator = true;

  let parts: array<TS_TargetPartInfo>;
  targetingSystem.GetTargetParts(this, query, parts);

  // Extract ScriptableDeviceComponentPS from target parts
  let i: Int32 = 0;
  while i < ArraySize(parts) {
    let entity: wref<GameObject> = TS_TargetPartInfo.GetComponent(parts[i]).GetEntity() as GameObject;

    if IsDefined(entity) {
      let device: ref<Device> = entity as Device;
      if IsDefined(device) {
        let devicePS: ref<ScriptableDeviceComponentPS> = device.GetDevicePS();
        if IsDefined(devicePS) {
          ArrayPush(devices, devicePS);
        }
      }
    }

    i += 1;
  }

  return devices;
}

// Helper: Filter for standalone devices and unlock them
@addMethod(PlayerPuppet)
private func UnlockStandaloneDevices(
  devices: array<ref<ScriptableDeviceComponentPS>>
) -> Int32 {
  let unlockedCount: Int32 = 0;

  let i: Int32 = 0;
  while i < ArraySize(devices) {
    let devicePS: ref<ScriptableDeviceComponentPS> = devices[i];
    let sharedPS: ref<SharedGameplayPS> = devicePS;

    if IsDefined(sharedPS) {
      let apControllers: array<ref<AccessPointControllerPS>> = sharedPS.GetAccessPoints();

      // Standalone = no AccessPoints
      if ArraySize(apControllers) == 0 {
        if this.UnlockSingleDevice(sharedPS, devicePS) {
          unlockedCount += 1;
        }
      }
    }

    i += 1;
  }

  return unlockedCount;
}

// Helper: Unlock a single device based on type
@addMethod(PlayerPuppet)
private func UnlockSingleDevice(
  sharedPS: ref<SharedGameplayPS>,
  devicePS: ref<ScriptableDeviceComponentPS>
) -> Bool {
  // Use DeviceTypeUtils for centralized device type detection
  let deviceType: DeviceType = DeviceTypeUtils.GetDeviceType(devicePS);

  // Set appropriate breach flag based on device type
  if Equals(deviceType, DeviceType.Camera) {
    sharedPS.m_betterNetrunningBreachedCameras = true;
    return true;
  } else if Equals(deviceType, DeviceType.Turret) {
    sharedPS.m_betterNetrunningBreachedTurrets = true;
    return true;
  } else {
    // All other device types (Basic, NPC) use Basic flag
    sharedPS.m_betterNetrunningBreachedBasic = true;
    return true;
  }

  return false;
}

