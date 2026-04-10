allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep Android outputs under app/build so Flutter tooling can locate APK artifacts.
rootProject.layout.buildDirectory.value(rootProject.layout.projectDirectory.dir("../build"))

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
