plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.allformarkdown.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.allformarkdown.app"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = rootProject.file(keystoreProperties.getProperty("storeFile") ?: "upload-keystore.jks")
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            ndk {
                debugSymbolLevel = "NONE"
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols += setOf("**/*.so")
        }
        resources {
            excludes += setOf("META-INF/*")
        }
        // Explicitly do not strip any .so files
        jniLibs.pickFirsts += setOf("**/*.so")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

// Force disable ALL strip debug symbols tasks to fix AAB build issues
afterEvaluate {
    tasks.matching { task -> 
        task.name.contains("strip", ignoreCase = true) || 
        task.name.contains("extractNativeSymbol", ignoreCase = true) ||
        task.name.contains("mergeNativeDebugMetadata", ignoreCase = true)
    }.configureEach {
        enabled = false
    }
}

// Also try to catch any remaining strip-related tasks
gradle.taskGraph.whenReady {
    allTasks.filter { task -> 
        task.name.lowercase().contains("strip") 
    }.forEach { task ->
        task.enabled = false
    }
}
