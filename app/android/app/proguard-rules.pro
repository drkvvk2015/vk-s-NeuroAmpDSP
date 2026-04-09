# Flutter-related rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }

# Kotlin and Java standard library
-keep class kotlin.** { *; }
-keep class java.** { *; }

# Riverpod state management
-keep class riverpod.** { *; }

# Our app classes
-keep class com.neuroamp.app.** { *; }
-keepclassmembers class com.neuroamp.app.** { *; }

# JNI
-keepclasseswithmembernames class * {
    native <methods>;
}

# Generic signatures
-keepattributes Signature
-keepattributes *Annotation*

# Enum keep
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
