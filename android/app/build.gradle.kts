import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun keystoreValue(name: String): String =
    keystoreProperties.getProperty(name)?.trim().orEmpty()

val releaseStorePassword = keystoreValue("storePassword")
val releaseKeyPassword = keystoreValue("keyPassword")
val releaseKeyAlias = keystoreValue("keyAlias")
val releaseStoreFilePath = keystoreValue("storeFile")

// Empty template and a missing file both stay on the debug key.
// A filled key.properties uses the upload key; a bad storeFile fails the build.
val hasReleaseKeystore =
    keystorePropertiesFile.exists() &&
        releaseStorePassword.isNotEmpty() &&
        releaseKeyPassword.isNotEmpty() &&
        releaseKeyAlias.isNotEmpty() &&
        releaseStoreFilePath.isNotEmpty()

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

android {
    namespace = "com.lululu.game.lululu_game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lululu.game.lululu_game"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = file(releaseStoreFilePath)
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
