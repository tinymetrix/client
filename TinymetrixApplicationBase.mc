import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.System as Sys;

(:barrel)
module Tinymetrix {
    (:background)
    class ApplicationBase extends Application.AppBase {
        private var _config as Lang.Dictionary? = null;

        function initialize(config as Lang.Dictionary?) {
            Application.AppBase.initialize();
            _config = config;
        }

        function onStop(state as Dictionary?) as Void {
            if (TinymetrixExecutionContext.isBackground()) {
                return;
            }
            Client.track(Tinymetrix.EventType.SESSION_END);
        }

        function getInitialView() as [Views] or [Views, InputDelegates] {
            TinymetrixExecutionContext.markAsForeground();

            if (_config != null) {
                TinymetrixConfig.configure(_config);
            }

            Client.track(Tinymetrix.EventType.INSTALL);
            Client.track(Tinymetrix.EventType.SESSION_START);
            return onCreateView();
        }

        // Override this method to provide your app's views.
        function onCreateView() as [Views] or [Views, InputDelegates] {
            return [] as [Views];
        }

        function getServiceDelegate() as Lang.Array {
            TinymetrixScheduler.ensureScheduledOnLaunch();
            
            var customDelegate = getBackgroundServiceDelegate();
            return [ new TinymetrixServiceDelegate(customDelegate) ] as Lang.Array;
        }

        // Override this method to provide your own service delegate
        // It will be called from Tinymetrix's background process.
        function getBackgroundServiceDelegate() as Sys.ServiceDelegate? {
            return null;
        }
    }
}