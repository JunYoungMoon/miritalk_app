package com.miritalk.miritalk_app;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.view.WindowManager;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.miritalk/window_secure";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("enableSecure")) {
                        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
                        result.success(null);
                    } else if (call.method.equals("disableSecure")) {
                        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });
    }
}