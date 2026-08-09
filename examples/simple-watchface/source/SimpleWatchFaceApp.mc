import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Tinymetrix;

// Extending Tinymetrix.WatchFaceApplicationBase instead of Application.AppBase
// is the only integration point required: it tracks the INSTALL event, starts
// the background sync service, and marks the execution context for you.
class SimpleWatchFaceApp extends Tinymetrix.WatchFaceApplicationBase {

    function initialize() {
        Tinymetrix.WatchFaceApplicationBase.initialize({
            "debug"     => true,           // verbose System.println while developing
            "syncDelay" => 6 * 60 * 60,    // flush queued events every 6h
        });

        // Everything below is regular Tinymetrix.Client usage — call it from
        // anywhere in your app, not just here.
        Tinymetrix.Client.setUserId("example-user");
        Tinymetrix.Client.setUserProperties({
            "plan" => "free",
        });
    }

    function onCreateView() as [Views] or [Views, InputDelegates] {
        return [ new SimpleWatchFaceView(), new SimpleWatchFaceDelegate() ];
    }
}

function getApp() as SimpleWatchFaceApp {
    return Application.getApp() as SimpleWatchFaceApp;
}
