using Toybox.System as Sys;
using Toybox.Application.Storage as Storage;
using Toybox.Lang as Lang;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixUserContext {
        
        private static const USER_CTX_KEY = "tm.uctx";
        private static var _cache = null as Lang.Dictionary<Lang.String, Lang.String> | Null;
        private static var _isLoaded = null as Lang.Boolean | Null;
        
        // === PUBLIC METHODS ===

        // Setter for the user ID
        public static function setUserId(userId as Lang.String | Null) as Void {
            _ensureLoaded();
            if (userId != null) {
                _cache.put("_user_id", userId);
                _saveUserContext();
            } else {
                // Remove the user ID if it is null
                if (_cache.hasKey("_user_id")) {
                    _cache.remove("_user_id");
                    _saveUserContext();
                }
            }
        }
        
        // Getter for the user ID
        public static function getUserId() as Lang.String | Null {
            return getValue("_user_id");
        }
        
        // Setter for user properties (batch)
        public static function setUserProperties(userProperties as Lang.Dictionary<Lang.String, Lang.String> | Null) as Void {
            if (userProperties == null) {
                return;
            }
            
            _ensureLoaded();
            var hasChanges = false;
            
            var keys = userProperties.keys();
            for (var i = 0; i < keys.size(); i++) {
                var k = keys[i] as Lang.String;
                var v = userProperties.get(k) as Lang.String;
                if (k != null && v != null) {
                    var propertyKey = "_user_property_" + k;
                    _cache.put(propertyKey, v);
                    hasChanges = true;
                }
            }
            
            if (hasChanges) {
                _saveUserContext();
            }
        }
        
        // Setter for a specific property
        public static function setUserProperty(key as Lang.String, value as Lang.String | Null) as Void {
            _ensureLoaded();
            var propertyKey = "_user_property_" + key;
            
            if (value != null) {
                _cache.put(propertyKey, value);
                _saveUserContext();
            } else {
                // Remove the property if the value is null
                if (_cache.hasKey(propertyKey)) {
                    _cache.remove(propertyKey);
                    _saveUserContext();
                }
            }
        }
        
        // Getter for a specific property
        public static function getUserProperty(key as Lang.String) as Lang.String | Null {
            return getValue("_user_property_" + key);
        }
        
        // Check if a user ID exists
        public static function hasUserId() as Lang.Boolean {
            _ensureLoaded();
            return _cache.hasKey("_user_id");
        }
        
        // Retrieve all user properties (excluding _user_id)
        public static function getUserProperties() as Lang.Dictionary<Lang.String, Lang.String> {
            _ensureLoaded();
            var properties = {} as Lang.Dictionary<Lang.String, Lang.String>;
            if (_cache != null) {
                var keys = _cache.keys();
                
                for (var i = 0; i < keys.size(); i++) {
                    var key = keys[i] as Lang.String;
                    if (key.find("_user_property_") == 0) {
                        // Extract the original property name
                        var originalKey = key.substring(15, key.length()); // Remove "_user_property_"
                        properties.put(originalKey, _cache.get(key) as Lang.String);
                    }
                }
            }
            
            return properties;
        }

        // Add user context directly to an existing meta dictionary (memory efficient)
        public static function addToMeta(meta as Lang.Dictionary) as Void {
            _ensureLoaded();
            if (_cache != null) {
                var keys = _cache.keys();
                for (var i = 0; i < keys.size(); i++) {
                    var key = keys[i] as Lang.String;
                    var value = _cache.get(key);
                    meta[key] = value;
                }
            }
        }
        
        // Getter - Return a copy to avoid external modifications (kept for backward compatibility)
        public static function getAll() as Lang.Dictionary<Lang.String, Lang.String> {
            _ensureLoaded();
            var copy = {} as Lang.Dictionary<Lang.String, Lang.String>;
            if (_cache != null) {
                var keys = _cache.keys();
                for (var i = 0; i < keys.size(); i++) {
                    var key = keys[i] as Lang.String;
                    var value = _cache.get(key);
                    if (value instanceof Lang.String) {
                        copy.put(key, value as Lang.String);
                    }
                }
            }
            return copy;
        }
        
        // Clear the entire context
        public static function clear() as Void {
            _ensureLoaded();
            _cache = _getDefaultUserContext();
            _saveUserContext();
        }
        
        // === PRIVATE METHODS ===
        
        // Load the user context once at startup
        private static function _ensureLoaded() as Void {
            if (_cache == null || _isLoaded == null || !_isLoaded) {
                _cache = _getDefaultUserContext();
                try {
                    var storedValue = Storage.getValue(USER_CTX_KEY);
                    if (storedValue instanceof Lang.Dictionary) {
                        _cache = storedValue as Lang.Dictionary<Lang.String, Lang.String>;
                    } else {
                        _saveUserContext();
                    }
                } catch(e) {
                    _saveUserContext();
                }
                _isLoaded = true;
            }
        }
        
        private static function _getDefaultUserContext() as Lang.Dictionary<Lang.String, Lang.String> {
            return {} as Lang.Dictionary<Lang.String, Lang.String>;
        }
        
        private static function _saveUserContext() as Void {
            if (_cache != null) {
                try {
                    Storage.setValue(USER_CTX_KEY, _cache);
                } catch(e) {
                    // Silent fail
                }
            }
        }
    
        
        // Getter for a specific value
        private static function getValue(key as Lang.String) as Lang.String | Null {
            _ensureLoaded();
            return _cache.get(key) as Lang.String | Null;
        }
        

    }
}
