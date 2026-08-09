using Toybox.Application.Storage as Storage;
using Toybox.System as Sys;
using Toybox.Lang as Lang;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixConfig {
        
        private static const CONFIG_KEY = "tm.cfg";
        private static var _cache = null as Lang.Dictionary | Null;
        private static var _isLoaded = null as Lang.Boolean | Null;
        
        // Getters - Read-only from memory after the first load
        (:inline)
        public static function isEnabled() as Lang.Boolean {
            _ensureLoaded();
            var value = _cache.get("enabled");
            return (value instanceof Lang.Boolean) ? (value as Lang.Boolean) : true; // default true
        }
        
        (:inline)
        public static function isDebug() as Lang.Boolean {
            _ensureLoaded();
            var value = _cache.get("debug");
            return (value instanceof Lang.Boolean) ? (value as Lang.Boolean) : false; // default false
        }
        
        (:inline)
        public static function isTrackSessions() as Lang.Boolean {
            _ensureLoaded();
            var value = _cache.get("trackSessions");
            return (value instanceof Lang.Boolean) ? (value as Lang.Boolean) : false; // default false
        }

        (:inline)
        public static function isHeartbeatEnabled() as Lang.Boolean {
            _ensureLoaded();
            var value = _cache.get("heartbeat");
            return (value instanceof Lang.Boolean) ? (value as Lang.Boolean) : true; // default true
        }

        // How many consecutive identical logs to skip before letting one through.
        // 1 = disabled (everything passes). 10 = keep 1 in 10 identical consecutive logs.
        public static function getSampleRate() as Lang.Number {
            _ensureLoaded();
            var value = _cache.get("sampleRate");
            return (value instanceof Lang.Number) ? (value as Lang.Number) : 10; // default 10
        }

        public static function getSyncDelay() as Lang.Number {
            _ensureLoaded();
            var value = _cache.get("syncDelay");
            var result = (value instanceof Lang.Number) ? (value as Lang.Number) : (12 * 60 * 60);
            
            if (isDebug()) {
                Sys.println("TM: getSyncDelay() - cached: " + value + ", result: " + result + " (" + (result/3600) + "h)");
            }
            
            return result;
        }

        // Setters - Update the cache and persist to Storage
        public static function setEnabled(enabled as Lang.Boolean) as Void {
            _ensureLoaded();
            _cache.put("enabled", enabled);
            _saveConfig();
        }
        
        public static function setDebug(debug as Lang.Boolean) as Void {
            _ensureLoaded();
            _cache.put("debug", debug);
            _saveConfig();
        }
        
        public static function setTrackSessions(track as Lang.Boolean) as Void {
            _ensureLoaded();
            _cache.put("trackSessions", track);
            _saveConfig();
        }

        public static function setHeartbeatEnabled(enabled as Lang.Boolean) as Void {
            _ensureLoaded();
            _cache.put("heartbeat", enabled);
            _saveConfig();
        }

        public static function setSampleRate(rate as Lang.Number) as Void {
            _ensureLoaded();
            if (rate < 1) { rate = 1; } // 1 = effectively disabled
            _cache.put("sampleRate", rate);
            _saveConfig();
        }

        public static function setSyncDelay(delaySeconds as Lang.Number) as Void {
            _ensureLoaded();
            // Validate minimum delay (5 minutes) and maximum delay (7 days)
            var minDelay = 5 * 60; // 5 minutes
            var maxDelay = 7 * 24 * 60 * 60; // 7 days
            if (delaySeconds < minDelay) {
                delaySeconds = minDelay;
            } else if (delaySeconds > maxDelay) {
                delaySeconds = maxDelay;
            }
            _cache.put("syncDelay", delaySeconds);
            _saveConfig();
        }

        // Batch configuration - Single write to Storage
        public static function configure(config as Lang.Dictionary) as Void {
            _ensureLoaded();
            var hasChanges = false;
            
            // Process each available configuration
            if (config.hasKey("enabled")) {
                var value = config.get("enabled");
                if (value instanceof Lang.Boolean) {
                    _cache.put("enabled", value as Lang.Boolean);
                    hasChanges = true;
                }
            }
            
            if (config.hasKey("debug")) {
                var value = config.get("debug");
                if (value instanceof Lang.Boolean) {
                    _cache.put("debug", value as Lang.Boolean);
                    hasChanges = true;
                }
            }
            
            if (config.hasKey("trackSessions")) {
                var value = config.get("trackSessions");
                if (value instanceof Lang.Boolean) {
                    _cache.put("trackSessions", value as Lang.Boolean);
                    hasChanges = true;
                }
            }
            
            if (config.hasKey("heartbeat")) {
                var value = config.get("heartbeat");
                if (value instanceof Lang.Boolean) {
                    _cache.put("heartbeat", value as Lang.Boolean);
                    hasChanges = true;
                }
            }

            if (config.hasKey("syncDelay")) {
                var value = config.get("syncDelay");
                if (value instanceof Lang.Number) {
                    var delaySeconds = value as Lang.Number;
                    // Validate range
                    var minDelay = 5 * 60; // 5 minutes
                    var maxDelay = 7 * 24 * 60 * 60; // 7 days
                    if (delaySeconds < minDelay) {
                        delaySeconds = minDelay;
                    } else if (delaySeconds > maxDelay) {
                        delaySeconds = maxDelay;
                    }
                    _cache.put("syncDelay", delaySeconds);
                    hasChanges = true;
                }
            }

            if (config.hasKey("sampleRate")) {
                var value = config.get("sampleRate");
                if (value instanceof Lang.Number) {
                    var rate = value as Lang.Number;
                    if (rate < 1) { rate = 1; }
                    _cache.put("sampleRate", rate);
                    hasChanges = true;
                }
            }
            
            // Only persist if something changed
            if (hasChanges) {
                _saveConfig();
            }
        }

        // === PRIVATE METHODS ===

        // Load the configuration once at startup
        private static function _ensureLoaded() as Void {
            if (_cache == null || _isLoaded == null || !_isLoaded) {
                _cache = _getDefaultConfig();
                try {
                    var storedValue = Storage.getValue(CONFIG_KEY);
                    if (storedValue instanceof Lang.Dictionary) {
                        _cache = storedValue as Lang.Dictionary;
                    } else {
                        _saveConfig();
                    }
                } catch(e) {
                    _saveConfig();
                }
                _isLoaded = true;
            }
        }

        private static function _getDefaultConfig() as Lang.Dictionary {
            return {
                "enabled" => true,
                "debug" => false,
                "trackSessions" => false,
                "heartbeat" => true,
                "syncDelay" => 12 * 60 * 60,  // 12 hours default
                "sampleRate" => 10             // 1-in-10 for consecutive duplicates
            } as Lang.Dictionary;
        }

        private static function _saveConfig() as Void {
            if (_cache != null) {
                try {
                    Storage.setValue(CONFIG_KEY, _cache);
                } catch(e) {
                    // Silent fail
                }
            }
        }
    }
}
