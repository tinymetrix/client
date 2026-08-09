using Toybox.Test;
using Toybox.Lang;
using Toybox.Application.Storage as Storage;

module Tinymetrix {
    (:test)
    function testLoggerInfoAndError(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setDebug(true); // Shouldn't affect storage queue, just prints
        TinymetrixConfig.setSampleRate(1); // Disable sampling so duplicates don't interfere
        TinymetrixLogger.resetSampler();
        
        TinymetrixLogger.logInfo("Test info message");
        TinymetrixLogger.logError("Test error message");
        
        var size = TinymetrixStorageQueue.size();
        Test.assertEqual(2, size);
        
        var peeked = TinymetrixStorageQueue.peek(2);
        
        Test.assertEqual("Test info message", peeked[0].get("message"));
        Test.assertEqual("info", peeked[0].get("type"));
        
        Test.assertEqual("Test error message", peeked[1].get("message"));
        Test.assertEqual("error", peeked[1].get("type"));
        
        return true;
    }

    (:test)
    function testLoggerDisabled(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setEnabled(false);
        TinymetrixConfig.setSampleRate(1);
        TinymetrixLogger.resetSampler();
        
        TinymetrixLogger.logInfo("Test info message");
        
        var size = TinymetrixStorageQueue.size();
        Test.assertEqual(0, size); // Should not queue when disabled
        
        return true;
    }
}
