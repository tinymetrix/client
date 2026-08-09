using Toybox.Test;
using Toybox.Lang;
using Toybox.Application.Storage as Storage;

module Tinymetrix {
    (:test)
    function testHeartbeatInitialState(logger as Test.Logger) as Lang.Boolean {
        Storage.deleteValue("tm.hb.la"); // Clear heartbeat
        TinymetrixConfig.setHeartbeatEnabled(true);
        
        // Initial state - should NOT heartbeat (no activity yet)
        Test.assertEqual(false, TinymetrixHeartbeat.shouldSendHeartbeat());
        return true;
    }

    (:test)
    function testHeartbeatAfterActivity(logger as Test.Logger) as Lang.Boolean {
        Storage.deleteValue("tm.hb.la"); // Clear heartbeat
        TinymetrixConfig.setHeartbeatEnabled(true);
        
        // Update activity
        TinymetrixHeartbeat.updateActivity();
        
        // Right after update - should NOT heartbeat
        Test.assertEqual(false, TinymetrixHeartbeat.shouldSendHeartbeat());
        return true;
    }

    (:test)
    function testHeartbeatAfterFiveDays(logger as Test.Logger) as Lang.Boolean {
        Storage.deleteValue("tm.hb.la"); // Clear heartbeat
        TinymetrixConfig.setHeartbeatEnabled(true);
        
        // Simulate 5 days passing
        var now = Toybox.Time.now().value();
        var fiveDaysAndOneSecAgo = now - (5 * 24 * 60 * 60) - 1;
        Storage.setValue("tm.hb.la", fiveDaysAndOneSecAgo);
        
        // Should now heartbeat!
        Test.assertEqual(true, TinymetrixHeartbeat.shouldSendHeartbeat());
        
        return true;
    }

    (:test)
    function testHeartbeatDisabled(logger as Test.Logger) as Lang.Boolean {
        Storage.deleteValue("tm.hb.la");
        TinymetrixConfig.setHeartbeatEnabled(false);
        
        // Even if no heartbeat recorded, if it's disabled it should be false
        Test.assertEqual(false, TinymetrixHeartbeat.shouldSendHeartbeat());
        
        return true;
    }
}
