module BetterNetrunning.Logger

import BetterNetrunningConfig.*

/*
 * Centralized logging system for Better Netrunning mod
 * All log output is controlled by EnableDebugLog setting
 */

/*
 * Main logging function - checks EnableDebugLog setting before output
 * Use this instead of calling ModLog directly
 *
 * @param message The log message to output
 */
public static func BNLog(message: String) -> Void {
  if BetterNetrunningSettings.EnableDebugLog() {
    ModLog(n"BetterNetrunning", message);
  }
}
