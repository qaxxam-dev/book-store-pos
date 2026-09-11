allprojects {
    repositories {
        google()
        mavenCentral()
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

subprojects {
    plugins.withId("com.android.library") {
        val manifestFile = file("src/main/AndroidManifest.xml")
        var pkgName: String? = null
        if (manifestFile.exists()) {
            val content = manifestFile.readText()
            val match = Regex("""package="([^"]+)"""").find(content)
            if (match != null) {
                pkgName = match.groupValues[1]
                val updatedContent = content.replace(Regex("""package="[^"]*""""), "")
                manifestFile.writeText(updatedContent)
            }
        }
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val currentNs = getNamespace.invoke(android)
                if (currentNs == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val nsToSet = pkgName ?: "com.example.${project.name.replace('-', '_').replace('.', '_')}"
                    setNamespace.invoke(android, nsToSet)
                }
            } catch (_: Exception) {}
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
