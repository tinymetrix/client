using Toybox.Lang as Lang;

(:barrel)
module Tinymetrix {
    (:background)
    class EventType {
        public enum EventType {
            SESSION_START = "session_started",
            SESSION_END = "session_ended", 
            INSTALL = "install",
            HEARTBEAT = "heartbeat"
        }
    }
}