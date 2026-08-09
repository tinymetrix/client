using Toybox.Test;
using Toybox.Lang;
using Toybox.Application.Storage as Storage;
using Toybox.Background as Bg;
using Toybox.Time;

// =============================================================================
// Integration Test Suite
//
// These tests validate end-to-end behaviours of the library from the 
// perspective of the integrating developer — exactly as a real app would use it.
//
// Scenarios:
//   Suite A: App lifecycle — install, session tracking, scheduler setup
//   Suite B: WatchFace lifecycle — install only, comm-restricted context
//   Suite C: Background execution — onTemporalEvent flush logic
// =============================================================================

module Tinymetrix {

    // =========================================================================
    // HELPERS
    // =========================================================================

    function _clearState() as Void {
        TinymetrixStorageQueue.clear();
        TinymetrixInstall.clearInstallFlag();
        Storage.deleteValue("tm.sch.le");
        Storage.deleteValue("tm.hb.la");
        TinymetrixConfig.setEnabled(true);
        try {
            var a = Toybox.Application.getApp();
            a.setProperty("TinymetrixToken", "test-token");
            a.setProperty("AppName", "test-app");
            a.setProperty("AppVersion", "1.0.0");
        } catch(e) {}
    }

    // =========================================================================
    // SUITE A: App (non-watch-face) lifecycle
    // =========================================================================

    // A1 — On very first launch (fresh install), INSTALL event must be queued.
    (:test)
    function testAppFirstLaunchQueuesInstall(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var app = new ApplicationBase({
            "token" => "tk", "app_id" => "aid", "trackSessions" => false
        });
        app.getInitialView();

        var events = TinymetrixStorageQueue.peek(5);
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        Test.assertEqual(EventType.INSTALL, events[0].get("message"));
        return true;
    }

