allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://artifact.bytedance.com/repository/AwemeOpenSDK") }
        maven { url = uri("https://artifact.bytedance.com/repository/pangle") }
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
    if (project.name == "cronet_http") {
        // Bundle Cronet so networking also works on phones without Google Play.
        val existing = project.findProperty("dart-defines")?.toString().orEmpty()
        val embedded = java.util.Base64.getEncoder()
            .encodeToString("cronetHttpNoPlay=true".toByteArray())
        project.extensions.extraProperties["dart-defines"] =
            listOf(existing, embedded).filter { it.isNotEmpty() }.joinToString(",")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
