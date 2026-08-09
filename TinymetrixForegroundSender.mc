using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Communications as Comm;

module Tinymetrix {
    (:background, :hidden)
    class TinymetrixForegroundSender {
        private static const ENDPOINT_URL = Tinymetrix.INGEST_URL;
        private static const MAX_PER_SEND = 10;

        public static function send() as Void {
            var chunk = TinymetrixStorageQueue.peek(MAX_PER_SEND);
            var count = (chunk == null) ? 0 : chunk.size();

            if (count == 0) {
                if (TinymetrixConfig.isDebug()) {
                    Sys.println("TM: Foreground send - queue empty, nothing to send");
                }
                return;
            }

            try {
                var payload = TinymetrixJsonSerializer.buildJsonArray(chunk);
                var params = { "batch" => payload } as Lang.Dictionary;
                var opts = {
                    :method       => Comm.HTTP_REQUEST_METHOD_POST,
                    :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                } as Lang.Dictionary;

                if (TinymetrixConfig.isDebug()) {
                    Sys.println("TM: Foreground send " + count + " events");
                }

                var sender = new TinymetrixForegroundSender();
                Comm.makeWebRequest(ENDPOINT_URL, params, opts, new Lang.Method(sender, :onHttpResponse));
            } catch(e) {
                if (TinymetrixConfig.isDebug()) {
                    Sys.println("TM: Foreground send error: " + e.getErrorMessage());
                }
            }
        }

        function onHttpResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
            var rc = (responseCode == null) ? -1 : responseCode as Lang.Number;
            var ok = (rc >= 200 && rc < 300);

            if (TinymetrixConfig.isDebug()) {
                Sys.println("TM: Foreground send rc=" + rc + (ok ? " OK" : " FAIL"));
            }

            if (ok) {
                TinymetrixStorageQueue.drop(MAX_PER_SEND);
                TinymetrixHeartbeat.updateActivity();
            } else if (rc >= 400 && rc < 500) {
                // Client error: discard events, retrying won't help
                TinymetrixStorageQueue.drop(MAX_PER_SEND);
                if (TinymetrixConfig.isDebug()) { Sys.println("TM: Foreground 4XX - events discarded"); }
            }
        }
    }
}
