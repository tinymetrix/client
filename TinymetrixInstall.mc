using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Application.Storage as Storage;
using Toybox.Lang as Lang;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixInstall {
        
        private static const INSTALL_FLAG_KEY = "tm.inst";
        private static var _cache = null as Lang.Boolean?;
        
    
        public static function markInstallTracked() as Void {
            _markInstallTracked();
            _cache = true; // Update cache
        }
        
        public static function wasInstallTracked() as Lang.Boolean {
            // Use cache if available
            if (_cache != null) {
                return _cache as Lang.Boolean;
            }
            // Load from storage and cache result
            var result = _wasInstallTracked();
            _cache = result;
            return result;
        }
        
        public static function clearInstallFlag() as Void {
            try {
                Storage.deleteValue(INSTALL_FLAG_KEY);
                _cache = false; // Update cache
            } catch(e) {
                if (TinymetrixConfig.isDebug()) { 
                    Sys.println("TM: Error clearing install flag: " + e.getErrorMessage()); 
                }
            }
        }
        
        private static function _wasInstallTracked() as Lang.Boolean {
            try {
                return Storage.getValue(INSTALL_FLAG_KEY) != null;
            } catch(e) {
                return false;
            }
        }

        private static function _markInstallTracked() as Void {
            try {
                Storage.setValue(INSTALL_FLAG_KEY, Time.now().value());
            } catch(e) {
                if (TinymetrixConfig.isDebug()) { 
                    Sys.println("TM: Error saving install flag: " + e.getErrorMessage()); 
                }
            }
        }
    }
}