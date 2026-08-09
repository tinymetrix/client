using Toybox.Application.Storage as Storage;
using Toybox.Lang as Lang;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixStorageQueue {
        static const K_HEAD = "tmq.h";
        static const K_TAIL = "tmq.t";
        static const K_ITEM = "tmq.i"; // + index suffix
        static const MAX_SIZE = 100; // max events in queue
    
        // --- append: O(1), no need to read the entire queue ---
        static function append(evt as Lang.Dictionary) as Void {
            var tail = _getNum(K_TAIL, 0);
            var head = _getNum(K_HEAD, 0);
    
            // 1) Is the queue already full?
            if ((tail - head) >= MAX_SIZE) {
                // Discard the oldest event by advancing the head pointer
                Storage.deleteValue(K_ITEM + head);
                head += 1;
                Storage.setValue(K_HEAD, head);
            }
    
            // 2) Insert at the tail
            Storage.setValue(K_ITEM + tail, evt);
            Storage.setValue(K_TAIL, tail + 1);
        }
    
        static function appendMany(arr as Lang.Array<Lang.Dictionary>) as Void {
            var tail = _getNum(K_TAIL, 0);
            for (var i = 0; i < arr.size(); i += 1) {
                Storage.setValue(K_ITEM + tail, arr[i]);
                tail += 1;
            }
            Storage.setValue(K_TAIL, tail);
        }
    
        // --- peek: read up to max without consuming ---
        static function peek(max as Lang.Number) as Lang.Array<Lang.Dictionary> {
            var out  = [] as Lang.Array<Lang.Dictionary>;
            var head = _getNum(K_HEAD, 0);
            var tail = _getNum(K_TAIL, 0);
    
            var available = tail - head;
            if (available < 0) {
                available = 0;
            }
    
            if (max > available) {
                max = available;
            }
            
             var end = head + max;
    
            for (var i = head; i < end; i += 1) {
                var d = Storage.getValue(K_ITEM + i) as Lang.Dictionary;
                if (d != null) {
                    out.add(d);
                }
            }
            return out;
        }
    
        // --- drop: consume n elements (O(n) deletes, but n is small) ---
        static function drop(n as Lang.Number) as Void {
            var head = _getNum(K_HEAD, 0);
            var tail = _getNum(K_TAIL, 0);
    
            var to = head + n;
            if (to > tail) {
                to = tail;
            }
    
            // Optional: delete keys to keep storage from growing indefinitely
            for (var i = head; i < to; i += 1) {
                Storage.deleteValue(K_ITEM + i);
            }
            Storage.setValue(K_HEAD, to);
    
            // Compact indices from time to time
            if (to == tail) {
                // Empty queue → reset
                Storage.setValue(K_HEAD, 0);
                Storage.setValue(K_TAIL, 0);
            }
        }

        (:inline)
        static function size() as Lang.Number {
            var head = _getNum(K_HEAD, 0);
            var tail = _getNum(K_TAIL, 0);
            var s = tail - head;
            return (s < 0) ? 0 : s;
        }
    
        static function clear() as Void {
            var head = _getNum(K_HEAD, 0);
            var tail = _getNum(K_TAIL, 0);
            for (var i = head; i < tail; i += 1) {
                Storage.deleteValue(K_ITEM + i);
            }
            Storage.setValue(K_HEAD, 0);
            Storage.setValue(K_TAIL, 0);
        }
    
        // --- Helpers ---
        (:inline)
        static function _getNum(key as Lang.String, def as Lang.Number) as Lang.Number {
            try {
                var v = Storage.getValue(key) as Lang.Number;
                return (v == null) ? def : v;
            } catch(e) { return def; }
        }
    }
}
