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
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

// These media plugins support AGP 9 but declare an older buildscript toolchain.
// Reuse this project's versions instead of resolving a second AGP/Kotlin graph.
gradle.beforeProject {
    if (name == "livekit_client" || name == "flutter_webrtc") {
        buildscript.configurations.configureEach {
            resolutionStrategy.eachDependency {
                if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                    useVersion("9.0.1")
                }
                if (requested.group == "org.jetbrains.kotlin" && requested.name == "kotlin-gradle-plugin") {
                    useVersion("2.3.20")
                }
            }
        }
    }
}

include(":app")
