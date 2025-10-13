

module BetterNetrunning.CivilianPatch

import BetterNetrunningConfig.*
import BetterNetrunning.Common.*




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



@wrapMethod(ScriptedPuppet)
protected const func ShouldRegisterToHUD() -> Bool {
    // Crowds/vendors should register if they're quickhackable
    if (this.IsCrowd() || this.IsVendor()) && this.IsQuickHackAble() {
        return true;
    };
    
    return wrappedMethod();
}



@wrapMethod(ScriptedPuppet)
public const func CanRevealRemoteActionsWheel() -> Bool {
    // Allow crowds/vendors to show quickhack wheel
    if (this.IsCrowd() || this.IsVendor()) && this.IsQuickHackAble() {
        return true;
    };
    
    return wrappedMethod();
}



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