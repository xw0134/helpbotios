// Top-level build file where you can add configuration options common to all sub-projects/modules.
import org.gradle.api.tasks.testing.Test

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
}

/**
 * 测试任务稳定性修复（Windows 环境）：
 *
 * 某些机器的 PATH / java.library.path 会被错误地注入双引号（例如包含 `"C:\Program Files\Java\jdk-xx\bin;..."`），
 * Gradle 在 Windows 上组装子进程命令行时会把引号当作参数边界，导致 Test Executor 启动参数错位，
 * 出现 “找不到或无法加载主类 Files\Java\...” 等异常。
 *
 * 这里统一对所有 Test 任务做“去引号”处理，确保单测进程可启动。
 */
/**
 * 注意：AGP 可能会在 project evaluation 结束后再对 AndroidUnitTest/Test 任务追加/覆盖参数。
 * 因此这里放到 projectsEvaluated 阶段统一强制覆盖，保证最终生效。
 */
gradle.projectsEvaluated {
    allprojects {
        tasks.withType<Test>().configureEach {
            // Windows 环境下，AGP/Gradle 会为 Test Executor 拼接一个很长的 -Djava.library.path，
            // 若其中夹杂带引号的路径片段，会导致命令行参数错位，进而出现“找不到主类 Files\\Java\\...”。
            //
            // 处理策略：
            // - 在命令行末尾追加一个空的 -Djava.library.path=，确保覆盖前面的值（以最后一个为准）。
            // - 同时去掉 Path 环境变量里的引号，减少未来再次被拼接进 java.library.path 的风险。
            jvmArgs("-Djava.library.path=")

            val rawPath = System.getenv("Path") ?: System.getenv("PATH") ?: ""
            val sanitizedPath = rawPath.replace("\"", "")
            if (sanitizedPath.isNotEmpty()) {
                environment("Path", sanitizedPath)
                environment("PATH", sanitizedPath)
            }
        }
    }
}

/**
 * 调试用：打印 :HelpBot:testDebugUnitTest 的关键信息，便于定位 Windows 下测试进程启动参数错位问题。
 * （不影响正常构建；仅在手动执行该任务时输出）
 */
tasks.register("printHelpBotUnitTestConfig") {
    doLast {
        val p = project(":HelpBot")
        val t = p.tasks.findByName("testDebugUnitTest")
        println("== :HelpBot:testDebugUnitTest ==")
        if (t == null) {
            println("task not found")
            return@doLast
        }
        println("taskClass=" + t.javaClass.name)
        if (t is Test) {
            println("is Test: true")
            println("jvmArgs=" + t.jvmArgs)
            println("systemProperties[java.library.path]=" + (t.systemProperties["java.library.path"] ?: "<null>"))
            println("environment[Path]=" + (t.environment["Path"] ?: "<null>"))
        } else {
            println("is Test: false")
        }
    }
}