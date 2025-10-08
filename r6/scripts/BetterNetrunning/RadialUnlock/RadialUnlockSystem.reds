// ============================================================================
// BetterNetrunning - Radial Unlock System
// ============================================================================
// Radial-based network breach tracking for standalone devices
//
// ARCHITECTURE:
// - Uses GameInstance.GetTargetingSystem() to find nearby devices
// - Records breached AccessPoint entity IDs in player's persistent storage
// - Standalone devices check if they're within breach radius of any recorded AP
//
// ADVANTAGES over hash-based approach:
// - Uses native TargetingSystem (same as RadialBreach mod)
// - No hash mismatch issues (devices found by spatial proximity)
// - Works for physically separate standalone devices
// - Configurable breach radius
// ============================================================================

module BetterNetrunning.RadialUnlock

import BetterNetrunning.Common.*
import BetterNetrunningConfig.*

// ============================================================================
// PLAYER PERSISTENT STORAGE
// ============================================================================

// Store breach positions instead of EntityIDs (more reliable)
@addField(PlayerPuppet)
public persistent let m_betterNetrunning_breachedAccessPointPositions: array<Vector4>;

@addField(PlayerPuppet)
public persistent let m_betterNetrunning_breachTimestamps: array<Uint64>;

// ============================================================================
// CONFIGURATION
// ============================================================================

/// Default breach radius (meters) - can be adjusted based on testing
/// @return Breach radius in meters (50m to cover wider network ranges)
public func GetDefaultBreachRadius() -> Float {
  return 50.0; // 50m to cover wider network ranges (increased from 30m)
}

/// Maximum stored breach records (prevents save bloat)
/// @return Maximum number of breach records to store
public func GetMaxBreachRecords() -> Int32 {
  return 50; // Reduced from 100 (only stores AccessPoint IDs, not device hashes)
}

/// Records to remove when pruning (20% of max)
/// @return Number of oldest records to remove when pruning
public func GetPruneCount() -> Int32 {
  return 10;
}

// ============================================================================
// CORE API
// ============================================================================

/// Records a successful AccessPoint breach by position
/// Called from RefreshSlaves() after breach minigame completion
/// Uses position-based tracking since EntityID retrieval is unreliable
/// @param apPosition World position of the breached AccessPoint
/// @param gameInstance Current game instance
public func RecordAccessPointBreachByPosition(apPosition: Vector4, gameInstance: GameInstance) -> Void {
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
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
      return;
    }
    idx += 1;
  }

  // Add new record
  ArrayPush(player.m_betterNetrunning_breachedAccessPointPositions, apPosition);
  ArrayPush(player.m_betterNetrunning_breachTimestamps, GetCurrentTimestamp(gameInstance));

  let newSize: Int32 = ArraySize(player.m_betterNetrunning_breachedAccessPointPositions);

  // Prune old records if limit exceeded
  if newSize > GetMaxBreachRecords() {
    PruneOldestBreachRecords(player);
  }
}

/// Legacy function for compatibility - now records by position
/// @param apEntityID Entity ID of the breached AccessPoint
/// @param gameInstance Current game instance
public func RecordAccessPointBreach(apEntityID: EntityID, gameInstance: GameInstance) -> Void {
  // Try to get entity position
  let apEntity: wref<GameObject> = GameInstance.FindEntityByID(gameInstance, apEntityID) as GameObject;
  if IsDefined(apEntity) {
    RecordAccessPointBreachByPosition(apEntity.GetWorldPosition(), gameInstance);
  }
}

/// Checks if a standalone device should be unlocked
/// Returns true if device is within breach radius of any recorded AccessPoint
/// @param device Device power state to check
/// @param gameInstance Current game instance
/// @return true if device should be unlocked (within breach radius or setting allows)
public func ShouldUnlockStandaloneDevice(device: ref<ScriptableDeviceComponentPS>, gameInstance: GameInstance) -> Bool {
  // CRITICAL FIX: UnlockIfNoAccessPoint setting logic
  // - UnlockIfNoAccessPoint = true -> Standalone devices ALWAYS unlock (don't require AP)
  // - UnlockIfNoAccessPoint = false -> Standalone devices require nearby breached AP

  if BetterNetrunningSettings.UnlockIfNoAccessPoint() {
    // Setting is TRUE -> Always unlock standalone devices without requiring AP
    return true;
  }

  // Setting is FALSE -> Require nearby breached AccessPoint

  // Get device position
  let deviceEntity: wref<GameObject> = device.GetOwnerEntityWeak() as GameObject;
  if !IsDefined(deviceEntity) {
    return false;
  }

  let devicePosition: Vector4 = deviceEntity.GetWorldPosition();
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);

  if !IsDefined(player) {
    return false;
  }

  // Check if within radius of any breached AccessPoint
  return IsWithinBreachedAccessPointRadius(devicePosition, player, gameInstance);
}

