// ============================================================================
// BetterNetrunning - Bonus Daemon Utilities
// ============================================================================
// Shared utility functions for applying bonus daemons to breach programs
//
// FEATURES:
// - Auto-execute PING on daemon success (AutoExecutePingOnSuccess setting)
// - Auto-apply Datamine based on success count (AutoDatamineBySuccessCount setting)
// - Centralized program detection (HasProgram, HasAnyDatamineProgram)
// - Success count calculation (CountNonDataminePrograms)
//
// USAGE:
// - AccessPoint breach: BreachProcessing.reds
// - RemoteBreach: RemoteBreachNetworkUnlock.reds
// - UnconsciousNPC breach: Future implementation
//
// DESIGN:
// - Global functions (no class dependency)
// - DRY principle (single source of truth)
// - Type-safe TweakDBID handling
// ============================================================================

module BetterNetrunning.Common

import BetterNetrunningConfig.*

// ============================================================================
// BONUS DAEMON APPLICATION
// ============================================================================

// Apply bonus daemons based on settings and success count
// - Auto-execute PING if any daemon succeeded (AutoExecutePingOnSuccess)
// - Auto-apply Datamine based on success count (AutoDatamineBySuccessCount)
//
// Parameters:
//   activePrograms: Array of successfully uploaded daemon programs (modified in-place)
//   gi: GameInstance for settings access
//   logContext: Optional context string for logging (e.g., "[RemoteBreach]", "[AccessPoint]")
public func ApplyBonusDaemons(
  activePrograms: script_ref<array<TweakDBID>>,
  gi: GameInstance,
  opt logContext: String
) -> Void {
  let successCount: Int32 = ArraySize(Deref(activePrograms));

  if successCount == 0 {
    return; // No successful daemons
  }

  // Feature 1: Auto-execute PING on any daemon success
  if BetterNetrunningSettings.AutoExecutePingOnSuccess() {
    if !HasProgram(Deref(activePrograms), t"MinigameAction.NetworkPing") {
      ArrayPush(Deref(activePrograms), t"MinigameAction.NetworkPing");

      if NotEquals(logContext, "") {
        BNLog(logContext + " Bonus Daemon: Auto-added PING (silent execution)");
      }
    }
  }

  // Feature 2: Auto-apply Datamine based on success count
  if BetterNetrunningSettings.AutoDatamineBySuccessCount() {
    let nonDatamineCount: Int32 = CountNonDataminePrograms(Deref(activePrograms));

    if nonDatamineCount > 0 && !HasAnyDatamineProgram(Deref(activePrograms)) {
      let datamineToAdd: TweakDBID;
      let logMessage: String;

      if nonDatamineCount >= 3 {
        datamineToAdd = t"MinigameAction.NetworkDataMineLootAllMaster";
        logMessage = "DatamineV3 (3+ daemons succeeded)";
      } else if nonDatamineCount == 2 {
        datamineToAdd = t"MinigameAction.NetworkDataMineLootAllAdvanced";
        logMessage = "DatamineV2 (2 daemons succeeded)";
      } else if nonDatamineCount == 1 {
        datamineToAdd = t"MinigameAction.NetworkDataMineLootAll";
        logMessage = "DatamineV1 (1 daemon succeeded)";
      }

      ArrayPush(Deref(activePrograms), datamineToAdd);

      if NotEquals(logContext, "") {
        BNLog(logContext + " Bonus Daemon: Auto-added " + logMessage);
      }
    }
  }
}

// ============================================================================
// PROGRAM DETECTION UTILITIES
// ============================================================================

// Check if programs array contains a specific program
public func HasProgram(programs: array<TweakDBID>, programID: TweakDBID) -> Bool {
  let i: Int32 = 0;
  while i < ArraySize(programs) {
    if Equals(programs[i], programID) {
      return true;
    }
    i += 1;
  }
  return false;
}

// Count non-Datamine programs (for auto-datamine feature)
// Returns the number of daemons that are NOT Datamine programs
public func CountNonDataminePrograms(programs: array<TweakDBID>) -> Int32 {
  let count: Int32 = 0;
  let i: Int32 = 0;

  while i < ArraySize(programs) {
    let programID: TweakDBID = programs[i];

    if programID != t"MinigameAction.NetworkDataMineLootAll"
       && programID != t"MinigameAction.NetworkDataMineLootAllAdvanced"
       && programID != t"MinigameAction.NetworkDataMineLootAllMaster" {
      count += 1;
    }

    i += 1;
  }

  return count;
}

// Check if any Datamine program exists in array
public func HasAnyDatamineProgram(programs: array<TweakDBID>) -> Bool {
  let i: Int32 = 0;
  while i < ArraySize(programs) {
    let programID: TweakDBID = programs[i];

    if programID == t"MinigameAction.NetworkDataMineLootAll"
       || programID == t"MinigameAction.NetworkDataMineLootAllAdvanced"
       || programID == t"MinigameAction.NetworkDataMineLootAllMaster" {
      return true;
    }

    i += 1;
  }
  return false;
}
