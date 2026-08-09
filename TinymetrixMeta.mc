using Toybox.System       as Sys;
using Toybox.Time         as Time;
using Toybox.Application  as App;
using Toybox.Lang         as Lang;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixMeta {
    
        private static const TM_TOKEN_KEY = "TinymetrixToken";
        
        // Cached values (primitives use less memory than a Dictionary)
        private static var _token = null;
        private static var _appName = null;
        private static var _appVer = null;
        private static var _deviceModel = null;
        private static var _firmware = null;
        private static var _apiLevel = null;
        private static var _deviceId = null;
    
        static public function getMeta() as Lang.Dictionary {
            // Lazy load static device info only once
            if (_token == null) {
                _loadStaticMeta();
            }
            
            // Build minimal dictionary with fresh timestamp
            return {
                "timestamp"     => Time.now().value(),
                "token"         => _token,
                "app_name"      => _appName,
                "app_ver"       => _appVer,
                "device_model"  => _deviceModel,
                "firmware"      => _firmware,
                "api_level"     => _apiLevel,
                "device_id"     => _deviceId
            };
        }
        
        private static function _loadStaticMeta() as Void {
            _token = _getToken();
            _appName = _getAppName();
            _appVer = _getAppVersion();
            
            var ds = Sys.getDeviceSettings();
            _deviceModel = ds.partNumber != null ? ds.partNumber : "unknown";
            _deviceId = ds.uniqueIdentifier != null ? ds.uniqueIdentifier : "unknown";
            _firmware = _getFirmwareVersion(ds);
            _apiLevel = _getApiLevel(ds);
        }
    
        (:inline)
        private static function _getToken() as Lang.String {
            try {  
                if (App.getApp() != null && App has :Properties) {
                    var tok = App.Properties.getValue(TM_TOKEN_KEY);
                    if (tok != null) {
                        return tok.toString();
                    }
                }
            } catch (e) {}
            return "unknown";
        }
        
        private static function _getAppName() as Lang.String {
            try {
                if (App.getApp() != null && App has :Properties) {
                    var appNameResource = App.Properties.getValue("AppName");
                    if (appNameResource != null) {
                        return appNameResource.toString();
                    }
                }
            } catch (e) {}
            
            return "unknown";
        }
        
        private static function _getAppVersion() as Lang.String {
            try {
                if (App.getApp() != null && App has :Properties) {
                    var v = App.Properties.getValue("AppVersion");
                    if (v != null) { return v.toString(); }
                }
            } catch (e) {}
            return "unknown";
        }

        private static function _getFirmwareVersion(ds) as Lang.String {
            try {
                if (ds.firmwareVersion != null) {
                    return Lang.format("$1$.$2$", ds.firmwareVersion);
                }
            } catch (e) {}
            return "unknown";
        }
        
        private static function _getApiLevel(ds) as Lang.String {
            try {
                if (ds has :monkeyVersion) {
                    return Lang.format("$1$.$2$.$3$", ds.monkeyVersion);
                }
            } catch (e) {}
            return "unknown";
        }
    }
}
