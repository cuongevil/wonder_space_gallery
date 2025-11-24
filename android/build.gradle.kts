allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Di chuyển build ra ngoài android/build → build/
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    project.layout.buildDirectory.set(newBuildDir.dir(project.name))
}

// ❌ BỎ evaluationDependsOn(":app")
// ❗ Đoạn này ép tất cả module lấy signingConfig từ app, gây lỗi debug
// subprojects {
//     evaluationDependsOn(":app")
// }

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
