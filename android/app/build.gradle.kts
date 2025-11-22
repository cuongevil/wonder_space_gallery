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

    signingConfigs {
        create("debug") {
            // Dùng debug keystore mặc định
            storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }

        create("release") {
            val props = Properties()
            val file = rootProject.file("key.properties")
            if (file.exists()) props.load(FileInputStream(file))

            keyAlias = props["keyAlias"] as String?
            keyPassword = props["keyPassword"] as String?
            storeFile = props["storeFile"]?.let { file(it as String) }
            storePassword = props["storePassword"] as String?
        }
    }

    buildTypes {
        getByName("debug") {
            // ❗ Fix quan trọng: dùng debug keystore
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = true
            isMinifyEnabled = false
        }

        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    packaging {
        resources.excludes += "META-INF/*"
    }
}

flutter {
    source = "../.."
}
