using Toybox.Lang as Lang;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixJsonSerializer {

        static function buildJsonArray(chunk as Lang.Array<Lang.Dictionary>) as Lang.String {
            var parts = [] as Lang.Array<Lang.String>;

            for (var i = 0; i < chunk.size(); i += 1) {
                var ev = chunk[i] as Lang.Dictionary;

                var kvs = [] as Lang.Array<Lang.String>;
                var keys = ev.keys();
                for (var j = 0; j < keys.size(); j += 1) {
                    var k = keys[j] as Lang.String;
                    var v = ev.get(k);

                    var vStr = "";
                    if (v == null) {
                        vStr = "null";
                    } else if (v instanceof Lang.String) {
                        var safe = v as Lang.String;
                        var escaped = "";
                        for (var c = 0; c < safe.length(); c += 1) {
                            var ch = safe.substring(c, c + 1);
                            if (ch.equals("\"")) {
                                escaped = escaped + "\\\"";
                            } else if (ch.equals("\\")) {
                                escaped = escaped + "\\\\";
                            } else {
                                escaped = escaped + ch;
                            }
                        }
                        vStr = "\"" + escaped + "\"";
                    } else if (v instanceof Lang.Number || v instanceof Lang.Float) {
                        vStr = v.toString();
                    } else if (v instanceof Lang.Boolean) {
                        vStr = (v as Lang.Boolean) ? "true" : "false";
                    } else {
                        vStr = "\"" + v.toString() + "\"";
                    }

                    kvs.add("\"" + k + "\":" + vStr);
                }

                var objStr = "{";
                var kvsArray = kvs as Lang.Array<Lang.String>;
                for (var k = 0; k < kvs.size(); k += 1) {
                    if (k > 0) { objStr = objStr + ","; }
                    objStr = objStr + kvsArray[k];
                }
                objStr = objStr + "}";
                parts.add(objStr);
            }

            var arrayStr = "[";
            var partsArray = parts as Lang.Array<Lang.String>;
            for (var p = 0; p < parts.size(); p += 1) {
                if (p > 0) { arrayStr = arrayStr + ","; }
                arrayStr = arrayStr + partsArray[p];
            }
            return arrayStr + "]";
        }
    }
}
