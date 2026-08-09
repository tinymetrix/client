using Toybox.Lang as Lang;
using Toybox.System as Sys;

(:barrel)
module Tinymetrix {
    const INGEST_URL = "https://tinymetrix.com/api/ingest";

    (:background)
    class Client {

        // Log an informational message through the Tinymetrix logger.
        public static function logInfo(message as Lang.String) as Void {

            TinymetrixLogger.logInfo(message);
        }

        // Log an error message through the Tinymetrix logger.
        public static function logError(message as Lang.String) as Void {

            TinymetrixLogger.logError(message);
        }

        // Track a Tinymetrix event or custom event string.
        public static function track(event as EventType | Lang.String) as Void {

            TinymetrixEvents.track(event);
        }

        // Associate analytics activity with a specific user identifier.
        public static function setUserId(userId as Lang.String) as Void {

            TinymetrixUserContext.setUserId(userId);
        }

        // Persist a batch of user properties to be attached to future events.
        public static function setUserProperties(properties as Lang.Dictionary) as Void {

            TinymetrixUserContext.setUserProperties(properties);
        }
    }
}
