allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // 🛡️ THE MASTER SHIELD: Prevents 'lStar' error across all plugins
    configurations.all {
        resolutionStrategy.eachDependency {
            val group = requested.group
            val name = requested.name
            
            // Force stable AndroidX Core (Without lStar)
            if (group == "androidx.core" && (name == "core" || name == "core-ktx")) {
                useVersion("1.13.1")
            }
            // Force stable AndroidX Activity
            if (group == "androidx.activity" && (name == "activity" || name == "activity-ktx")) {
                useVersion("1.9.3")
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
