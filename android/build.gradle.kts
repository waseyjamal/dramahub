// android/build.gradle  (ROOT level — not android/app/build.gradle)
// ✅ Added Yandex required repository URLs

allprojects {
    repositories {
        google()
        mavenCentral()
        mavenLocal()
        maven { url = uri("https://cboost.jfrog.io/artifactory/chartboost-ads/") }

        // ── Yandex required repos ──────────────────────────────────────
        maven { url = uri("https://android-sdk.is.com/") }
        maven { url = uri("https://artifact.bytedance.com/repository/pangle") }
        maven { url = uri("https://sdk.tapjoy.com/") }
        maven { url = uri("https://dl-maven-android.mintegral.com/repository/mbridge_android_sdk_oversea") }
        maven { url = uri("https://dl.appnext.com/") }
        maven { url = uri("https://developer.huawei.com/repo/") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}