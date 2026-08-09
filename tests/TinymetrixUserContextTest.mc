using Toybox.Test;
using Toybox.Lang;
using Toybox.Application.Storage as Storage;

module Tinymetrix {
    (:test)
    function testUserContextDefaults(logger as Test.Logger) as Lang.Boolean {
        TinymetrixUserContext.clear(); // Use proper API to clear

        var userId = TinymetrixUserContext.getUserId();
        Test.assertEqual(true, userId == null);
        
        var props = TinymetrixUserContext.getUserProperties();
        Test.assertEqual(0, props.size());
        return true;
    }

    (:test)
    function testUserContextPersistence(logger as Test.Logger) as Lang.Boolean {
        TinymetrixUserContext.setUserId("test-user-123");
        var props = {"tier" => "premium", "age" => "30"}; // Must be String
        TinymetrixUserContext.setUserProperties(props as Lang.Dictionary);

        // Fetch back
        Test.assertEqual("test-user-123", TinymetrixUserContext.getUserId());
        
        var fetchedProps = TinymetrixUserContext.getUserProperties();
        Test.assertEqual(true, fetchedProps != null);
        Test.assertEqual("premium", fetchedProps.get("tier"));
        Test.assertEqual("30", fetchedProps.get("age"));
        
        return true;
    }
}
