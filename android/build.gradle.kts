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

// Flutter plugin modules pin their own Java/Kotlin JVM targets and they do not
// always agree. async_wallpaper 2.1.0 compiles Java with 1.8 while leaving the
// Kotlin jvmTarget unset, so it falls back to the Kotlin Gradle plugin default
// (the JDK running Gradle, currently 17). The Kotlin Gradle plugin turns that
// mismatch into a build failure:
//   Inconsistent JVM-target compatibility detected for tasks
//   'compileReleaseJavaWithJavac' (1.8) and 'compileReleaseKotlin' (17).
// Plugins live in the pub cache, which is replaced on the next `flutter pub get`,
// so pin Java and Kotlin to the same JVM target for every module instead.
//
// This block has to be registered before the `evaluationDependsOn(":app")` block
// below, because evaluating :app makes `afterEvaluate` unavailable for it.
val javaTarget = JavaVersion.VERSION_17
val kotlinTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17

subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileOptions.sourceCompatibility = javaTarget
            compileOptions.targetCompatibility = javaTarget
        }
        // The Kotlin Gradle plugin validates the JVM target of the javac and
        // Kotlin compile tasks, so configure the tasks themselves as well as the
        // DSL extensions that the tasks are created from.
        tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
            sourceCompatibility = javaTarget.toString()
            targetCompatibility = javaTarget.toString()
        }
        extensions.findByType<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension>()?.apply {
            compilerOptions.jvmTarget.set(kotlinTarget)
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(kotlinTarget)
        }
    }
}

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

// async_wallpaper 2.1.0 still ships the `flutter create` Kotlin stub in
// src/main/kotlin even though the plugin itself is implemented in Java. When the
// Kotlin plugin is applied to that module, both sources declare
// com.codenameakshay.async_wallpaper.AsyncWallpaperPlugin and Kotlin aborts with
// "Redeclaration". The Java class is the implementation the plugin registers
// (the stub only answers getPlatformVersion), so drop the unused stub.
// The filter is applied to the compile tasks instead of the Kotlin source set,
// because Flutter >= 3.47 applies the Kotlin plugin before the Android variants
// exist, so the Kotlin source sets cannot be configured at that point yet.
subprojects {
    if (name == "async_wallpaper") {
        pluginManager.withPlugin("org.jetbrains.kotlin.android") {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                exclude("**/AsyncWallpaperPlugin.kt")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
