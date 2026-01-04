plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "com.example.HelpBot"
    compileSdk {
        version = release(36)
    }

    defaultConfig {
        minSdk = 21  // 降低到 Android 5.0，提升兼容性

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
        // 设置HelpBot版本号
        version = "0.1.13"
    }

    buildTypes {
        release {
            isMinifyEnabled = true  //  启用代码混淆
            isShrinkResources = false  // SDK 不启用资源压缩（由宿主控制）
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }
    // AGP 8+ library 默认可能关闭 BuildConfig 生成；SDK 需要用 BuildConfig.DEBUG 做发布静默/调试开关
    buildFeatures {
        buildConfig = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    // 修改编译aar文件携带版本号
    libraryVariants.configureEach {
        outputs.configureEach {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            if (output.outputFileName.endsWith(".aar")) {
                output.outputFileName = "${project.name}-${buildType.name}-${version}.aar"
            }
        }
    }
}

dependencies {
    implementation(libs.appcompat)
    implementation(libs.material)
    implementation(libs.activity)
    implementation(libs.constraintlayout)
    testImplementation(libs.junit)
    androidTestImplementation(libs.ext.junit)
    androidTestImplementation(libs.espresso.core)
}