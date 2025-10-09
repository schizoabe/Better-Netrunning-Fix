// ============================================================================
// BetterNetrunning - Progression System
// ============================================================================
//
// PURPOSE:
// Evaluates player progression requirements (Cyberdeck quality, Intelligence stat,
// Enemy Rarity) to determine quickhack unlock eligibility in Progressive Mode.
//
// FUNCTIONALITY:
// - Cyberdeck Quality: Checks player's equipped Cyberdeck tier (Common to Legendary++)
// - Intelligence Stat: Checks player's Intelligence attribute level
// - Enemy Rarity: Checks target NPC's difficulty rating (Weak to MaxTac)
// - AND/OR Logic: Supports "require all" or "require any" condition combinations
//
// VERSION HISTORY:
// - Release version: Used EnemyLevel for NPC progression checks
// - Latest version: Changed to EnemyRarity for more granular control (intentional design change)
//
// RATIONALE: EnemyRarity provides better progression curve:
// - Weak -> Normal -> Strong -> Elite -> Rare -> Boss -> MiniBoss -> MaxTac
// - More nuanced than simple level ranges
// - Aligned with vanilla game's enemy classification system
//
// USAGE:
// - Called from NPCs/NPCQuickhacks.reds and Devices/DeviceQuickhacks.reds
// - Integrates with BetterNetrunningSettings for user configuration
// ============================================================================

module BetterNetrunning.Progression

import BetterNetrunningConfig.*

// ============================================================================
// CYBERDECK QUALITY CHECKS
// ============================================================================

/// Converts config value (1-11) to gamedataQuality enum
/// @param value Config value from Native Settings (1=Common, 11=Legendary++)
/// @return Corresponding gamedataQuality enum value
public func CyberdeckQualityFromConfigValue(value: Int32) -> gamedataQuality {
  switch(value) {
    case 1:
      return gamedataQuality.Common;
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

/// Converts gamedataQuality enum to numeric rank (1-11) for comparison
/// Required because CDPR reordered enum values inconsistently
/// @param quality gamedataQuality enum value
/// @return Numeric rank (1=Common, 11=Legendary++)
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

/// Checks if player's Cyberdeck meets minimum quality requirement
/// @param gameInstance Current game instance
/// @param value Minimum required quality config value (1-11)
/// @return true if player's Cyberdeck quality >= required quality
public func CyberdeckConditionMet(gameInstance: GameInstance, value: Int32) -> Bool {
  let systemReplacementID: ItemID = EquipmentSystem.GetData(GetPlayer(gameInstance)).GetActiveItem(gamedataEquipmentArea.SystemReplacementCW);
  let itemRecord: wref<Item_Record> = RPGManager.GetItemRecord(systemReplacementID);
  let playerCyberdeckQuality: gamedataQuality = itemRecord.Quality().Type();
  let minQuality: gamedataQuality = CyberdeckQualityFromConfigValue(value);
  return CyberdeckQualityToRank(playerCyberdeckQuality) >= CyberdeckQualityToRank(minQuality);
}

// ============================================================================
// INTELLIGENCE STAT CHECKS
// ============================================================================

/// Checks if player's Intelligence stat meets minimum requirement
/// @param gameInstance Current game instance
/// @param value Minimum required Intelligence level
/// @return true if player's Intelligence >= required value
public func IntelligenceConditionMet(gameInstance: GameInstance, value: Int32) -> Bool {
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(gameInstance);
  let playerIntelligence: Int32 = Cast(statsSystem.GetStatValue(Cast(GetPlayer(gameInstance).GetEntityID()), gamedataStatType.Intelligence));
  return playerIntelligence >= value;
}

// ============================================================================
// ENEMY RARITY CHECKS
// ============================================================================

/// Converts NPC rarity enum to numeric rank (1-8) for comparison
/// @param rarity NPC's difficulty rating
/// @return Numeric rank (1=Trash, 8=MaxTac)
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

/// Checks if enemy rarity allows quickhack unlock
/// @param gameInstance Current game instance
/// @param enemy Target NPC entity
/// @param value Maximum allowed rarity rank (1-8)
/// @return true if enemy's rarity <= max allowed rarity
public func EnemyRarityConditionMet(gameInstance: GameInstance, enemy: wref<Entity>, value: Int32) -> Bool {
  let puppet: wref<ScriptedPuppet> = enemy as ScriptedPuppet;
  if !IsDefined(puppet) {
    return false;
  }
  let rarity: gamedataNPCRarity = puppet.GetNPCRarity();
  return NPCRarityToRank(rarity) <= value;
}

// ============================================================================
// COMBINED PROGRESSION CHECKS
// ============================================================================

/// Evaluates if NPC quickhacks should be unlocked based on progression settings
/// Supports AND/OR logic based on ProgressionRequireAll() setting
/// @param gameInstance Current game instance
/// @param enemy Target NPC entity
/// @param alwaysAllow If true, bypass all checks
/// @param cyberdeckValue Minimum Cyberdeck quality (1-11)
/// @param intelligenceValue Minimum Intelligence stat
/// @param enemyRarityValue Maximum enemy rarity (1-8)
/// @return true if NPC quickhacks should be unlocked
public func ShouldUnlockHackNPC(gameInstance: GameInstance, enemy: wref<Entity>, alwaysAllow: Bool, cyberdeckValue: Int32, intelligenceValue: Int32, enemyRarityValue: Int32) -> Bool {
  if alwaysAllow {
    return true;
  }

  let useConditionCyberdeck: Bool = BetterNetrunningSettings.ProgressionCyberdeckEnabled();
  let useConditionIntelligence: Bool = BetterNetrunningSettings.ProgressionIntelligenceEnabled();
  let useConditionEnemyRarity: Bool = BetterNetrunningSettings.ProgressionEnemyRarityEnabled();

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

/// Evaluates if device quickhacks should be unlocked based on progression settings
/// Supports AND/OR logic based on ProgressionRequireAll() setting
/// @param gameInstance Current game instance
/// @param alwaysAllow If true, bypass all checks
/// @param cyberdeckValue Minimum Cyberdeck quality (1-11)
/// @param intelligenceValue Minimum Intelligence stat
/// @return true if device quickhacks should be unlocked
public func ShouldUnlockHackDevice(gameInstance: GameInstance, alwaysAllow: Bool, cyberdeckValue: Int32, intelligenceValue: Int32) -> Bool {
  if alwaysAllow {
    return true;
  }

  let useConditionCyberdeck: Bool = BetterNetrunningSettings.ProgressionCyberdeckEnabled();
  let useConditionIntelligence: Bool = BetterNetrunningSettings.ProgressionIntelligenceEnabled();

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
