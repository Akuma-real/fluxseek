# Flutter registers plugins and generated entry points through Android embedding
# metadata. Keep the generated registrant and plugin implementations stable
# while allowing app and dependency code to be optimized by R8.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.embedding.** { *; }

# MethodChannel targets are invoked from Dart by string method names.
-keep class com.akuma.fluxseek.MainActivity { *; }
-keep class com.akuma.fluxseek.AndroidCdpBridge { *; }
-keep class com.akuma.fluxseek.FluxseekApplication { *; }

# Firebase components are discovered by generated metadata and reflection.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# androidx.webkit is used directly and by WebView feature checks.
-keep class androidx.webkit.** { *; }
-dontwarn androidx.webkit.**

# Flutter embedding references Play Core splitinstall classes only when Android
# deferred components are used. FluxSeek does not ship deferred components, so
# suppress the optional dependency warnings while keeping R8 enabled.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
