using Toybox.Test;
using Toybox.Lang;
using Toybox.System as Sys;

module Tinymetrix {
    (:test)
    function testMetaDictionaryPayload(logger as Test.Logger) as Lang.Boolean {
        try {
            var app = Toybox.Application.getApp();
            app.setProperty("TinymetrixToken", "meta-test-token");
            app.setProperty("AppName", "meta-test-app");
            app.setProperty("AppVersion", "2.0.0");
        } catch(e) {}

        var meta = TinymetrixMeta.getMeta();
        
        Test.assertEqual("meta-test-token", meta.get("token"));
        Test.assertEqual("meta-test-app", meta.get("app_name"));
        Test.assertEqual("2.0.0", meta.get("app_ver"));
        
        Test.assertEqual(true, meta.get("timestamp") instanceof Lang.Number);
        
        // System derived properties
        Test.assertEqual(true, meta.get("device_model") instanceof Lang.String);
        Test.assertEqual(true, meta.get("device_id") instanceof Lang.String);
        Test.assertEqual(true, meta.get("firmware") instanceof Lang.String);
        Test.assertEqual(true, meta.get("api_level") instanceof Lang.String);
        
        return true;
    }
}
