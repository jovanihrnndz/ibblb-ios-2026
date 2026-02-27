plugins {
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.android.application)
    id("skip-build-plugin")
}

configurations.configureEach {
    resolutionStrategy.dependencySubstitution {
        substitute(module("com.jovanihrnndz.ibblb:IBBLBAndroidApp")).using(project(":IBBLBAndroidApp"))
    }
}

skip {
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(libs.versions.jvm.get().toString())
    }
}

android {
    namespace = group as String
    compileSdk = libs.versions.android.sdk.compile.get().toInt()

    compileOptions {
        sourceCompatibility = JavaVersion.toVersion(libs.versions.jvm.get())
        targetCompatibility = JavaVersion.toVersion(libs.versions.jvm.get())
    }

    packaging {
        jniLibs {
            keepDebugSymbols.add("**/*.so")
            pickFirsts.add("**/*.so")
            useLegacyPackaging = true
        }
    }

    defaultConfig {
        minSdk = libs.versions.android.sdk.min.get().toInt()
        targetSdk = libs.versions.android.sdk.compile.get().toInt()
    }

    buildFeatures {
        buildConfig = true
    }

    lint {
        disable.add("Instantiatable")
        disable.add("MissingPermission")
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}
