using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Application.Storage as Storage;
using Toybox.Lang as Lang;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixHeartbeat {
        
        private static const LAST_ACTIVITY_KEY = "tm.hb.la";
        private static const HEARTBEAT_INTERVAL_SECONDS = 5 * 24 * 60 * 60; // 5 days
        
        public static function shouldSendHeartbeat() as Lang.Boolean {
            if (!TinymetrixConfig.isEnabled()) { return false; }
            if (!TinymetrixConfig.isHeartbeatEnabled()) { return false; }
            
            var now = Time.now().value();
            var lastActivity = _getLastActivity();

            // If we have never recorded activity, do not send a heartbeat yet
            if (lastActivity <= 0) {
                return false;
            }

            // If 5 days have passed since the last activity, send a heartbeat
            return (now - lastActivity) >= HEARTBEAT_INTERVAL_SECONDS;
        }
        
        public static function updateActivity() as Void {
            if (!TinymetrixConfig.isHeartbeatEnabled()) {
                return;
            }
            _updateLastActivity();
        }
        
        (:inline)
        private static function _isDebug() as Lang.Boolean {
            return TinymetrixConfig.isDebug();
        }
        
        // Private methods
        static private function _updateLastActivity() as Void {
            try {
                var now = Time.now().value();
                Storage.setValue(LAST_ACTIVITY_KEY, now);
                if (_isDebug()) { 
                    Sys.println("TM: Last activity updated to " + now); 
                }
            } catch(e) {
                if (_isDebug()) { Sys.println("TM: Error updating last activity: " + e.getErrorMessage()); }
            }
        }
        
        static private function _getLastActivity() as Lang.Number {
            try {
                var stored = Storage.getValue(LAST_ACTIVITY_KEY) as Lang.Number;
                return (stored == null) ? -1 : stored;
            } catch(e) {
                return -1;
            }
        }
    }
}
