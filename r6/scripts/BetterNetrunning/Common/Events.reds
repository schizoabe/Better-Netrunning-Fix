// ============================================================================
// BetterNetrunning - Common Event Definitions
// ============================================================================
//
// PURPOSE:
// Defines custom events and persistent fields used across Better Netrunning modules
//
// EVENTS:
// - SetBreachedSubnet: Propagates breach state across network devices
//
// PERSISTENT FIELDS:
// - m_betterNetrunningWasDirectlyBreached: Tracks if NPC was directly breached
// - m_betterNetrunningBreachedBasic: Tracks if basic devices are breached
// - m_betterNetrunningBreachedNPCs: Tracks if NPCs are breached
// - m_betterNetrunningBreachedCameras: Tracks if cameras are breached
// - m_betterNetrunningBreachedTurrets: Tracks if turrets are breached
//
// USAGE:
// - Import this module in any script that needs to use these events/fields
// - Events are used by RadialBreachGating, betterNetrunning, etc.
// ============================================================================

module BetterNetrunning.Common

// ==================== Persistent Field Definitions ====================

// Persistent field for tracking direct breach on NPCs
@addField(ScriptedPuppetPS)
public persistent let m_betterNetrunningWasDirectlyBreached: Bool;

// Device breach state fields (used by SetBreachedSubnet event)
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedBasic: Bool;
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedNPCs: Bool;
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedCameras: Bool;
@addField(SharedGameplayPS)
public persistent let m_betterNetrunningBreachedTurrets: Bool;

// ==================== Breach State Event System ====================

/*
 * Custom event for propagating breach state across network devices
 * Sent to all devices when subnet is successfully breached
 */
public class SetBreachedSubnet extends ActionBool {

  public let breachedBasic: Bool;
  public let breachedNPCs: Bool;
  public let breachedCameras: Bool;
  public let breachedTurrets: Bool;

  public final func SetProperties() -> Void {
    this.actionName = n"SetBreachedSubnet";
    this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(this.actionName, true, n"SetBreachedSubnet", n"SetBreachedSubnet");
  }

  public func GetTweakDBChoiceRecord() -> String {
    return "SetBreachedSubnet";
  }

  public final static func IsAvailable(device: ref<ScriptableDeviceComponentPS>) -> Bool {
    return true;
  }

  public final static func IsClearanceValid(clearance: ref<Clearance>) -> Bool {
    if Clearance.IsInRange(clearance, 2) {
      return true;
    };
    return false;
  }

  public final static func IsContextValid(const context: script_ref<GetActionsContext>) -> Bool {
    if Equals(Deref(context).requestType, gamedeviceRequestType.Direct) {
      return true;
    };
    return false;
  }

}

// Event handler: Updates device breach state when subnet is breached
@addMethod(SharedGameplayPS)
public func OnSetBreachedSubnet(evt: ref<SetBreachedSubnet>) -> EntityNotificationType {
  if evt.breachedBasic {
    this.m_betterNetrunningBreachedBasic = true;
  }
  if evt.breachedNPCs {
    this.m_betterNetrunningBreachedNPCs = true;
  }
  if evt.breachedCameras {
    this.m_betterNetrunningBreachedCameras = true;
  }
  if evt.breachedTurrets {
    this.m_betterNetrunningBreachedTurrets = true;
  }
  return EntityNotificationType.DoNotNotifyEntity;
}
