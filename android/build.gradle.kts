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
    
    // Fix for "Namespace not specified" in older plugins
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            try {
                val namespaceMethod = android.javaClass.getMethod("getNamespace")
                if (namespaceMethod.invoke(android) == null) {
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespaceMethod.invoke(android, "com.example.flutter_jailbreak_detection_fix")
                }
            } catch (e: Exception) {
                // Property might not exist or method names differ in older AGP versions
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
