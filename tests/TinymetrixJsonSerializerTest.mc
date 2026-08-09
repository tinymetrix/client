using Toybox.Test;
using Toybox.Lang;

module Tinymetrix {
    (:test)
    function testJsonSerializerEmpty(logger as Test.Logger) as Lang.Boolean {
        var emptyArray = new [0];
        var json = TinymetrixJsonSerializer.buildJsonArray(emptyArray as Lang.Array<Lang.Dictionary>);
        Test.assertEqual("[]", json);
        return true;
    }

    (:test)
    function testJsonSerializerSimpleTypes(logger as Test.Logger) as Lang.Boolean {
        var dict = {
            "str" => "value",
            "num" => 42,
            "bool" => true
        };
        var chunk = new [1];
        chunk[0] = dict;
        var json = TinymetrixJsonSerializer.buildJsonArray(chunk as Lang.Array<Lang.Dictionary>);
        
        Test.assertEqual(true, json.find("\"str\":\"value\"") != null);
        Test.assertEqual(true, json.find("\"num\":42") != null);
        Test.assertEqual(true, json.find("\"bool\":true") != null);
        return true;
    }
}
