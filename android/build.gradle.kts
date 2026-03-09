buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Align all Android subprojects to Java 17 and Kotlin JVM 17 so Java and Kotlin match (webview_flutter_android, flutter_network_connectivity, etc.)
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        try {
            val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
            val javaVersion = JavaVersion.VERSION_17
            compileOptions?.javaClass?.getMethod("setSourceCompatibility", Object::class.java)?.invoke(compileOptions, javaVersion)
            compileOptions?.javaClass?.getMethod("setTargetCompatibility", Object::class.java)?.invoke(compileOptions, javaVersion)
            val kotlinOptions = android.javaClass.getMethod("getKotlinOptions").invoke(android)
            kotlinOptions?.javaClass?.getMethod("setJvmTarget", String::class.java)?.invoke(kotlinOptions, "17")
        } catch (_: Exception) {
            // Not an Android project or API changed
        }
    }
    // Force Kotlin JVM target 17 for all subprojects (fixes flutter_network_connectivity etc.)
    try {
        val kotlinCompileClass = Class.forName("org.jetbrains.kotlin.gradle.tasks.KotlinCompile") as Class<out Task>
        tasks.withType(kotlinCompileClass).configureEach {
            this.javaClass.getMethod("getKotlinOptions").invoke(this)?.let { opts: Any ->
                opts.javaClass.getMethod("setJvmTarget", String::class.java).invoke(opts, "17")
            }
        }
    } catch (_: Exception) { }
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
