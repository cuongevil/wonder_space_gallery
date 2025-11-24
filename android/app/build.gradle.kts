import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")   // Firebase
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ctmd.wonderforge.wonderspace.gallery"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.ctmd.wonderforge.wonderspace.gallery"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 15
        versionName = "1.0.0"
    }

    // -----------------------------
    // SIGNING CONFIGS
    // -----------------------------
    signingConfigs {

        // ⭐ Debug: dùng mặc định của Android Studio
        getByName("debug") {
            storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }

        // ⭐ Release: đọc từ key.properties
        create("release") {
            val props = Properties()
            val propFile = rootProject.file("key.properties")

            if (propFile.exists()) {
                props.load(FileInputStream(propFile))

                keyAlias = props["keyAlias"] as String?
                keyPassword = props["keyPassword"] as String?
                storePassword = props["storePassword"] as String?
                storeFile = props["storeFile"]?.let { file(it as String) }
            }
        }
    }

    // -----------------------------
    // BUILD TYPES
    // -----------------------------
    buildTypes {

        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = true
            isMinifyEnabled = false
        }

        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }
    }

    // -----------------------------
    // JVM / KOTLIN SETTINGS
    // -----------------------------
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // -----------------------------
    // PACKAGING FIX
    // -----------------------------
    packaging {
        resources.excludes += "META-INF/*"
    }
}

flutter {
    source = "../.."
}
