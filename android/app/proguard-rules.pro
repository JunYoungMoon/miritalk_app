# ===== Flutter =====
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ===== Google Sign-In =====
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# ===== Kakao SDK =====
-keep class com.kakao.** { *; }
-keep class com.kakao.sdk.** { *; }
-keepclassmembers class * {
    @com.kakao.sdk.common.annotation.* <methods>;
}
-dontwarn com.kakao.**

# ===== 기본 Android =====
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ===== 보안: 역난독화 방지 =====
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# ===== Retrofit / OkHttp (Spring 서버 통신용) =====
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }
-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}

# Google Play Core (Flutter 디퍼드 컴포넌트)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**