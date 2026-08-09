import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Tinymetrix;

// Bare digital watch face: draws HH:MM centered, no layout resource needed.
class SimpleWatchFaceView extends WatchUi.WatchFace {

    function initialize() {
        WatchUi.WatchFace.initialize();
    }

    // Note: SESSION_START/SESSION_END aren't a fit here — a watch face's
    // onShow()/onHide() fire on every glance, not on a meaningful "session"
    // boundary, and only Tinymetrix.ApplicationBase auto-tracks those events
    // anyway. WatchFaceApplicationBase (used by this app) only tracks INSTALL.

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [
            clockTime.hour,
            clockTime.min.format("%02d"),
        ]);

        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_NUMBER_MEDIUM,
            timeString,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
