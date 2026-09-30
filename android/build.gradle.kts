// Kotlin comes from the app: AGP 9's built-in Kotlin, or the Kotlin Gradle
// Plugin that Flutter applies when built-in Kotlin is off. The plugin only
// needs KGP on the classpath to configure the compiler.
buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.0")
    }
}

plugins {
    id("com.android.library")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

android {
    namespace = "com.jhonacode.flutter_local_db"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    // Libraries have no targetSdk since AGP 9: the app sets its own.
    defaultConfig {
        minSdk = 21
    }
}
