import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Tinymetrix;

// Extends Tinymetrix.ApplicationBase (not WatchFaceApplicationBase, see the
// simple-watchface example) — it's the one that also auto-tracks
// SESSION_START/SESSION_END, which makes sense for a widget you open/close.
class SimpleAppApp extends Tinymetrix.ApplicationBase {

    function initialize() {
        Tinymetrix.ApplicationBase.initialize(null);
    }

    function onCreateView() as [Views] or [Views, InputDelegates] {
        return [ new SimpleAppView() ];
    }

    // Fires whenever the user changes a setting from Garmin Connect Mobile —
    // see resources/settings/settings.xml. This is the pattern for turning
    // "the user changed something" into an analytics event: track a custom
    // event, attach the new value as a user property, and log the outcome
    // either way.
    function onSettingsChanged() as Void {
        try {
            var minutes = Application.Properties.getValue("SyncIntervalMinutes") as Lang.Number?;
            if (minutes == null || minutes < 5 || minutes > 60) {
                Tinymetrix.Client.logError("Invalid SyncIntervalMinutes: " + minutes);
                return;
            }

            Tinymetrix.Client.setUserProperties({ "sync_interval_minutes" => minutes.toString() });
            Tinymetrix.Client.track("properties_changed");
            Tinymetrix.Client.logInfo("Settings updated: syncIntervalMinutes=" + minutes);
        } catch (e) {
            // A malformed property value, or Properties being briefly
            // unavailable right after a settings sync, land here.
            Tinymetrix.Client.logError("onSettingsChanged failed: " + e.getErrorMessage());
        }

        WatchUi.requestUpdate();
    }
}

function getApp() as SimpleAppApp {
    return Application.getApp() as SimpleAppApp;
}
