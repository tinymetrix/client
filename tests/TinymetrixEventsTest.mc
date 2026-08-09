using Toybox.Test;
using Toybox.Lang;
using Toybox.Application.Storage as Storage;

module Tinymetrix {

    function _eventsSetup() as Void {
        try {
            var a = Toybox.Application.getApp();
            a.setProperty("TinymetrixToken", "test-token");
            a.setProperty("AppName", "test-app");
            a.setProperty("AppVersion", "1.0.0");
        } catch(e) {}
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setTrackSessions(false);
        TinymetrixStorageQueue.clear();
        TinymetrixInstall.clearInstallFlag();
    }

    // -------------------------------------------------------------------------
    // Generic custom events
    // -------------------------------------------------------------------------

    (:test)
    function testEventsCustomEventQueued(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixEvents.track("purchase");
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        Test.assertEqual("purchase", TinymetrixStorageQueue.peek(1)[0].get("message"));
        return true;
    }

    (:test)
    function testEventsCustomEventHasTimestamp(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixEvents.track("level_complete");
        var ev = TinymetrixStorageQueue.peek(1)[0];
        // The meta dict uses "timestamp" key from TinymetrixMeta
        var ts = ev.get("timestamp");
        Test.assertEqual(true, ts instanceof Lang.Number);
        Test.assertEqual(true, (ts as Lang.Number) > 0);
        return true;
    }

    (:test)
    function testEventsTrackingDisabledDropsEvent(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixConfig.setEnabled(false);
        TinymetrixEvents.track("ignored_event");
        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testEventsMultipleCustomEventsQueued(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixEvents.track("event_a");
        TinymetrixEvents.track("event_b");
        TinymetrixEvents.track("event_c");
        Test.assertEqual(3, TinymetrixStorageQueue.size());
        var peeked = TinymetrixStorageQueue.peek(3);
        Test.assertEqual("event_a", peeked[0].get("message"));
        Test.assertEqual("event_b", peeked[1].get("message"));
        Test.assertEqual("event_c", peeked[2].get("message"));
        return true;
    }

    // -------------------------------------------------------------------------
    // INSTALL idempotency
    // -------------------------------------------------------------------------

    (:test)
    function testEventsInstallTrackedOnce(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixEvents.track(Tinymetrix.EventType.INSTALL);
        TinymetrixEvents.track(Tinymetrix.EventType.INSTALL); // second call ignored
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testEventsInstallFlagSetAfterTracking(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        Test.assertEqual(false, TinymetrixInstall.wasInstallTracked());
        TinymetrixEvents.track(Tinymetrix.EventType.INSTALL);
        Test.assertEqual(true, TinymetrixInstall.wasInstallTracked());
        return true;
    }

    (:test)
    function testEventsInstallNotQueuedWhenDisabled(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixConfig.setEnabled(false);
        TinymetrixEvents.track(Tinymetrix.EventType.INSTALL);
        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    // -------------------------------------------------------------------------
    // SESSION events
    // -------------------------------------------------------------------------

    (:test)
    function testEventsSessionStartQueuedWhenEnabled(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixConfig.setTrackSessions(true);
        TinymetrixEvents.track(Tinymetrix.EventType.SESSION_START);
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        Test.assertEqual(EventType.SESSION_START, TinymetrixStorageQueue.peek(1)[0].get("message"));
        return true;
    }

    (:test)
    function testEventsSessionEndQueuedWhenEnabled(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixConfig.setTrackSessions(true);
        TinymetrixEvents.track(Tinymetrix.EventType.SESSION_END);
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        Test.assertEqual(EventType.SESSION_END, TinymetrixStorageQueue.peek(1)[0].get("message"));
        return true;
    }

    (:test)
    function testEventsSessionDroppedWhenSessionsDisabled(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixConfig.setTrackSessions(false);
        TinymetrixEvents.track(Tinymetrix.EventType.SESSION_START);
        TinymetrixEvents.track(Tinymetrix.EventType.SESSION_END);
        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    // -------------------------------------------------------------------------
    // HEARTBEAT events
    // -------------------------------------------------------------------------

    (:test)
    function testEventsHeartbeatQueuedWhenEnabled(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixConfig.setHeartbeatEnabled(true);
        TinymetrixEvents.track(Tinymetrix.EventType.HEARTBEAT);
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        Test.assertEqual(EventType.HEARTBEAT, TinymetrixStorageQueue.peek(1)[0].get("message"));
        return true;
    }

    (:test)
    function testEventsHeartbeatDroppedWhenDisabled(logger as Test.Logger) as Lang.Boolean {
        _eventsSetup();
        TinymetrixConfig.setHeartbeatEnabled(false);
        TinymetrixEvents.track(Tinymetrix.EventType.HEARTBEAT);
        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }
}
