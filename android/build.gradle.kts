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

// AGP 8+ requires every library module to declare a namespace.
// async_wallpaper 2.1.0 omits it, so we patch it here.
subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()
            ?.let { android ->
                if (android.namespace == null) {
                    // Read the package attribute from the module's AndroidManifest.xml
                    // so this block works for any plugin that is missing a namespace.
                    val manifest = file("src/main/AndroidManifest.xml")
                    if (manifest.exists()) {
                        val pkg = javax.xml.parsers.DocumentBuilderFactory
                            .newInstance()
                            .newDocumentBuilder()
                            .parse(manifest)
                            .documentElement
                            .getAttribute("package")
                        if (pkg.isNotBlank()) android.namespace = pkg
                    }
                }
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
