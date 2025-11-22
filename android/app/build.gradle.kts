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
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }

        getByName("debug") {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // Optional fix cho nhiều lib Flutter + multidex
    packaging {
        resources.excludes += "META-INF/*"
    }
}

flutter {
    source = "../.."
}
