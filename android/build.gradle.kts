// FILE: android/build.gradle.kts

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 🔥 Clean and safe build directory setup
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build")
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    layout.buildDirectory.set(newBuildDir.map { it.dir(name) })
}

// ⚠️ Ensure app evaluated first (important for Flutter plugins)
subprojects {
    evaluationDependsOn(":app")
}

// 🧹 Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
