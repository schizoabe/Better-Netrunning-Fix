module BetterNetrunning.RadialUnlock

import BetterNetrunning.Logger.*
import BetterNetrunningConfig.*

/*
 * Radial-based network breach tracking for standalone devices
 *
 * ARCHITECTURE:
 * - Uses GameInstance.GetTargetingSystem() to find nearby devices
 * - Records breached AccessPoint entity IDs in player's persistent storage
 * - Standalone devices check if they're within breach radius of any recorded AP
 *
 * ADVANTAGES over hash-based approach:
 * - Uses native TargetingSystem (same as RadialBreach mod)
 * - No hash mismatch issues (devices found by spatial proximity)
 * - Works for physically separate standalone devices
 * - Configurable breach radius
 */

// ==================== Player Persistent Storage ====================

// Store breach positions instead of EntityIDs (more reliable)
@addField(PlayerPuppet)
public persistent let m_betterNetrunning_breachedAccessPointPositions: array<Vector4>;

@addField(PlayerPuppet)
public persistent let m_betterNetrunning_breachTimestamps: array<Uint64>;

// ==================== Configuration ====================

// Default breach radius (meters) - can be adjusted based on testing
public func GetDefaultBreachRadius() -> Float {
  return 50.0; // 50m to cover wider network ranges (increased from 30m)
}

// Maximum stored breach records (prevents save bloat)
public func GetMaxBreachRecords() -> Int32 {
  return 50; // Reduced from 100 (only stores AccessPoint IDs, not device hashes)
}

// Records to remove when pruning (20% of max)
public func GetPruneCount() -> Int32 {
  return 10;
}

// ==================== Core API ====================

/*
 * Records a successful AccessPoint breach by position
 * Called from RefreshSlaves() after breach minigame completion
 * Uses position-based tracking since EntityID retrieval is unreliable
 */
public func RecordAccessPointBreachByPosition(apPosition: Vector4, gameInstance: GameInstance) -> Void {
  BNLog("RecordAccessPointBreachByPosition: Recording breach at (" + ToString(apPosition.X) + ", " + ToString(apPosition.Y) + ", " + ToString(apPosition.Z) + ")");

  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    BNLog("RecordAccessPointBreachByPosition: Player not found");
    return;
  }

  // Check if already recorded (within 1m tolerance)
  let idx: Int32 = 0;
  let tolerance: Float = 1.0; // 1 meter tolerance for duplicate detection
  while idx < ArraySize(player.m_betterNetrunning_breachedAccessPointPositions) {
    let existingPos: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[idx];
    let distance: Float = Vector4.Distance(existingPos, apPosition);

    if distance < tolerance {
      // Update timestamp and return
      player.m_betterNetrunning_breachTimestamps[idx] = GetCurrentTimestamp(gameInstance);
      BNLog("RecordAccessPointBreachByPosition: Updated existing record at index " + ToString(idx) + " (distance: " + ToString(distance) + "m)");
      return;
    }
    idx += 1;
  }

  // Add new record
  ArrayPush(player.m_betterNetrunning_breachedAccessPointPositions, apPosition);
  ArrayPush(player.m_betterNetrunning_breachTimestamps, GetCurrentTimestamp(gameInstance));

  let newSize: Int32 = ArraySize(player.m_betterNetrunning_breachedAccessPointPositions);
  BNLog("RecordAccessPointBreachByPosition: Added new record. Total records: " + ToString(newSize));

  // Prune old records if limit exceeded
  if newSize > GetMaxBreachRecords() {
    BNLog("RecordAccessPointBreachByPosition: Pruning old records...");
    PruneOldestBreachRecords(player);
  }
}

// Legacy function for compatibility - now records by position
public func RecordAccessPointBreach(apEntityID: EntityID, gameInstance: GameInstance) -> Void {
  // Try to get entity position
  let apEntity: wref<GameObject> = GameInstance.FindEntityByID(gameInstance, apEntityID) as GameObject;
  if IsDefined(apEntity) {
    RecordAccessPointBreachByPosition(apEntity.GetWorldPosition(), gameInstance);
  } else {
    BNLog("RecordAccessPointBreach: WARNING - Could not get entity position for EntityID " + ToString(EntityID.GetHash(apEntityID)));
  }
}

/*
 * Checks if a standalone device should be unlocked
 * Returns true if device is within breach radius of any recorded AccessPoint
 */
public func ShouldUnlockStandaloneDevice(device: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Bool {
  // CRITICAL FIX: UnlockIfNoAccessPoint setting logic
  // - UnlockIfNoAccessPoint = true ↁEStandalone devices ALWAYS unlock (don't require AP)
  // - UnlockIfNoAccessPoint = false ↁEStandalone devices require nearby breached AP

  if BetterNetrunningSettings.UnlockIfNoAccessPoint() {
    // Setting is TRUE ↁEAlways unlock standalone devices without requiring AP
    BNLog("ShouldUnlockStandaloneDevice: UnlockIfNoAccessPoint=true, always unlock");
    return true;
  }

  // Setting is FALSE ↁERequire nearby breached AccessPoint
  BNLog("ShouldUnlockStandaloneDevice: UnlockIfNoAccessPoint=false, checking radius...");

  // Get device position
  let deviceEntity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;
  if !IsDefined(deviceEntity) {
    BNLog("ShouldUnlockStandaloneDevice: deviceEntity not found");
    return false;
  }

  let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);

  if !IsDefined(player) {
    BNLog("ShouldUnlockStandaloneDevice: player not found");
    return false;
  }

  let recordCount: Int32 = ArraySize(player.m_betterNetrunning_breachedAccessPointPositions);
  BNLog("ShouldUnlockStandaloneDevice: Checking " + ToString(recordCount) + " breached APs");

  // Check if within radius of any breached AccessPoint
  let result: Bool = IsWithinBreachedAccessPointRadius(devicePosition, player, gameInstance);
  BNLog("ShouldUnlockStandaloneDevice: Result = " + ToString(result));
  return result;
}

