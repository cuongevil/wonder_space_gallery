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
    // Signing Configs
    // -----------------------------
    signingConfigs {

        // Debug keystore mặc định
        create("debug") {
            storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }

        // Release keystore dùng wonderkids.keystore
        create("release") {
            val props = Properties()
            val propFile = rootProject.file("key.properties")

            if (propFile.exists()) {
                props.load(FileInputStream(propFile))

                keyAlias = props["keyAlias"] as String?
                keyPassword = props["keyPassword"] as String?
                storePassword = props["storePassword"] as String?

                // File keystore (vì nằm trong thư mục android/)
                storeFile = props["storeFile"]?.let { file(it as String) }
            }
        }
    }

    // -----------------------------
    // Build Types
    // -----------------------------
    buildTypes {

        // Debug
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
        }

        // Release
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
    // Java & Kotlin options
    // -----------------------------
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // -----------------------------
    // Packaging (fix conflict META-INF)
    // -----------------------------
    packaging {
        resources.excludes += "META-INF/*"
    }
}

flutter {
    source = "../.."
}
