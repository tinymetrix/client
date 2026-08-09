using Toybox.System as Sys;
using Toybox.Lang as Lang;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixLogger {
        
        // Use numeric constants instead of string enum to save memory
        private static const TYPE_INFO = 0;
        private static const TYPE_ERROR = 1;
        private static const TYPE_EVENT = 2;

        // --- Consecutive-duplicate sampler (in-memory only, resets on app restart) ---
        // Stores "message|type" of the last log that was enqueued
        private static var _lastFingerprint = null as Lang.String | Null;
        // How many times the current fingerprint has been seen consecutively
        private static var _dupCount = 0 as Lang.Number;
        
        public static function logInfo(message as Lang.String) as Void {
            _log(message, TYPE_INFO);
        }

        public static function logError(message as Lang.String) as Void {
            _log(message, TYPE_ERROR);
        }

        public static function logEvent(trackerName as Lang.String) as Void {
            _log(trackerName, TYPE_EVENT);
        }

        // Allows tests (and the app if needed) to reset sampler state
        public static function resetSampler() as Void {
            _lastFingerprint = null;
            _dupCount = 0;
        }
        
        // Main logging routine
        private static function _log(message as Lang.String, type as Lang.Number) as Void {
            if (!TinymetrixConfig.isEnabled()) { return; }

            // Deduplicate consecutive identical logs via sampling
            if (_shouldDropDuplicate(message, type)) {
                if (_isDebug()) {
                    Sys.println("TM: Sampled duplicate log (skipped): " + message);
                }
                return;
            }

            var meta = TinymetrixMeta.getMeta();
            meta["message"] = message;
            meta["type"] = (type == TYPE_INFO) ? "info" : ((type == TYPE_ERROR) ? "error" : "event");

            // Add user context directly (avoid copying dictionary)
            TinymetrixUserContext.addToMeta(meta);

            _enqueue(meta);
        }

        // Returns true if this log should be dropped because it's a sampled duplicate.
        // Consecutive identical (message + type) logs are kept 1-in-sampleRate.
        // The first occurrence of any fingerprint always passes.
        private static function _shouldDropDuplicate(message as Lang.String, type as Lang.Number) as Lang.Boolean {
            var fingerprint = message + "|" + type;

            if (_lastFingerprint == null || !fingerprint.equals(_lastFingerprint)) {
                // New distinct message — reset counter and always pass
                _lastFingerprint = fingerprint;
                _dupCount = 1;
                return false;
            }

            // Same fingerprint as last time
            _dupCount += 1;
            var rate = TinymetrixConfig.getSampleRate();

            if (rate <= 1) {
                // Sampling disabled — always pass
                return false;
            }

            // Drop unless this is the start of a new sampling window
            return (_dupCount % rate) != 1;
        }
        
        // Enqueue routine containing the full logic
        private static function _enqueue(evt as Lang.Dictionary) as Void {
            try {
                // 1. Persist the event in the queue
                TinymetrixStorageQueue.append(evt);
                
                // 2. Update heartbeat activity for every event
                // The heartbeat counts as activity too (indicates the app is alive)
                TinymetrixHeartbeat.updateActivity();
                
                // 3. Schedule the next dispatch
                TinymetrixScheduler.scheduleForPending();
                
            } catch (e) {
                if (_isDebug()) { Sys.println("TM: Error saving event: " + e.getErrorMessage()); }
            }
        }
    
        (:inline)
        private static function _isDebug() as Lang.Boolean {
            return TinymetrixConfig.isDebug();
        }
    }
}