/*
 * Checks if a position is within breach radius of any recorded AccessPoint
 * Now uses stored positions instead of EntityIDs
 */
private func IsWithinBreachedAccessPointRadius(position: Vector4, player: ref<PlayerPuppet>, gameInstance: GameInstance) -> Bool {
  let breachRadius: Float = GetDefaultBreachRadius();
  let breachRadiusSq: Float = breachRadius * breachRadius; // Use squared distance for performance

  let idx: Int32 = 0;
  let recordCount: Int32 = ArraySize(player.m_betterNetrunning_breachedAccessPointPositions);

  BNLog("IsWithinBreachedAccessPointRadius: Device position = (" + ToString(position.X) + ", " + ToString(position.Y) + ", " + ToString(position.Z) + ")");
  BNLog("IsWithinBreachedAccessPointRadius: Checking " + ToString(recordCount) + " records with radius " + ToString(breachRadius) + "m");

  while idx < recordCount {
    let apPosition: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[idx];
    let distanceSq: Float = Vector4.DistanceSquared(position, apPosition);
    let distance: Float = SqrtF(distanceSq);

    BNLog("IsWithinBreachedAccessPointRadius: AP #" + ToString(idx) + " at (" + ToString(apPosition.X) + ", " + ToString(apPosition.Y) + ", " + ToString(apPosition.Z) + ") distance = " + ToString(distance) + "m");

    if distanceSq <= breachRadiusSq {
      BNLog("IsWithinBreachedAccessPointRadius: FOUND within radius!");
      return true; // Within breach radius
    }

    idx += 1;
  }

  BNLog("IsWithinBreachedAccessPointRadius: No AP within radius");
  return false; // Not within any breach radius
}

// ==================== Helper Functions ====================

// Removes oldest breach records when storage limit exceeded
private func PruneOldestBreachRecords(player: ref<PlayerPuppet>) -> Void {
  let pruneCount: Int32 = GetPruneCount();
  let currentSize: Int32 = ArraySize(player.m_betterNetrunning_breachedAccessPointPositions);

  if currentSize <= pruneCount {
    // Edge case: just clear all
    ArrayClear(player.m_betterNetrunning_breachedAccessPointPositions);
    ArrayClear(player.m_betterNetrunning_breachTimestamps);
    return;
  }

  // Bubble sort to find oldest records (timestamps are already sorted by insertion order,
  // but may be updated, so we need to sort)
  let idx: Int32 = 0;
  while idx < currentSize - 1 {
    let jdx: Int32 = 0;
    while jdx < currentSize - idx - 1 {
      if player.m_betterNetrunning_breachTimestamps[jdx] > player.m_betterNetrunning_breachTimestamps[jdx + 1] {
        // Swap timestamps
        let tempTimestamp: Uint64 = player.m_betterNetrunning_breachTimestamps[jdx];
        player.m_betterNetrunning_breachTimestamps[jdx] = player.m_betterNetrunning_breachTimestamps[jdx + 1];
        player.m_betterNetrunning_breachTimestamps[jdx + 1] = tempTimestamp;

        // Swap positions
        let tempPos: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[jdx];
        player.m_betterNetrunning_breachedAccessPointPositions[jdx] = player.m_betterNetrunning_breachedAccessPointPositions[jdx + 1];
        player.m_betterNetrunning_breachedAccessPointPositions[jdx + 1] = tempPos;
      }
      jdx += 1;
    }
    idx += 1;
  }

  // Remove oldest records
  let removeIdx: Int32 = 0;
  while removeIdx < pruneCount {
    ArrayErase(player.m_betterNetrunning_breachedAccessPointPositions, 0);
    ArrayErase(player.m_betterNetrunning_breachTimestamps, 0);
    removeIdx += 1;
  }
}

// Returns current game time as Uint64 timestamp
private func GetCurrentTimestamp(gameInstance: GameInstance) -> Uint64 {
  let gameTime: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gameInstance));
  return Cast<Uint64>(gameTime);
}

// ==================== Debug/Testing Functions ====================

/*
 * Debug: Returns count of recorded breaches
 * Useful for testing and monitoring memory usage
 */
public func GetBreachRecordCount(gameInstance: GameInstance) -> Int32 {
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    return 0;
  }
  return ArraySize(player.m_betterNetrunning_breachedAccessPointPositions);
}

/*
 * Debug: Clears all breach records
 * Useful for testing
 */
public func ClearAllBreachRecords(gameInstance: GameInstance) -> Void {
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    return;
  }
  ArrayClear(player.m_betterNetrunning_breachedAccessPointPositions);
  ArrayClear(player.m_betterNetrunning_breachTimestamps);
}

