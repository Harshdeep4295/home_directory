# JNA and Vosk are called from native code by name (alphacep/vosk-android-demo proguard).
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }
-keep class org.vosk.** { *; }
-dontwarn java.awt.**
