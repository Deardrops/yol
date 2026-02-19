package com.example.yol_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Expose Android system proxy settings to Dart via a method channel.
        // Dart's HttpClient does not read Android Java system properties
        // automatically; this bridge provides the values so ProxyHttpOverrides
        // can configure findProxy accordingly.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.yol_app/system"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getSystemProxy") {
                val host = System.getProperty("http.proxyHost")
                    ?: System.getProperty("https.proxyHost")
                val port = System.getProperty("http.proxyPort")
                    ?: System.getProperty("https.proxyPort")
                if (!host.isNullOrEmpty() && !port.isNullOrEmpty()) {
                    result.success("$host:$port")
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
