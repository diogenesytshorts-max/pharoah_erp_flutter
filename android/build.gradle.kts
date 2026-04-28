allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // DEEP FIX: Force all plugins to use stable AndroidX versions
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.activity") {
                useVersion("1.9.3")
            }
            if (requested.group == "androidx.lifecycle") {
                useVersion("2.8.7")
            }
            if (requested.group == "androidx.core" && requested.name == "core-ktx") {
                useVersion("1.13.1")
            }
        }
    }
}

// THE FIX FOR CIRCULAR EVALUATION ERROR 👇
val newBuildDir = rootProject.layout.projectDirectory.dir("../../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
