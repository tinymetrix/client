import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Shows the current setting so it's visible on-device that
// onSettingsChanged() actually ran after a sync from Garmin Connect Mobile.
class SimpleAppView extends WatchUi.View {

    function initialize() {
        WatchUi.View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var minutes = Application.Properties.getValue("SyncIntervalMinutes");

        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_MEDIUM,
            "Sync: " + minutes + "m",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
