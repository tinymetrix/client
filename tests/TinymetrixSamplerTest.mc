using Toybox.Test;
using Toybox.Lang;

module Tinymetrix {

    (:test)
    function testSamplerFirstLogAlwaysPasses(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setSampleRate(10);
        TinymetrixLogger.resetSampler();

        TinymetrixLogger.logInfo("unique-message");

        Test.assertEqual(1, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testSamplerDropsConsecutiveDuplicates(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setSampleRate(10); // 1 passes, next 9 dropped, 11th passes, etc.
        TinymetrixLogger.resetSampler();

        // Log the same message 10 times — only the 1st should be enqueued
        for (var i = 0; i < 10; i += 1) {
            TinymetrixLogger.logInfo("repeated-message");
        }

        // Only the 1st passes; positions 2-10 are duplicates within the window
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testSamplerPassesEveryNthDuplicate(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setSampleRate(5); // 1-in-5
        TinymetrixLogger.resetSampler();

        // Log 15 times: positions 1, 6, 11 should pass (every 5th starting from 1)
        for (var i = 0; i < 15; i += 1) {
            TinymetrixLogger.logInfo("cycling-message");
        }

        // 3 windows of 5: positions 1, 6, 11 pass
        Test.assertEqual(3, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testSamplerResetsOnDifferentMessage(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setSampleRate(10);
        TinymetrixLogger.resetSampler();

        TinymetrixLogger.logInfo("message-A");  // passes (1st of A)
        TinymetrixLogger.logInfo("message-A");  // dropped (2nd of A)
        TinymetrixLogger.logInfo("message-A");  // dropped (3rd of A)

        TinymetrixLogger.logInfo("message-B");  // passes (1st of B — different fingerprint)
        TinymetrixLogger.logInfo("message-B");  // dropped (2nd of B)

        TinymetrixLogger.logInfo("message-A");  // passes (1st of A after B reset counter)

        Test.assertEqual(3, TinymetrixStorageQueue.size()); // A, B, A
        return true;
    }

    (:test)
    function testSamplerRateOneDisablesSampling(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setSampleRate(1); // 1 = disabled, all logs pass
        TinymetrixLogger.resetSampler();

        for (var i = 0; i < 5; i += 1) {
            TinymetrixLogger.logInfo("same-message-rate-one");
        }

        Test.assertEqual(5, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testSamplerDifferentTypesSameMessageNotDeduplicated(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixConfig.setEnabled(true);
        TinymetrixConfig.setSampleRate(10);
        TinymetrixLogger.resetSampler();

        // Same message string but different types → different fingerprint → all pass
        TinymetrixLogger.logInfo("my-message");   // passes (fingerprint: "my-message|0")
        TinymetrixLogger.logError("my-message");  // passes (fingerprint: "my-message|1")
        TinymetrixLogger.logInfo("my-message");   // passes (fingerprint changed back)

        Test.assertEqual(3, TinymetrixStorageQueue.size());
        return true;
    }
}
