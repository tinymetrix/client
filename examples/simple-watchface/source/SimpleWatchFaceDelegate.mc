import Toybox.Lang;
import Toybox.WatchUi;
import Tinymetrix;

// AMOLED devices call this when the watch face is eating more battery than
// its budget allows — a real error condition worth reporting, unlike the
// contrived examples logError call sites usually reach for.
class SimpleWatchFaceDelegate extends WatchUi.WatchFaceDelegate {

    function initialize() {
        WatchUi.WatchFaceDelegate.initialize();
    }

    function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
        Tinymetrix.Client.logError("Power budget exceeded: " + powerInfo.executionTimeAverage + "ms avg");
    }
}
