using Toybox.Test;
using Toybox.Lang;
using Toybox.Application.Storage as Storage;

module Tinymetrix {

    // -------------------------------------------------------------------------
    // wasInstallTracked / markInstallTracked
    // -------------------------------------------------------------------------

    (:test)
    function testInstallFlagFalseByDefault(logger as Test.Logger) as Lang.Boolean {
        TinymetrixInstall.clearInstallFlag();
        Test.assertEqual(false, TinymetrixInstall.wasInstallTracked());
        return true;
    }

    (:test)
    function testInstallFlagTrueAfterMark(logger as Test.Logger) as Lang.Boolean {
        TinymetrixInstall.clearInstallFlag();
        TinymetrixInstall.markInstallTracked();
        Test.assertEqual(true, TinymetrixInstall.wasInstallTracked());
        return true;
    }

    (:test)
    function testInstallFlagClearResetsToFalse(logger as Test.Logger) as Lang.Boolean {
        TinymetrixInstall.markInstallTracked();
        TinymetrixInstall.clearInstallFlag();
        Test.assertEqual(false, TinymetrixInstall.wasInstallTracked());
        return true;
    }

    (:test)
    function testInstallMarkIdempotent(logger as Test.Logger) as Lang.Boolean {
        TinymetrixInstall.clearInstallFlag();
        TinymetrixInstall.markInstallTracked();
        TinymetrixInstall.markInstallTracked(); // second call — should not crash
        Test.assertEqual(true, TinymetrixInstall.wasInstallTracked());
        return true;
    }

    (:test)
    function testInstallFlagPersistedAfterReRead(logger as Test.Logger) as Lang.Boolean {
        // Clear cache and force re-read from storage
        TinymetrixInstall.clearInstallFlag();
        TinymetrixInstall.markInstallTracked();
        // Force a fresh read by clearing cache via clearInstallFlag then re-marking
        // We verify Storage actually holds the value by reading it
        var stored = Storage.getValue("tm.inst");
        Test.assertEqual(true, stored != null);
        return true;
    }
}
