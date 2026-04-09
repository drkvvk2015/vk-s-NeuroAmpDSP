import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

// Support CI/CD signing from environment variables
val ciKeystore = System.getenv("NEUROAMP_KEYSTORE_BASE64")
val ciKeyAlias = System.getenv("NEUROAMP_KEY_ALIAS")
val ciKeyPassword = System.getenv("NEUROAMP_KEY_PASSWORD")
val ciStorePassword = System.getenv("NEUROAMP_KEYSTORE_PASSWORD")

android {
    namespace = "com.neuroamp.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.neuroamp.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    signingConfigs {
        create("release") {
            if (ciKeystore != null) {
                // CI/CD environment: decode keystore from base64
                val keystoreFile = File("${buildDir}/ci.keystore")
                val keystoreBytes = android.util.Base64.decode(ciKeystore, android.util.Base64.DEFAULT)
                keystoreFile.writeBytes(keystoreBytes)
                storeFile = keystoreFile
                storePassword = ciStorePassword
                keyAlias = ciKeyAlias
                keyPassword = ciKeyPassword
            } else if (keyPropertiesFile.exists()) {
                // Local development: read from key.properties
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (ciKeystore != null || keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    bundle {
        // Enable dynamic feature module support for Play Store AAB
        enableSplit = true
    }
}

flutter {
    source = "../.."
}

