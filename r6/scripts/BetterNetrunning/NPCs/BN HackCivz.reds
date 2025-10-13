// ============================================================================
// BETTER NETRUNNING + HACKABLE CIVILIANS INTEGRATION
// ============================================================================
// This patches Better Netrunning to recognize crowds/vendors as hackable
// while respecting its breach/progression system

module BetterNetrunning.CivilianPatch

import BetterNetrunningConfig.*
import BetterNetrunning.Common.*


// ============================================================================
// STEP 1: Make crowds/vendors pass IsQuickHackAble() check
// ============================================================================

@wrapMethod(ScriptedPuppet)
public const func IsQuickHackAble() -> Bool {
    let actionRecords: array<wref<ObjectAction_Record>>;
    let i: Int32;
    
    // CUSTOM: Check if this is a crowd/vendor that should be hackable
    if this.IsCrowd() || this.IsVendor() {
        // Must still be active
        if !this.IsActive() {
            return false;
        };
        
        // Must have cyberdeck
        if !EquipmentSystem.IsCyberdeckEquipped(GameInstance.GetPlayerSystem(this.GetGame()).GetLocalPlayerControlledGameObject()) {
            return false;
        };
        
        // Must have quickhack actions defined
        if this.GetRecord().GetObjectActionsCount() <= 0 {
            return false;
        };
        
        // Must have at least one PuppetQuickHack action
        this.GetRecord().ObjectActions(actionRecords);
        i = 0;
        while i < ArraySize(actionRecords) {
            if Equals(actionRecords[i].ObjectActionType().Type(), gamedataObjectActionType.PuppetQuickHack) {
                return true;
            };
            i += 1;
        };
        
        return false;
    };
    
    // For non-crowds/vendors, use original logic
    return wrappedMethod();
}

// ============================================================================
// STEP 2: Patch Better Netrunning's permission calculation for crowds/vendors
// ============================================================================

/*  @wrapMethod(ScriptedPuppetPS)
private final func CalculateNPCHackPermissions() -> NPCHackPermissions {
    let permissions: NPCHackPermissions = wrappedMethod();
    let puppet: wref<ScriptedPuppet> = this.GetOwnerEntity() as ScriptedPuppet;
    
    // CUSTOM: Special handling for crowds and vendors
    if IsDefined(puppet) && (puppet.IsCrowd() || puppet.IsVendor()) {
        // Crowds/vendors REQUIRE breach (no auto-unlock from progression)
        // Only breach status unlocks their hacks
        if !permissions.isBreached {
            // Lock all categories if not breached
            permissions.allowCovert = false;
            permissions.allowCombat = false;
            permissions.allowControl = false;
            permissions.allowUltimate = false;
            permissions.allowPing = false;
            permissions.allowWhistle = false;
        }
        // If breached, keep whatever permissions were calculated
    };
    
    return permissions;
} */

// ============================================================================
// STEP 3: Fix attitude check for crowds/vendors (they're neutral, not hostile)
// ============================================================================

/* @wrapMethod(ScriptedPuppetPS)
private final func SetQuickhackInactiveReason(puppetAction: ref<PuppetAction>, attiudeTowardsPlayer: EAIAttitude) -> Void {
    let puppet: wref<ScriptedPuppet> = this.GetOwnerEntity() as ScriptedPuppet;
    
    // CUSTOM: Crowds/vendors use breach message instead of attitude message
    if IsDefined(puppet) && (puppet.IsCrowd() || puppet.IsVendor()) {
        puppetAction.SetInactiveWithReason(false, "LocKey#7021"); // "BREACH PROTOCOL REQUIRED"
        return;
    };
    
    // For regular enemies, use original attitude-based logic
    wrappedMethod(puppetAction, attiudeTowardsPlayer);
} */

// ============================================================================
// STEP 4: Ensure crowds/vendors show in HUD when scannable
// ============================================================================

@wrapMethod(ScriptedPuppet)
protected const func ShouldRegisterToHUD() -> Bool {
    // Crowds/vendors should register if they're quickhackable
    if (this.IsCrowd() || this.IsVendor()) && this.IsQuickHackAble() {
        return true;
    };
    
    return wrappedMethod();
}

// ============================================================================
// STEP 5: Make sure crowds/vendors can be revealed in network pulse
// ============================================================================

@wrapMethod(ScriptedPuppet)
public const func CanRevealRemoteActionsWheel() -> Bool {
    // Allow crowds/vendors to show quickhack wheel
    if (this.IsCrowd() || this.IsVendor()) && this.IsQuickHackAble() {
        return true;
    };
    
    return wrappedMethod();
}

// ============================================================================
// OPTIONAL: Visual feedback for unbreached crowds/vendors
// ============================================================================

@wrapMethod(ScriptedPuppet)
public const func GetDefaultHighlight() -> ref<FocusForcedHighlightData> {
    let highlight: ref<FocusForcedHighlightData>;
    let puppet: wref<ScriptedPuppet> = this;
    
    // CUSTOM: Show neutral outline for unbreached crowds/vendors
    if (puppet.IsCrowd() || puppet.IsVendor()) && puppet.IsQuickHackAble() {
        let ps: ref<ScriptedPuppetPS> = puppet.GetPS();
        
        // Check if breached
        if !ps.IsQuickHacksExposed() && ps.IsConnectedToAccessPoint() {
            highlight = new FocusForcedHighlightData();
            highlight.sourceID = puppet.GetEntityID();
            highlight.sourceName = puppet.GetClassName();
            highlight.highlightType = EFocusForcedHighlightType.NEUTRAL;
            highlight.outlineType = EFocusOutlineType.NEUTRAL;
            highlight.patternType = VisionModePatternType.Netrunner;
            highlight.priority = EPriority.Low;
            return highlight;
        };
    };
    
    return wrappedMethod();
}