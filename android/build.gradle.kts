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
    project.evaluationDependsOn(":app")
}

// AGP 8+ requires every library module to declare a namespace.
// async_wallpaper 2.1.0 omits it, so we patch it here.
// pluginManager.withPlugin fires when the Android library plugin is applied,
// before any namespace validation occurs, so the namespace can still be set.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.getByType<com.android.build.gradle.LibraryExtension>()
        if (androidExt.namespace == null) {
            val manifest = file("src/main/AndroidManifest.xml")
            if (manifest.exists()) {
                val pkg = javax.xml.parsers.DocumentBuilderFactory
                    .newInstance()
                    .newDocumentBuilder()
                    .parse(manifest)
                    .documentElement
                    .getAttribute("package")
                if (pkg.isNotBlank()) androidExt.namespace = pkg
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
