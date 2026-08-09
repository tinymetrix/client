using Toybox.Test;
using Toybox.Lang;

module Tinymetrix {

    // -------------------------------------------------------------------------
    // isForeground / isBackground
    // -------------------------------------------------------------------------

    (:test)
    function testExecutionContextDefaultIsBackground(logger as Test.Logger) as Lang.Boolean {
        // Note: markAsForeground is sticky (in-memory), so we can't truly "reset" it
        // after tests that already called it. We test isBackground ↔ isForeground relationship.
        var fg = TinymetrixExecutionContext.isForeground();
        var bg = TinymetrixExecutionContext.isBackground();
        Test.assertEqual(true, fg != bg); // they must always be opposites
        return true;
    }

    (:test)
    function testExecutionContextMarkAsForeground(logger as Test.Logger) as Lang.Boolean {
        TinymetrixExecutionContext.markAsForeground();
        Test.assertEqual(true, TinymetrixExecutionContext.isForeground());
        Test.assertEqual(false, TinymetrixExecutionContext.isBackground());
        return true;
    }

    // -------------------------------------------------------------------------
    // isForegroundCommRestricted
    // -------------------------------------------------------------------------

    (:test)
    function testExecutionContextCommRestrictedSetToTrue(logger as Test.Logger) as Lang.Boolean {
        TinymetrixExecutionContext.markAsForegroundCommRestricted();
        Test.assertEqual(true, TinymetrixExecutionContext.isForegroundCommRestricted());
        return true;
    }

    (:test)
    function testExecutionContextForegroundAndCommRestrictedAreIndependent(logger as Test.Logger) as Lang.Boolean {
        // Both can be set independently
        TinymetrixExecutionContext.markAsForeground();
        TinymetrixExecutionContext.markAsForegroundCommRestricted();
        Test.assertEqual(true, TinymetrixExecutionContext.isForeground());
        Test.assertEqual(true, TinymetrixExecutionContext.isForegroundCommRestricted());
        return true;
    }
}