/// Checks if a position is within breach radius of any recorded AccessPoint
/// Now uses stored positions instead of EntityIDs
/// @param position World position to check
/// @param player Player puppet instance
/// @param gameInstance Current game instance
/// @return true if position is within breach radius of any recorded AccessPoint
private func IsWithinBreachedAccessPointRadius(position: Vector4, player: ref<PlayerPuppet>, gameInstance: GameInstance) -> Bool {
  let breachRadius: Float = GetDefaultBreachRadius();
  let breachRadiusSq: Float = breachRadius * breachRadius; // Use squared distance for performance

  let idx: Int32 = 0;
  while idx < ArraySize(player.m_betterNetrunning_breachedAccessPointPositions) {
    let apPosition: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[idx];
    let distanceSq: Float = Vector4.DistanceSquared(position, apPosition);

    if distanceSq <= breachRadiusSq {
      return true; // Within breach radius
    }

    idx += 1;
  }

  return false; // Not within any breach radius
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Removes oldest breach records when storage limit exceeded
/// @param player Player puppet instance
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

/// Returns current game time as Uint64 timestamp
/// @param gameInstance Current game instance
/// @return Current game time as Uint64
private func GetCurrentTimestamp(gameInstance: GameInstance) -> Uint64 {
  return Cast<Uint64>(EngineTime.ToFloat(GameInstance.GetSimTime(gameInstance)));
}

// ============================================================================
// RADIALBREACH INTEGRATION API
// ============================================================================

/// Gets the last breach position for a given AccessPoint
/// Used by RadialBreach integration to filter devices by physical distance
/// @param apPosition Position of the AccessPoint being checked
/// @param gameInstance Current game instance
/// @return Position of the last breach (or zero vector if not found)
public func GetLastBreachPosition(apPosition: Vector4, gameInstance: GameInstance) -> Vector4 {
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    BNLog("GetLastBreachPosition: Player not found");
    return Vector4(0.0, 0.0, 0.0, 1.0);
  }

  // Find the breach position closest to the given AccessPoint position
  let tolerance: Float = 5.0; // 5 meter tolerance for AccessPoint matching
  let idx: Int32 = ArraySize(player.m_betterNetrunning_breachedAccessPointPositions) - 1;

  while idx >= 0 {
    let breachPos: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[idx];
    let distance: Float = Vector4.Distance(breachPos, apPosition);

    if distance < tolerance {
      return breachPos;
    }
    idx -= 1;
  }

  // Not found - return the AccessPoint position itself as fallback
  return apPosition;
}

/// Checks if a device is within breach radius from any recorded breach position
/// Used by RadialBreach integration for physical distance filtering
/// @param devicePosition World position of the device to check
/// @param gameInstance Current game instance
/// @param maxDistance Maximum allowed distance (default: 50m)
/// @return true if device is within breach radius of any recorded breach
public func IsDeviceWithinBreachRadius(devicePosition: Vector4, gameInstance: GameInstance, opt maxDistance: Float) -> Bool {
  if maxDistance == 0.0 {
    maxDistance = GetDefaultBreachRadius(); // Default: 50m
  }

  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    return false;
  }

  // Check distance from all recorded breach positions
  let idx: Int32 = 0;
  while idx < ArraySize(player.m_betterNetrunning_breachedAccessPointPositions) {
    let breachPos: Vector4 = player.m_betterNetrunning_breachedAccessPointPositions[idx];
    let distance: Float = Vector4.Distance(breachPos, devicePosition);

    if distance <= maxDistance {
      return true;
    }
    idx += 1;
  }

  return false;
}

/// ✅ OPTIONAL: Alternative API - Gets last breach position by AccessPoint PersistentID
/// This is provided for API completeness and future extensibility.
/// Currently not used by the integration code (direct entity position is used instead).
/// @param apID PersistentID of the AccessPoint
/// @param gameInstance Current game instance
/// @return Recorded breach position, or error signal if not found
public func GetLastBreachPositionByID(apID: PersistentID, gameInstance: GameInstance) -> Vector4 {
  // Convert PersistentID to EntityID
  let entityID: EntityID = PersistentID.ExtractEntityID(apID);

  // Get GameObject from EntityID
  let apEntity: wref<GameObject> = GameInstance.FindEntityByID(gameInstance, entityID) as GameObject;

  if IsDefined(apEntity) {
    // Use the Vector4-based API with entity position
    let apPosition: Vector4 = apEntity.GetWorldPosition();
    return GetLastBreachPosition(apPosition, gameInstance);
  }

  // Error: Could not find entity
  return Vector4(-999999.0, -999999.0, -999999.0, 1.0);
}

// ============================================================================
// DEBUG/TESTING FUNCTIONS
// ============================================================================

/// Debug: Returns count of recorded breaches
/// Useful for testing and monitoring memory usage
/// @param gameInstance Current game instance
/// @return Number of recorded breach positions
public func GetBreachRecordCount(gameInstance: GameInstance) -> Int32 {
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    return 0;
  }
  return ArraySize(player.m_betterNetrunning_breachedAccessPointPositions);
}

/// Debug: Clears all breach records
/// Useful for testing
/// @param gameInstance Current game instance
public func ClearAllBreachRecords(gameInstance: GameInstance) -> Void {
  let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
  if !IsDefined(player) {
    return;
  }
  ArrayClear(player.m_betterNetrunning_breachedAccessPointPositions);
  ArrayClear(player.m_betterNetrunning_breachTimestamps);
}
