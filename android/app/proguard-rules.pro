# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Garder toutes les ressources drawable et mipmap (icônes)
-keep class **.R$drawable { *; }
-keep class **.R$mipmap { *; }

# Garder les assets
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Image Picker
-keep class androidx.lifecycle.** { *; }

# Video Player
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Prévenir la suppression des ressources utilisées dynamiquement
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Garder les classes natives
-keepclasseswithmembernames class * {
    native <methods>;
}
