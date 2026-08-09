using Toybox.Lang as Lang;
using Toybox.System as Sys;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixExecutionContext {
        // En memoria - cada proceso (foreground/background) tiene su propia copia
        private static var _isForeground as Lang.Boolean = false;
        private static var _isForegroundCommRestricted as Lang.Boolean = false;

        // Llamar desde init() en getInitialView()
        public static function markAsForeground() as Void {
            _isForeground = true;
        }

        public static function markAsForegroundCommRestricted() as Void {
            _isForegroundCommRestricted = true;
        }

        public static function isForegroundCommRestricted() as Lang.Boolean {
            return _isForegroundCommRestricted;
        }

        // Verifica si estamos en foreground
        public static function isForeground() as Lang.Boolean {
            return _isForeground;
        }

        // Verifica si estamos en background (no se llamó init())
        public static function isBackground() as Lang.Boolean {
            var result = !_isForeground;
            return result;
        }
    }
}
