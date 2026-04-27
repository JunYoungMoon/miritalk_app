package com.miritalk.miritalk_app;

import android.os.Bundle;
import android.view.WindowManager;
import androidx.annotation.Nullable;
import androidx.core.view.WindowCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.miritalk/window_secure";

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Android 15 SDK 35 강제 edge-to-edge 모드 대비.
        // FlutterActivity 가 ComponentActivity 를 상속하지 않아 EdgeToEdge.enable()
        // 을 못 쓰므로, 그 내부 동작과 동일한 WindowCompat 호출로 대체.
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
    }

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