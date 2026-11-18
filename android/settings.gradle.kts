pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // Kotlin 2.4 rejects kotlinOptions { jvmTarget = "..." }. These three
    // plugins still ship that DSL. Rewrite the pub-cache script before Gradle
    // compiles it. Already-migrated files are left untouched.
    val pluginsManifest = file("../.flutter-plugins-dependencies")
    if (pluginsManifest.exists()) {
        val pluginPath = Regex(
            """"name"\s*:\s*"(audio_streamer|audioplayers_android|sign_in_with_apple)"\s*,\s*"path"\s*:\s*"([^"]+)"""",
        )
        val jvmOptions = Regex("""kotlinOptions\s*\{\s*jvmTarget\s*=\s*'([^']+)'\s*\}""")
        val topLevelDependencies = Regex("""(?m)^dependencies\s*\{""")
        for (found in pluginPath.findAll(pluginsManifest.readText())) {
            val buildFile = file(found.groupValues[2] + "android/build.gradle")
            if (!buildFile.exists()) continue
            val source = buildFile.readText()
            val target = jvmOptions.find(source) ?: continue
            val jvm = when (target.groupValues[1]) {
                "1.8", "8" -> "JVM_1_8"
                "11" -> "JVM_11"
                "17" -> "JVM_17"
                "21" -> "JVM_21"
                else -> "JVM_1_8"
            }
            val stripped = jvmOptions.replace(source, "")
            val block =
                "kotlin {\n" +
                    "    compilerOptions {\n" +
                    "        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.$jvm\n" +
                    "    }\n" +
                    "}\n\n"
            val updated = if (topLevelDependencies.containsMatchIn(stripped)) {
                topLevelDependencies.replaceFirst(stripped, block + "dependencies {")
            } else {
                stripped.trimEnd() + "\n\n" + block
            }
            if (updated != source) {
                buildFile.writeText(updated)
            }
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
