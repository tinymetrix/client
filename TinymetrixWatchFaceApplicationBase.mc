import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.System as Sys;

(:barrel)
module Tinymetrix {
    (:background)
    class WatchFaceApplicationBase extends Application.AppBase {
        function initialize(config as Lang.Dictionary?) {
            Application.AppBase.initialize();
            
            if (config != null) {
                TinymetrixConfig.configure(config);
            }

            TinymetrixExecutionContext.markAsForegroundCommRestricted();
            Client.track(Tinymetrix.EventType.INSTALL);
        }

        function getInitialView() as [Views] or [Views, InputDelegates] {
            TinymetrixExecutionContext.markAsForeground();
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