using Toybox.Test;
using Toybox.Lang;
using Toybox.Time as Time;
using Toybox.Application.Storage as Storage;

module Tinymetrix {

    // -------------------------------------------------------------------------
    // _isExpired tests
    // -------------------------------------------------------------------------

    (:test)
    function testServiceDelegateIsExpiredFresh(logger as Test.Logger) as Lang.Boolean {
        var delegate = new TinymetrixServiceDelegate(null);
        
        // A recent event (1 minute ago) should NOT be expired
        var ev = { "ts" => Time.now().value() - 60 };
        Test.assertEqual(false, delegate._isExpired(ev));
        return true;
    }

    (:test)
    function testServiceDelegateIsExpiredOld(logger as Test.Logger) as Lang.Boolean {
        var delegate = new TinymetrixServiceDelegate(null);
        
        // An event 8 days old should be expired (TTL = 7 days)
        var eightDaysAgo = Time.now().value() - (8 * 24 * 60 * 60);
        var ev = { "ts" => eightDaysAgo };
        Test.assertEqual(true, delegate._isExpired(ev));
        return true;
    }

    (:test)
    function testServiceDelegateIsExpiredNoTimestamp(logger as Test.Logger) as Lang.Boolean {
        var delegate = new TinymetrixServiceDelegate(null);
        
        // An event with no timestamp should NOT be expired (safe default)
        var ev = { "message" => "test" };
        Test.assertEqual(false, delegate._isExpired(ev));
        return true;
    }

    (:test)
    function testServiceDelegateIsExpiredLegacyTimestamp(logger as Test.Logger) as Lang.Boolean {
        var delegate = new TinymetrixServiceDelegate(null);
        
        // Should also handle "timestamp" key (legacy fallback)
        var recentTs = Time.now().value() - 60;
        var ev = { "timestamp" => recentTs };
        Test.assertEqual(false, delegate._isExpired(ev));
        return true;
    }

    // -------------------------------------------------------------------------
    // _loadChunk tests
    // -------------------------------------------------------------------------

    (:test)
    function testServiceDelegateLoadChunkEmpty(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        var delegate = new TinymetrixServiceDelegate(null);

        var chunk = delegate._loadChunk(10);
        Test.assertEqual(0, chunk.size());
        return true;
    }

    (:test)
    function testServiceDelegateLoadChunkRespectMax(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        var delegate = new TinymetrixServiceDelegate(null);
        TinymetrixConfig.setEnabled(true);

        // Add 5 fresh events manually
        for (var i = 0; i < 5; i++) {
            TinymetrixStorageQueue.append({ "ts" => Time.now().value(), "i" => i });
        }

        // Request max 3 - should get 3
        var chunk = delegate._loadChunk(3);
        Test.assertEqual(3, chunk.size());
        return true;
    }

    (:test)
    function testServiceDelegateLoadChunkSkipsExpired(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        var delegate = new TinymetrixServiceDelegate(null);

        // Add 2 expired events at the head
        var eightDaysAgo = Time.now().value() - (8 * 24 * 60 * 60);
        TinymetrixStorageQueue.append({ "ts" => eightDaysAgo, "msg" => "old1" });
        TinymetrixStorageQueue.append({ "ts" => eightDaysAgo, "msg" => "old2" });

        // Add 1 fresh event
        TinymetrixStorageQueue.append({ "ts" => Time.now().value(), "msg" => "fresh" });

        var chunk = delegate._loadChunk(10);

        // Expired events should have been trimmed - only fresh one returned
        Test.assertEqual(1, chunk.size());
        Test.assertEqual("fresh", chunk[0].get("msg"));
        return true;
    }

    // -------------------------------------------------------------------------
    // onHttpResponse tests
    // -------------------------------------------------------------------------

    (:test)
    function testServiceDelegateHttpResponse200DropsEvents(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        Storage.deleteValue("tm.sch.le");
        var delegate = new TinymetrixServiceDelegate(null);
        TinymetrixConfig.setEnabled(true);

        // Add events to queue
        for (var i = 0; i < 3; i++) {
            TinymetrixStorageQueue.append({ "ts" => Time.now().value(), "i" => i });
        }
        Test.assertEqual(3, TinymetrixStorageQueue.size());

        // Simulate a 200 OK response
        delegate.onHttpResponse(200, null);

        // Queue should have been dropped (up to MAX_PER_WAKE = 10)
        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testServiceDelegateHttpResponse4XXDropsEvents(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        Storage.deleteValue("tm.sch.le");
        var delegate = new TinymetrixServiceDelegate(null);
        TinymetrixConfig.setEnabled(true);

        for (var i = 0; i < 3; i++) {
            TinymetrixStorageQueue.append({ "ts" => Time.now().value(), "i" => i });
        }
        Test.assertEqual(3, TinymetrixStorageQueue.size());

        // 4XX = client error, discard events (retrying won't help)
        delegate.onHttpResponse(400, null);

        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testServiceDelegateHttpResponse5XXKeepsEvents(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        Storage.deleteValue("tm.sch.le");
        var delegate = new TinymetrixServiceDelegate(null);
        TinymetrixConfig.setEnabled(true);

        for (var i = 0; i < 3; i++) {
            TinymetrixStorageQueue.append({ "ts" => Time.now().value(), "i" => i });
        }
        Test.assertEqual(3, TinymetrixStorageQueue.size());

        // 5XX = server error, keep events for retry
        delegate.onHttpResponse(500, null);

        // Events should still be in queue
        Test.assertEqual(3, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testServiceDelegateHttpResponseNetworkErrorKeepsEvents(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        Storage.deleteValue("tm.sch.le");
        var delegate = new TinymetrixServiceDelegate(null);
        TinymetrixConfig.setEnabled(true);

        for (var i = 0; i < 2; i++) {
            TinymetrixStorageQueue.append({ "ts" => Time.now().value(), "i" => i });
        }
        Test.assertEqual(2, TinymetrixStorageQueue.size());

        // Garmin network error codes are negative (-200, -300, etc.)
        delegate.onHttpResponse(-200, null);

        // Events should still be in queue
        Test.assertEqual(2, TinymetrixStorageQueue.size());
        return true;
    }
}
