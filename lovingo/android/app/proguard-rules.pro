# ===== RÈGLES PROGUARD/R8 STRIPE =====

# Keep all Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# ===== CLASSES MANQUANTES R8 (NOUVELLES) =====
# Keep Google Play Core classes
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep Google API Client classes
-keep class com.google.api.client.** { *; }
-dontwarn com.google.api.client.**

# Keep OkHttp OLD VERSION classes (différent de okhttp3)
-keep class com.squareup.okhttp.** { *; }
-dontwarn com.squareup.okhttp.**

# Keep Joda Time classes
-keep class org.joda.time.** { *; }
-dontwarn org.joda.time.**

# Keep Google Crypto Tink classes
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# Keep gRPC classes
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**

# ===== STRIPE CLASSES - TOUTES =====
-keep class com.stripe.** { *; }
-keep interface com.stripe.** { *; }
-dontwarn com.stripe.**

# Stripe Push Provisioning (classes manquantes)
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.android.pushProvisioning.**

# Stripe React Native SDK (souvent la source du problème)
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.**

# Flutter Stripe Plugin
-keep class com.flutter.stripe.** { *; }
-dontwarn com.flutter.stripe.**

# ===== FIREBASE CLASSES =====
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**


# ===== GÉNÉRIQUES =====
# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep all annotations
-keepattributes Annotation
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep Kotlin coroutines
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# Keep Gson classes (si utilisé par Stripe)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Keep OkHttp classes (utilisé par Stripe)
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep Retrofit classes (potentiellement utilisé)
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

# Suppression des warnings spécifiques
-dontwarn java.lang.instrument.ClassFileTransformer
-dontwarn sun.misc.SignalHandler
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Keep all public classes and methods
-keep public class * {
    public protected *;
}

# ===== RÈGLES SPÉCIALES POUR RELEASE =====
# Désactiver l'optimisation aggressive pour Stripe
-dontoptimize
-dontobfuscate

# Ou si vous voulez garder l'optimisation, au moins garder Stripe intact
# -keep,allowoptimization class com.stripe.** { *; }