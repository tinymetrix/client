using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Background as Bg;
using Toybox.Application.Storage as Storage;
using Toybox.Lang as Lang;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixScheduler {
        
        private static const LAST_EXECUTION_KEY = "tm.sch.le";
        private static var _lastEnsureCall = 0; // Prevent rapid multiple calls
        
        public static function ensureScheduled() as Void {
            if (!TinymetrixConfig.isEnabled()) { return; }

            var now = Time.now().value();
            
            // Prevent rapid multiple calls (within 1 second)
            if (_lastEnsureCall > 0 && (now - _lastEnsureCall) < 1) {
                if (_isDebug()) { 
                    Sys.println("TM: ensureScheduled called too soon after previous call, skipping"); 
                }
                return;
            }
            _lastEnsureCall = now;

            _doEnsureScheduled();
        }

        public static function ensureScheduledOnLaunch() as Void {
            if (!TinymetrixConfig.isEnabled()) { return; }

            // Always check and ensure proper scheduling on launch
            // This handles both initial setup and configuration changes
            if (_isDebug()) { 
                Sys.println("TM: Launch - ensuring scheduler is properly configured"); 
            }
            _doEnsureScheduled();
        }

        private static function _doEnsureScheduled() as Void {
            var currentSyncDelay = TinymetrixConfig.getSyncDelay();
            
            if (_isDebug()) { 
                Sys.println("TM: Current config: " + currentSyncDelay + "s, checking temporal event status"); 
            }
            
            try {
                var registered = Bg.getTemporalEventRegisteredTime();
                
                if (registered != null) {
                    // For Duration events, the value represents the interval duration in seconds
                    var programmedInterval = registered.value();
                    
                    if (_isDebug()) { 
                        Sys.println("TM: Found active temporal event with interval: " + programmedInterval + "s"); 
                    }
                    
                    // Simple comparison: if the current config differs from what's programmed, reprogram
                    if (programmedInterval != currentSyncDelay) {
                        if (_isDebug()) { 
                            Sys.println("TM: Config changed from " + programmedInterval + "s to " + currentSyncDelay + "s, reprogramming");
                        }
                        _scheduleNewTemporalEvent();
                    } else {
                        if (_isDebug()) { 
                            Sys.println("TM: Config matches active temporal event (" + currentSyncDelay + "s), no change needed"); 
                        }
                    }
                } else {
                    if (_isDebug()) { 
                        Sys.println("TM: No temporal event registered, programming initial event");
                    }
                    _scheduleNewTemporalEvent();
                }
            } catch(e) {
                if (_isDebug()) { 
                    Sys.println("TM: Error checking temporal event registration: " + e.getErrorMessage() + ", programming new event"); 
                }
                _scheduleNewTemporalEvent();
            }
        }

        public static function scheduleForPending() as Void {
            ensureScheduled();
        }

        public static function onExecutionCompleted() as Void {
            var now = Time.now().value();
            _setLastExecutionTime(now);
            if (_isDebug()) { Sys.println("TM: Execution completed, updated last execution time to " + now); }
        }
        
        public static function shouldExecuteNow() as Lang.Boolean {
            if (!TinymetrixConfig.isEnabled()) { return false; }
            
            var now = Time.now().value();
            var lastExecution = _getLastExecutionTime();
            var pending = TinymetrixStorageQueue.size();
            
            // If we have never executed, execute now
            if (lastExecution <= 0) {
                if (_isDebug()) { Sys.println("TM: Never executed, should execute now"); }
                return true;
            }
            
            var timeSinceLastExecution = now - lastExecution;
            
            var syncDelay = TinymetrixConfig.getSyncDelay();
            
            // If we have pending events and sync delay has elapsed, execute
            if (pending > 0 && timeSinceLastExecution >= syncDelay) {
                if (_isDebug()) { Sys.println("TM: Pending events + sync delay elapsed (" + (syncDelay/3600) + "h), should execute"); }
                return true;
            }
            
            // Check for heartbeat - only execute if it's actually time for heartbeat (5 days)
            // We check this every sync interval, and TinymetrixHeartbeat.shouldSendHeartbeat() handles the 5-day logic
            if (timeSinceLastExecution >= syncDelay) {
                if (TinymetrixHeartbeat.shouldSendHeartbeat()) {
                    if (_isDebug()) { Sys.println("TM: Heartbeat needed (5 days since last activity), should execute"); }
                    return true;
                }
            }
            
            return false;
        }
        
        // === PRIVATE METHODS ===
        
        (:inline)
        private static function _isDebug() as Lang.Boolean {
            return TinymetrixConfig.isDebug();
        }
        
        private static function _scheduleNewTemporalEvent() as Void {
            try {
                var syncDelay = TinymetrixConfig.getSyncDelay();
                var duration = new Time.Duration(syncDelay);
                Bg.registerForTemporalEvent(duration);
                
                if (_isDebug()) { 
                    Sys.println("TM: Scheduled recurring temporal event in " + syncDelay + " seconds"); 
                }
            } catch(e) {
                if (_isDebug()) { 
                    Sys.println("TM: Error scheduling temporal event: " + e.getErrorMessage()); 
                }
            }
        }
        
        private static function _getLastExecutionTime() as Lang.Number {
            try {
                var stored = Storage.getValue(LAST_EXECUTION_KEY) as Lang.Number;
                return (stored == null) ? -1 : stored;
            } catch(e) {
                return -1;
            }
        }

        private static function _setLastExecutionTime(ts as Lang.Number) as Void {
            try {
                Storage.setValue(LAST_EXECUTION_KEY, ts);
            } catch(e) {
                if (_isDebug()) { Sys.println("TM: Error persisting last execution time: " + e.getErrorMessage()); }
            }
        }
    }
}
