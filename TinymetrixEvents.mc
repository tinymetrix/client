using Toybox.Lang as Lang;
using Toybox.System as Sys;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixEvents {
        
        // Primary method to track any event
        public static function track(eventType as EventType | Lang.String) as Void {
            if (!TinymetrixConfig.isEnabled()) { return; }

            // Handle install events
            if (_isInstallEvent(eventType)) {
                if (!_shouldTrackInstall()) { return; }
                _markInstallAsTracked();
            }

            // Handle session events with their specific logic
            if (_isSessionEvent(eventType)) {
                if (!_shouldTrackSessions()) { return; }
            }

            if (_isHeartbeatEvent(eventType)) {
                if (!_shouldTrackHeartbeat()) { return; }
            }

            // Log the event
            TinymetrixLogger.logEvent(eventType);

            // Install events trigger an immediate foreground flush
            if (_isInstallEvent(eventType)) {
                _flushForeground();
            }
        }
        
        
        // === PRIVATE LOGIC METHODS ===
        
        private static function _isInstallEvent(eventType as EventType | Lang.String) as Lang.Boolean {
            return eventType.equals(Tinymetrix.EventType.INSTALL);
        }
        
        private static function _isSessionEvent(eventType as EventType | Lang.String) as Lang.Boolean {
            return eventType.equals(Tinymetrix.EventType.SESSION_START) || eventType.equals(Tinymetrix.EventType.SESSION_END);
        }

        private static function _isHeartbeatEvent(eventType as EventType | Lang.String) as Lang.Boolean {
            return eventType.equals(Tinymetrix.EventType.HEARTBEAT);
        }

        private static function _shouldTrackHeartbeat() as Lang.Boolean {
            return TinymetrixConfig.isHeartbeatEnabled();
        }
        
        private static function _flushForeground() as Void {
            if (TinymetrixExecutionContext.isForegroundCommRestricted()) {
                if (TinymetrixConfig.isDebug()) {
                    Sys.println("TM: Skipping foreground flush (communications restricted)");
                }
                return;
            }

            try {
                TinymetrixForegroundSender.send();
            } catch(e) {
                if (TinymetrixConfig.isDebug()) {
                    Sys.println("TM: Error in foreground flush: " + e.getErrorMessage());
                }
            }
        }

        private static function _shouldTrackInstall() as Lang.Boolean {
            return !TinymetrixInstall.wasInstallTracked();
        }
        
        private static function _markInstallAsTracked() as Void {
            TinymetrixInstall.markInstallTracked();
        }
        
        private static function _shouldTrackSessions() as Lang.Boolean {
            return TinymetrixConfig.isTrackSessions();
        }
    }
}
