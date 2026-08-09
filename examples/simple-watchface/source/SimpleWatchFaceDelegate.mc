import Toybox.Lang;
import Toybox.WatchUi;
import Tinymetrix;

// Tapping the watch face tracks a custom event and logs through Tinymetrix —
// `track()` accepts any String, not just Tinymetrix.EventType values.
class SimpleWatchFaceDelegate extends WatchUi.WatchFaceDelegate {

    function initialize() {
        WatchUi.WatchFaceDelegate.initialize();
    }

    function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
        Tinymetrix.Client.logError("Power budget exceeded: " + powerInfo.executionTimeAverage + "ms avg");
    }
}
