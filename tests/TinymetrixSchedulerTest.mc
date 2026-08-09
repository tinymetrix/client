using Toybox.Test;
using Toybox.Lang;
using Toybox.Application.Storage as Storage;

module Tinymetrix {

    // -------------------------------------------------------------------------
    // shouldExecuteNow
    // -------------------------------------------------------------------------

    (:test)
    function testSchedulerShouldExecuteOnFirstRun(logger as Test.Logger) as Lang.Boolean {
        Storage.deleteValue("tm.sch.le"); // no previous execution
        TinymetrixConfig.setEnabled(true);
        Test.assertEqual(true, TinymetrixScheduler.shouldExecuteNow());
        return true;
    }

    (:test)
    function testSchedulerShouldNotExecuteWhenDisabled(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.setEnabled(false);
        Test.assertEqual(false, TinymetrixScheduler.shouldExecuteNow());
        TinymetrixConfig.setEnabled(true); // restore
        return true;
    }

    (:test)
    function testSchedulerShouldNotExecuteIfRecentlyExecutedEmptyQueue(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setSyncDelay(43200); // 12h

        // Simulate very recent execution (1 second ago)
        var justNow = Toybox.Time.now().value() - 1;
        Storage.setValue("tm.sch.le", justNow);

        Test.assertEqual(false, TinymetrixScheduler.shouldExecuteNow());
        Storage.deleteValue("tm.sch.le"); // cleanup
        return true;
    }

    (:test)
    function testSchedulerShouldExecuteAfterSyncDelayWithPendingEvents(logger as Test.Logger) as Lang.Boolean {
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setSyncDelay(3600); // 1h for this test

        // Simulate last execution was 2 hours ago
        var twoHoursAgo = Toybox.Time.now().value() - (2 * 3600);
        Storage.setValue("tm.sch.le", twoHoursAgo);

        // Add a pending event
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "ts" => Toybox.Time.now().value(), "msg" => "pending" });

        Test.assertEqual(true, TinymetrixScheduler.shouldExecuteNow());

        Storage.deleteValue("tm.sch.le");
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setSyncDelay(43200); // restore
        return true;
    }

    // -------------------------------------------------------------------------
    // onExecutionCompleted
    // -------------------------------------------------------------------------

    (:test)
    function testSchedulerOnExecutionCompletedSetsTimestamp(logger as Test.Logger) as Lang.Boolean {
        Storage.deleteValue("tm.sch.le");
        TinymetrixConfig.setEnabled(true);
        TinymetrixStorageQueue.clear();

        TinymetrixScheduler.onExecutionCompleted();

        var stored = Storage.getValue("tm.sch.le") as Lang.Number;
        Test.assertEqual(true, stored != null);
        Test.assertEqual(true, stored > 0);
        return true;
    }

    (:test)
    function testSchedulerAfterCompletionShouldNotExecuteImmediately(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setSyncDelay(43200);

        TinymetrixScheduler.onExecutionCompleted(); // sets last exec to now

        // Empty queue + no elapsed time → should not execute
        Test.assertEqual(false, TinymetrixScheduler.shouldExecuteNow());
        Storage.deleteValue("tm.sch.le");
        return true;
    }
}
