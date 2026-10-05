allprojects {
    repositories {
        google()
        mavenCentral()
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

// The async_wallpaper 2.1.0 workarounds that used to live here are gone with
// async_wallpaper 3.x: it declares its own namespace, pins Java and Kotlin to
// the same JVM target, and ships a single Kotlin plugin class. They also relied
// on AGP 8 extension types (com.android.build.gradle.BaseExtension and
// LibraryExtension) that AGP 9 removed.
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}