    // A2 — On second launch (already installed), INSTALL must NOT be re-queued.
    (:test)
    function testAppSecondLaunchNoInstall(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        // First launch
        var app1 = new ApplicationBase({
            "token" => "tk", "app_id" => "aid", "trackSessions" => false
        });
        app1.getInitialView();
        TinymetrixStorageQueue.clear(); // simulate queue flushed

        // Second launch — should NOT re-queue INSTALL
        var app2 = new ApplicationBase({
            "token" => "tk", "app_id" => "aid", "trackSessions" => false
        });
        app2.getInitialView();

        var events = TinymetrixStorageQueue.peek(5);
        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    // A3 — With sessions enabled, first launch queues INSTALL + SESSION_START.
    (:test)
    function testAppFirstLaunchWithSessionsQueuesInstallAndSessionStart(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var app = new ApplicationBase({
            "token" => "tk", "app_id" => "aid", "trackSessions" => true
        });
        app.getInitialView();

        Test.assertEqual(2, TinymetrixStorageQueue.size());
        var events = TinymetrixStorageQueue.peek(2);
        Test.assertEqual(EventType.INSTALL, events[0].get("message"));
        Test.assertEqual(EventType.SESSION_START, events[1].get("message"));
        return true;
    }

    // A4 — On app stop, SESSION_END must be queued (only in foreground context).
    (:test)
    function testAppStopQueuesSessionEnd(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var app = new ApplicationBase({
            "token" => "tk", "app_id" => "aid", "trackSessions" => true
        });
        app.getInitialView();
        TinymetrixStorageQueue.clear(); // simulate events already sent

        // Simulate foreground context so onStop actually tracks
        TinymetrixExecutionContext.markAsForeground();
        app.onStop(null);

        Test.assertEqual(1, TinymetrixStorageQueue.size());
        var events = TinymetrixStorageQueue.peek(1);
        Test.assertEqual(EventType.SESSION_END, events[0].get("message"));
        return true;
    }

    // A5 — getServiceDelegate() returns a TinymetrixServiceDelegate instance.
    (:test)
    function testAppGetServiceDelegateReturnsTinymetrixDelegate(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var app = new ApplicationBase({ "token" => "tk", "app_id" => "aid" });
        app.getInitialView();

        var delegates = app.getServiceDelegate();
        Test.assertEqual(true, delegates.size() > 0);
        Test.assertEqual(true, delegates[0] instanceof TinymetrixServiceDelegate);
        return true;
    }

    // A6 — After getServiceDelegate(), a temporal event should be registered.
    (:test)
    function testAppGetServiceDelegateRegistersTemporalEvent(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var app = new ApplicationBase({ "token" => "tk", "app_id" => "aid" });
        app.getInitialView();
        app.getServiceDelegate();

        // Verify a temporal event is registered (interval should be syncDelay)
        var registered = Bg.getTemporalEventRegisteredTime();
        Test.assertEqual(true, registered != null);
        Test.assertEqual(TinymetrixConfig.getSyncDelay(), registered.value());
        return true;
    }

    // =========================================================================
    // SUITE B: WatchFace lifecycle
    // =========================================================================

    // B1 — WatchFace first launch queues only INSTALL (no sessions by design).
    (:test)
    function testWatchFaceFirstLaunchQueuesInstallOnly(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var app = new WatchFaceApplicationBase({ "token" => "tk", "app_id" => "wf" });
        app.getInitialView();

        Test.assertEqual(1, TinymetrixStorageQueue.size());
        var events = TinymetrixStorageQueue.peek(1);
        Test.assertEqual(EventType.INSTALL, events[0].get("message"));
        return true;
    }

    // B2 — WatchFace marks context as foreground comm-restricted.
    (:test)
    function testWatchFaceMarksForegroundCommRestricted(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var app = new WatchFaceApplicationBase({ "token" => "tk", "app_id" => "wf" });
        app.getInitialView();

        Test.assertEqual(true, TinymetrixExecutionContext.isForegroundCommRestricted());
        return true;
    }

    // =========================================================================
    // SUITE C: Background execution (onTemporalEvent flush scenarios)
    // =========================================================================

    // C1 — If queue is empty, nothing is sent (no crash, no drop).
    (:test)
    function testBackgroundFlushEmptyQueueExitsCleanly(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        Storage.deleteValue("tm.sch.le"); // Never executed → shouldExecuteNow = true
        var delegate = new TinymetrixServiceDelegate(null);

        var chunk = delegate._loadChunk(10);
        Test.assertEqual(0, chunk.size());
        return true;
    }

    // C2 — Events in queue are correctly loaded into a chunk for sending.
    (:test)
    function testBackgroundFlushLoadsEventsIntoChunk(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var now = Time.now().value();
        TinymetrixStorageQueue.append({ "ts" => now, "message" => "install" });
        TinymetrixStorageQueue.append({ "ts" => now, "message" => "session_start" });
        TinymetrixStorageQueue.append({ "ts" => now, "message" => "custom_event" });

        var delegate = new TinymetrixServiceDelegate(null);
        var chunk = delegate._loadChunk(10);

        Test.assertEqual(3, chunk.size());
        Test.assertEqual("install",       chunk[0].get("message"));
        Test.assertEqual("session_start", chunk[1].get("message"));
        Test.assertEqual("custom_event",  chunk[2].get("message"));
        return true;
    }

    // C3 — Expired events (>7 days) are discarded from the head before flushing.
    (:test)
    function testBackgroundFlushDiscardsExpiredEventsBeforeSend(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var eightDaysAgo = Time.now().value() - (8 * 24 * 60 * 60);
        var now = Time.now().value();
        TinymetrixStorageQueue.append({ "ts" => eightDaysAgo, "message" => "old_event" });
        TinymetrixStorageQueue.append({ "ts" => now,          "message" => "fresh_event" });

        var delegate = new TinymetrixServiceDelegate(null);
        var chunk = delegate._loadChunk(10);

        // Only fresh event should be in chunk
        Test.assertEqual(1, chunk.size());
        Test.assertEqual("fresh_event", chunk[0].get("message"));
        return true;
    }

    // C4 — On successful HTTP 200, events are dropped from queue.
    (:test)
    function testBackgroundFlushOnSuccess200DropsQueuedEvents(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var now = Time.now().value();
        TinymetrixStorageQueue.append({ "ts" => now, "message" => "install" });
        TinymetrixStorageQueue.append({ "ts" => now, "message" => "session_start" });
        Test.assertEqual(2, TinymetrixStorageQueue.size());

        var delegate = new TinymetrixServiceDelegate(null);
        delegate.onHttpResponse(200, null);

        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    // C5 — On HTTP 5XX (server error), events are KEPT for retry.
    (:test)
    function testBackgroundFlushOnServerError5XXKeepsEvents(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var now = Time.now().value();
        TinymetrixStorageQueue.append({ "ts" => now, "message" => "install" });
        Test.assertEqual(1, TinymetrixStorageQueue.size());

        var delegate = new TinymetrixServiceDelegate(null);
        delegate.onHttpResponse(503, null);

        Test.assertEqual(1, TinymetrixStorageQueue.size());
        return true;
    }

    // C6 — On HTTP 4XX (client error), events are dropped (won't ever succeed).
    (:test)
    function testBackgroundFlushOnClientError4XXDropsEvents(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var now = Time.now().value();
        TinymetrixStorageQueue.append({ "ts" => now, "message" => "install" });
        Test.assertEqual(1, TinymetrixStorageQueue.size());

        var delegate = new TinymetrixServiceDelegate(null);
        delegate.onHttpResponse(401, null);

        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    // C7 — On network error (negative rc), events are KEPT for retry.
    (:test)
    function testBackgroundFlushOnNetworkErrorKeepsEvents(logger as Test.Logger) as Lang.Boolean {
        _clearState();
        var now = Time.now().value();
        TinymetrixStorageQueue.append({ "ts" => now, "message" => "install" });
        Test.assertEqual(1, TinymetrixStorageQueue.size());

        var delegate = new TinymetrixServiceDelegate(null);
        delegate.onHttpResponse(-200, null); // Garmin network error

        Test.assertEqual(1, TinymetrixStorageQueue.size());
        return true;
    }
}
