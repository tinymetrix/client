using Toybox.Test;
using Toybox.Lang;
using Toybox.Application.Storage as Storage;

module Tinymetrix {

    // -------------------------------------------------------------------------
    // append / size / peek
    // -------------------------------------------------------------------------

    (:test)
    function testQueueInitiallyEmpty(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testQueueAppendAndSize(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "event" => "a" });
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testQueuePeekReturnsCorrectItem(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "event" => "hello" });
        var peeked = TinymetrixStorageQueue.peek(1);
        Test.assertEqual(1, peeked.size());
        Test.assertEqual("hello", peeked[0].get("event"));
        return true;
    }

    (:test)
    function testQueuePeekDoesNotConsume(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "event" => "x" });
        TinymetrixStorageQueue.peek(1);
        Test.assertEqual(1, TinymetrixStorageQueue.size()); // still 1
        return true;
    }

    (:test)
    function testQueuePeekWithMaxLargerThanSize(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "event" => "only_one" });
        var peeked = TinymetrixStorageQueue.peek(100);
        Test.assertEqual(1, peeked.size()); // returns 1, not 100
        return true;
    }

    (:test)
    function testQueuePeekOnEmpty(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        var peeked = TinymetrixStorageQueue.peek(10);
        Test.assertEqual(0, peeked.size());
        return true;
    }

    (:test)
    function testQueuePreservesOrder(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "n" => "1" });
        TinymetrixStorageQueue.append({ "n" => "2" });
        TinymetrixStorageQueue.append({ "n" => "3" });
        var peeked = TinymetrixStorageQueue.peek(3);
        Test.assertEqual("1", peeked[0].get("n"));
        Test.assertEqual("2", peeked[1].get("n"));
        Test.assertEqual("3", peeked[2].get("n"));
        return true;
    }

    // -------------------------------------------------------------------------
    // appendMany
    // -------------------------------------------------------------------------

    (:test)
    function testQueueAppendMany(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        var evts = [{ "event" => "a" }, { "event" => "b" }] as Lang.Array<Lang.Dictionary>;
        TinymetrixStorageQueue.appendMany(evts);
        Test.assertEqual(2, TinymetrixStorageQueue.size());
        var peeked = TinymetrixStorageQueue.peek(2);
        Test.assertEqual("a", peeked[0].get("event"));
        Test.assertEqual("b", peeked[1].get("event"));
        return true;
    }

    // -------------------------------------------------------------------------
    // drop
    // -------------------------------------------------------------------------

    (:test)
    function testQueueDropPartial(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        var evts = [{ "n" => "a" }, { "n" => "b" }, { "n" => "c" }] as Lang.Array<Lang.Dictionary>;
        TinymetrixStorageQueue.appendMany(evts);

        TinymetrixStorageQueue.drop(2);
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        var peeked = TinymetrixStorageQueue.peek(1);
        Test.assertEqual("c", peeked[0].get("n"));
        return true;
    }

    (:test)
    function testQueueDropAll(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "n" => "x" });
        TinymetrixStorageQueue.drop(1);
        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testQueueDropMoreThanSize(logger as Test.Logger) as Lang.Boolean {
        // Dropping more elements than exist should not crash and should empty the queue
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "n" => "x" });
        TinymetrixStorageQueue.drop(100); // queue only has 1
        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testQueueDropZero(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "n" => "x" });
        TinymetrixStorageQueue.drop(0);
        Test.assertEqual(1, TinymetrixStorageQueue.size()); // unchanged
        return true;
    }

    (:test)
    function testQueueResetAfterFullDrop(logger as Test.Logger) as Lang.Boolean {
        // After fully draining, head and tail should reset so new items start from 0
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "n" => "x" });
        TinymetrixStorageQueue.drop(1); // empties queue → should reset head=0, tail=0
        TinymetrixStorageQueue.append({ "n" => "y" }); // should work without offset issues
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        var peeked = TinymetrixStorageQueue.peek(1);
        Test.assertEqual("y", peeked[0].get("n"));
        return true;
    }

    // -------------------------------------------------------------------------
    // MAX_SIZE overflow
    // -------------------------------------------------------------------------

    (:test)
    function testQueueMaxSizeDiscardOldest(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        var max = TinymetrixStorageQueue.MAX_SIZE;

        for (var i = 0; i < max + 5; i++) {
            TinymetrixStorageQueue.append({ "i" => i });
        }

        // Size should be capped at MAX_SIZE
        Test.assertEqual(max, TinymetrixStorageQueue.size());

        // The first 5 (oldest) should have been dropped
        var peeked = TinymetrixStorageQueue.peek(1);
        Test.assertEqual(5, peeked[0].get("i")); // item[0] was replaced by item[5]
        return true;
    }

    // -------------------------------------------------------------------------
    // clear
    // -------------------------------------------------------------------------

    (:test)
    function testQueueClearResets(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "n" => "a" });
        TinymetrixStorageQueue.append({ "n" => "b" });
        TinymetrixStorageQueue.clear();
        Test.assertEqual(0, TinymetrixStorageQueue.size());
        return true;
    }

    (:test)
    function testQueueClearThenAppendWorks(logger as Test.Logger) as Lang.Boolean {
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "n" => "first" });
        TinymetrixStorageQueue.clear();
        TinymetrixStorageQueue.append({ "n" => "after_clear" });
        Test.assertEqual(1, TinymetrixStorageQueue.size());
        var peeked = TinymetrixStorageQueue.peek(1);
        Test.assertEqual("after_clear", peeked[0].get("n"));
        return true;
    }
}
