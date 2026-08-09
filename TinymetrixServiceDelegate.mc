using Toybox.System as Sys;
using Toybox.Background as Bg;
using Toybox.Time as Time;
using Toybox.Lang as Lang;
using Toybox.Communications as Comm;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixServiceDelegate extends Sys.ServiceDelegate {
        private static const ENDPOINT_URL    = Tinymetrix.INGEST_URL;
        private static const MAX_PER_WAKE    = 10;      // max events to send per wake
        private static const EVENT_TTL_SECS  = 7*24*60*60; // discard events older than 7 days
    
        private var _proxyDelegate as Sys.ServiceDelegate? = null;

        function initialize(proxyDelegate as Sys.ServiceDelegate?) { 
            Sys.ServiceDelegate.initialize(); 
            _proxyDelegate = proxyDelegate;
        }
    
        function onTemporalEvent() {
            if (_proxyDelegate != null && _proxyDelegate has :onTemporalEvent) {
                _proxyDelegate.onTemporalEvent();
            }

            if (_isDebug()) { 
                Sys.println("TM: onTemporal triggered at " + Time.now().value()); 
            }

            // Always ensure we have a scheduled temporal event for the next execution
            TinymetrixScheduler.ensureScheduled();

            // Check if we should actually execute now based on our logic
            if (!TinymetrixScheduler.shouldExecuteNow()) {
                if (_isDebug()) { 
                    Sys.println("TM: Not time to execute, exiting"); 
                }
                // Still mark execution completed to maintain the 24h cycle
                TinymetrixScheduler.onExecutionCompleted();
                Bg.exit(true);
                return;
            }

            if (_isDebug()) { 
                Sys.println("TM: Executing scheduler logic"); 
            }

            // Check whether a heartbeat should be sent and trigger it if needed
            if (TinymetrixHeartbeat.shouldSendHeartbeat()) {
                if (_isDebug()) { Sys.println("TM: Service triggering heartbeat"); }
                TinymetrixEvents.track(Tinymetrix.EventType.HEARTBEAT);
            }
    
            // 1) Remove expired events at the head and load a chunk without consuming
            var chunk = _loadChunk(MAX_PER_WAKE);
            var count = (chunk == null) ? 0 : chunk.size();
            if (_isDebug()) {
                Sys.println("TM[v0.1] wake " + Time.now().value() + " sending=" + count + "/" + TinymetrixStorageQueue.size());
            }
    
            if (count == 0) {
                // Mark execution as completed even if no events were sent
                TinymetrixScheduler.onExecutionCompleted();
                Bg.exit(true);
                return;
            }
    
            // 2) Build the actual payload with the events
            var payload = TinymetrixJsonSerializer.buildJsonArray(chunk);
            var params = { "batch" => payload } as Lang.Dictionary;
    
            // 3) Perform the actual POST request to send data
            var opts = {
                :method       => Comm.HTTP_REQUEST_METHOD_POST,
                :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            } as Lang.Dictionary;
    
            var targetUrl = ENDPOINT_URL;
    
    
            try {
                // Debug information before the request
                if (_isDebug()) {
                    Sys.println("=== PRE-REQUEST DEBUG ===");
                    Sys.println("Events count: " + count);
                    Sys.println("Queue size: " + TinymetrixStorageQueue.size());
                    Sys.println("Target URL: " + targetUrl);
                    Sys.println("Method: POST with payload");
                }
                
                // Perform the request with the payload
                Comm.makeWebRequest(targetUrl, params, opts, new Lang.Method(self, :onHttpResponse));
            } catch(e) {
                if (_isDebug()) { Sys.println("Error making web request: " + e.getErrorMessage()); }
                // Mark execution as completed even when HTTP request fails to maintain schedule
                TinymetrixScheduler.onExecutionCompleted();
                Bg.exit(true);
            }
        }
        
        function onHttpResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void  {
            try {
                var rc = (responseCode == null) ? -1 : responseCode as Lang.Number;
                if (_isDebug()) {
                    Sys.println("=== HTTP RESPONSE DEBUG ===");
                    Sys.println("Response Code: " + rc);
                }
                
                if (_isDebug()) {
                    var dataInfo = "null";
                    if (data != null) {
                        if (data instanceof Lang.Dictionary) {
                            dataInfo = "Dictionary with " + (data as Lang.Dictionary).keys().size() + " keys";
                        } else if (data instanceof Lang.String) {
                            var dataStr = data as Lang.String;
                            dataInfo = "String: " + (dataStr.length() > 50 ? dataStr.substring(0, 50) + "..." : dataStr);
                        } else {
                            dataInfo = "Type: " + data.toString();
                        }
                    }
                    Sys.println("Data: " + dataInfo);
                }
                
                var ok = (rc >= 200 && rc < 300);
                if (_isDebug()) { Sys.println("GA send rc=" + rc + (ok ? " OK" : " FAIL")); }

                // Specific error code analysis
                if (rc < 0) {
                    if (_isDebug()) {
                        if (rc == -200) {
                            Sys.println("ERROR -200: Network/Communication error");
                        } else if (rc == -400) {
                            Sys.println("ERROR -400: Malformed request or invalid parameters");
                        } else if (rc == -300) {
                            Sys.println("ERROR -300: Timeout");
                        } else {
                            Sys.println("ERROR " + rc + ": Unknown Garmin error code");
                        }
                    }
                }
                
                if (ok) {
                    // Consume exactly the events that were sent
                    try {
                        TinymetrixStorageQueue.drop(MAX_PER_WAKE);
                    } catch(e) {
                        if (_isDebug()) { Sys.println("Error dropping from queue: " + e.getErrorMessage()); }
                    }
                } else if (rc >= 400 && rc < 500) {
                    // Client error: discard events, retrying won't help
                    try {
                        TinymetrixStorageQueue.drop(MAX_PER_WAKE);
                    } catch(e) {
                        if (_isDebug()) { Sys.println("Error dropping from queue: " + e.getErrorMessage()); }
                    }
                    if (_isDebug()) { Sys.println("TM: 4XX - events discarded"); }
                } else {
                    // 5XX or network error: keep events for retry
                    if (_isDebug()) { Sys.println("Request failed, keeping events for retry"); }
                }
                
            } catch(e) {
                if (_isDebug()) { Sys.println("Error in onHttpResponse: " + e.getErrorMessage()); }
            } finally {
                // Always mark execution as completed, regardless of success or failure
                // This maintains the 24h schedule and prevents getting stuck
                TinymetrixScheduler.onExecutionCompleted();
                Bg.exit(true);
            }
        }
    
        // Remove expired events at the front and return up to `max` elements without consuming
        function _loadChunk(max as Lang.Number) as Lang.Array<Lang.Dictionary> {
            // 1) Trim expired events at the head
            while (true) {
                var headArr = TinymetrixStorageQueue.peek(1);
                if (headArr == null || headArr.size() == 0) {
                    break;
                }
                var ev = headArr[0] as Lang.Dictionary;
                if (_isExpired(ev)) {
                    TinymetrixStorageQueue.drop(1); // discard and continue
                } else {
                    break;
                }
            }
            // 2) Take up to `max` from the head
            var out = TinymetrixStorageQueue.peek(max) as Lang.Array<Lang.Dictionary>;
            return (out == null) ? ([] as Lang.Array<Lang.Dictionary>) : out;
        }
    
        function _isExpired(ev as Lang.Dictionary) as Lang.Boolean {
            try {
                var now = Time.now().value();
                var ts = ev.get("ts");
                if (ts == null) {
                    ts = ev.get("timestamp"); // compatibility fallback
                }
                if (ts == null || !(ts instanceof Lang.Number)) {
                    return false; // if there is no timestamp, it does not expire
                }
                var timestamp = ts as Lang.Number;
                return (now - timestamp) > EVENT_TTL_SECS;
            } catch(e) { 
                return false; 
            }
        }
    
        function onBackgroundData(data as Lang.Object) {
            if (_proxyDelegate != null && _proxyDelegate has :onBackgroundData) {
                _proxyDelegate.onBackgroundData(data);
            }
            onTemporalEvent();
        }

        function onGoal(goalType) {
            if (_proxyDelegate != null && _proxyDelegate has :onGoal) {
                _proxyDelegate.onGoal(goalType);
            }
        }



        function onPhoneAppMessage(data) {
            if (_proxyDelegate != null && _proxyDelegate has :onPhoneAppMessage) {
                _proxyDelegate.onPhoneAppMessage(data);
            }
        }

        (:inline)
        private function _isDebug() as Lang.Boolean {
                return TinymetrixConfig.isDebug();
        }
    }
}
