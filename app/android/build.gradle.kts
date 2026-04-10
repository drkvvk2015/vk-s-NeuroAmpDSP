allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep Android outputs under app/build/<module> so Flutter tooling can locate APK artifacts.
val sharedBuildDir = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(sharedBuildDir)

subprojects {
    project.layout.buildDirectory.value(sharedBuildDir.dir(project.name))
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
