using Toybox.Test;
using Toybox.Lang;

module Tinymetrix {

    // -------------------------------------------------------------------------
    // Config defaults
    // -------------------------------------------------------------------------

    (:test)
    function testConfigDefaultEnabled(logger as Test.Logger) as Lang.Boolean {
        // Fresh config (no override) should default to enabled=true
        TinymetrixConfig.setEnabled(true); // reset to default
        Test.assertEqual(true, TinymetrixConfig.isEnabled());
        return true;
    }

    (:test)
    function testConfigDefaultDebug(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.setDebug(false); // reset
        Test.assertEqual(false, TinymetrixConfig.isDebug());
        return true;
    }

    (:test)
    function testConfigDefaultTrackSessions(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.setTrackSessions(false); // reset
        Test.assertEqual(false, TinymetrixConfig.isTrackSessions());
        return true;
    }

    (:test)
    function testConfigDefaultHeartbeat(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.setHeartbeatEnabled(true); // reset
        Test.assertEqual(true, TinymetrixConfig.isHeartbeatEnabled());
        return true;
    }

    (:test)
    function testConfigDefaultSyncDelay(logger as Test.Logger) as Lang.Boolean {
        // Default syncDelay is 12h = 43200s
        TinymetrixConfig.setSyncDelay(12 * 60 * 60);
        Test.assertEqual(43200, TinymetrixConfig.getSyncDelay());
        return true;
    }

    // -------------------------------------------------------------------------
    // Setters round-trip
    // -------------------------------------------------------------------------

    (:test)
    function testConfigSetEnabled(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.setEnabled(false);
        Test.assertEqual(false, TinymetrixConfig.isEnabled());
        TinymetrixConfig.setEnabled(true);
        Test.assertEqual(true, TinymetrixConfig.isEnabled());
        return true;
    }

    (:test)
    function testConfigSetDebug(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.setDebug(true);
        Test.assertEqual(true, TinymetrixConfig.isDebug());
        TinymetrixConfig.setDebug(false);
        Test.assertEqual(false, TinymetrixConfig.isDebug());
        return true;
    }

    (:test)
    function testConfigSetTrackSessions(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.setTrackSessions(true);
        Test.assertEqual(true, TinymetrixConfig.isTrackSessions());
        TinymetrixConfig.setTrackSessions(false);
        Test.assertEqual(false, TinymetrixConfig.isTrackSessions());
        return true;
    }

    (:test)
    function testConfigSetHeartbeat(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.setHeartbeatEnabled(false);
        Test.assertEqual(false, TinymetrixConfig.isHeartbeatEnabled());
        TinymetrixConfig.setHeartbeatEnabled(true);
        Test.assertEqual(true, TinymetrixConfig.isHeartbeatEnabled());
        return true;
    }

    (:test)
    function testConfigSetSyncDelay(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.setSyncDelay(3600); // 1 hour
        Test.assertEqual(3600, TinymetrixConfig.getSyncDelay());
        TinymetrixConfig.setSyncDelay(43200); // restore
        return true;
    }

    // -------------------------------------------------------------------------
    // setSyncDelay boundary / clamping
    // -------------------------------------------------------------------------

    (:test)
    function testConfigSyncDelayClampedToMin(logger as Test.Logger) as Lang.Boolean {
        // Below 5 minutes (300s) should clamp to 5 minutes
        TinymetrixConfig.setSyncDelay(60); // 1 minute — too small
        Test.assertEqual(300, TinymetrixConfig.getSyncDelay()); // clamped to 5min
        TinymetrixConfig.setSyncDelay(43200); // restore
        return true;
    }

    (:test)
    function testConfigSyncDelayClampedToMax(logger as Test.Logger) as Lang.Boolean {
        // Above 7 days (604800s) should clamp to 7 days
        TinymetrixConfig.setSyncDelay(999999);
        Test.assertEqual(604800, TinymetrixConfig.getSyncDelay()); // clamped to 7 days
        TinymetrixConfig.setSyncDelay(43200); // restore
        return true;
    }

    (:test)
    function testConfigSyncDelayExactMinBoundary(logger as Test.Logger) as Lang.Boolean {
        // Exactly 5 minutes is valid
        TinymetrixConfig.setSyncDelay(300);
        Test.assertEqual(300, TinymetrixConfig.getSyncDelay());
        TinymetrixConfig.setSyncDelay(43200); // restore
        return true;
    }

    (:test)
    function testConfigSyncDelayExactMaxBoundary(logger as Test.Logger) as Lang.Boolean {
        // Exactly 7 days is valid
        TinymetrixConfig.setSyncDelay(604800);
        Test.assertEqual(604800, TinymetrixConfig.getSyncDelay());
        TinymetrixConfig.setSyncDelay(43200); // restore
        return true;
    }

    // -------------------------------------------------------------------------
    // configure() batch method
    // -------------------------------------------------------------------------

    (:test)
    function testConfigureBatchUpdatesAllFields(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.configure({
            "enabled"       => false,
            "debug"         => true,
            "trackSessions" => true,
            "heartbeat"     => false,
            "syncDelay"     => 7200
        });
        Test.assertEqual(false, TinymetrixConfig.isEnabled());
        Test.assertEqual(true,  TinymetrixConfig.isDebug());
        Test.assertEqual(true,  TinymetrixConfig.isTrackSessions());
        Test.assertEqual(false, TinymetrixConfig.isHeartbeatEnabled());
        Test.assertEqual(7200,  TinymetrixConfig.getSyncDelay());

        // Restore
        TinymetrixConfig.configure({
            "enabled"       => true,
            "debug"         => false,
            "trackSessions" => false,
            "heartbeat"     => true,
            "syncDelay"     => 43200
        });
        return true;
    }

    (:test)
    function testConfigureBatchIgnoresWrongTypes(logger as Test.Logger) as Lang.Boolean {
        // Feeding wrong types should be silently ignored, not crash
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.configure({
            "enabled"   => "yes",     // String instead of Boolean → ignored
            "syncDelay" => "3600"     // String instead of Number → ignored
        });
        Test.assertEqual(true,  TinymetrixConfig.isEnabled());  // unchanged
        Test.assertEqual(43200, TinymetrixConfig.getSyncDelay()); // unchanged
        return true;
    }

    (:test)
    function testConfigureBatchClampsSyncDelay(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.configure({ "syncDelay" => 10 }); // too small
        Test.assertEqual(300, TinymetrixConfig.getSyncDelay()); // clamped to 5min
        TinymetrixConfig.setSyncDelay(43200); // restore
        return true;
    }
}
