module BetterNetrunning.NPCs

import BetterNetrunningConfig.*
import BetterNetrunning.Common.*

/*
 * ============================================================================
 * NPC LIFECYCLE MODULE
 * ============================================================================
 *
 * PURPOSE:
 * Manages NPC network connection state throughout their lifecycle (active,
 * incapacitated, dead) to enable/disable unconscious NPC breaching.
 *
 * FUNCTIONALITY:
 * - Keeps NPCs connected to network when incapacitated (allows unconscious breach)
 * - Disconnects NPCs from network upon death (vanilla behavior)
 * - Adds breach action to unconscious NPC interaction menu
 * - Checks physical access point connection for radial unlock mode
 *
 * VANILLA DIFF:
 * - OnIncapacitated(): Removes this.RemoveLink() call to keep network connection active
 * - GetValidChoices(): Adds breach action to unconscious NPC interaction menu
 *
 * MOD COMPATIBILITY:
 * OnDeath() override was removed as it's 100% identical to vanilla behavior,
 * improving compatibility with other mods that may hook death events.
 *
 * ============================================================================
 */

// ==================== Incapacitation Handling ====================

/*
 * Keeps NPCs connected to network when incapacitated
 * VANILLA DIFF: Removes this.RemoveLink() call to keep network connection active
 * Allows quickhacking unconscious NPCs per mod design
 */
@replaceMethod(ScriptedPuppet)
protected func OnIncapacitated() -> Void {
  let incapacitatedEvent: ref<IncapacitatedEvent>;
  if this.IsIncapacitated() {
    return;
  }
  if !StatusEffectSystem.ObjectHasStatusEffectWithTag(this, n"CommsNoiseIgnore") {
    incapacitatedEvent = new IncapacitatedEvent();
    GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, incapacitatedEvent, 0.50);
  }
  this.m_securitySupportListener = null;
  // Keep network link active (do not call this.RemoveLink())
  this.EnableLootInteractionWithDelay(this);
  this.EnableInteraction(n"Grapple", false);
  this.EnableInteraction(n"TakedownLayer", false);
  this.EnableInteraction(n"AerialTakedown", false);
  this.EnableInteraction(n"NewPerkFinisherLayer", false);
  StatusEffectHelper.RemoveAllStatusEffectsByType(this, gamedataStatusEffectType.Cloaked);
  if this.IsBoss() {
    this.EnableInteraction(n"BossTakedownLayer", false);
  } else if this.IsMassive() {
    this.EnableInteraction(n"MassiveTargetTakedownLayer", false);
  }
  this.RevokeAllTickets();
  this.GetSensesComponent().ToggleComponent(false);
  this.GetBumpComponent().Toggle(false);
  this.UpdateQuickHackableState(false);
  if this.IsPerformingCallReinforcements() {
    this.HidePhoneCallDuration(gamedataStatPoolType.CallReinforcementProgress);
  }
  this.GetPuppetPS().SetWasIncapacitated(true);
  this.ProcessQuickHackQueueOnDefeat();
  CachedBoolValue.SetDirty(this.m_isActiveCached);
}

// ==================== Death Handling ====================

/*
 * Disconnects NPCs from network upon death
 * VANILLA DIFF: Identical to vanilla behavior (removed @replaceMethod for better mod compatibility)
 *
 * MOD COMPATIBILITY: This method is no longer overridden as it's identical to vanilla.
 * Better Netrunning now delegates death handling to vanilla logic.
 */
// @replaceMethod(ScriptedPuppet)
// REMOVED: This override is unnecessary (100% identical to vanilla)

// ==================== Network Connection Checks ====================

/*
 * Checks if device is connected to any access point controller
 * Used to determine if unconscious NPC breach is possible
 */
@addMethod(DeviceComponentPS)
public final func IsConnectedToPhysicalAccessPoint() -> Bool {
  let sharedGameplayPS: ref<SharedGameplayPS> = this as SharedGameplayPS;
  if !IsDefined(sharedGameplayPS) {
    return false;
  }
  let apControllers: array<ref<AccessPointControllerPS>> = sharedGameplayPS.GetAccessPoints();
  return ArraySize(apControllers) > 0;
}

// ==================== Unconscious NPC Breach Action ====================

/*
 * Adds breach action to unconscious NPC interaction menu
 * Allows breaching unconscious NPCs when connected to network
 */
@wrapMethod(ScriptedPuppetPS)
public final const func GetValidChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>, objectActionsCallbackController: wref<gameObjectActionsCallbackController>, checkPlayerQuickHackList: Bool, choices: script_ref<array<InteractionChoice>>) -> Void {
	if BetterNetrunningSettings.AllowBreachingUnconsciousNPCs() && this.IsConnectedToAccessPoint() && (!BetterNetrunningSettings.UnlockIfNoAccessPoint() || this.GetDeviceLink().IsConnectedToPhysicalAccessPoint()) && !this.m_betterNetrunningWasDirectlyBreached {
    ArrayPush(Deref(actions), TweakDBInterface.GetObjectActionRecord(t"Takedown.BreachUnconsciousOfficer"));
  }
	wrappedMethod(actions, context, objectActionsCallbackController, checkPlayerQuickHackList, choices);
}
