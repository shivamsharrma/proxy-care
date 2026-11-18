plugins {
    java
    jacoco
    alias(libs.plugins.spring.boot)
    alias(libs.plugins.spotless)
}

group = "in.proxycare"
version = "0.1.0-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
        vendor = JvmVendorSpec.ADOPTIUM
    }
}

// Every resolved version is recorded in gradle.lockfile; refresh with
// `./gradlew resolveAndLockAll --write-locks` after changing a dependency.
dependencyLocking {
    lockAllConfigurations()
    // A missing or stale lockfile fails resolution instead of silently floating.
    lockMode = LockMode.STRICT
}

tasks.register("resolveAndLockAll") {
    description = "Resolves every resolvable configuration so --write-locks records all of them."
    notCompatibleWithConfigurationCache("Resolves configurations at execution time")
    doFirst {
        require(gradle.startParameter.isWriteDependencyLocks) { "Run with --write-locks" }
    }
    doLast {
        configurations.filter { it.isCanBeResolved }.forEach { it.resolve() }
    }
}

// Mockito's inline mock maker is attached as a Java agent instead of self-attaching at
// run time, which JDK 21 warns about and a future JDK will refuse.
val mockitoAgent: Configuration = configurations.create("mockitoAgent")

dependencies {
    val boms = listOf(platform(libs.spring.boot.bom), platform(libs.spring.modulith.bom))
    boms.forEach {
        implementation(it)
        annotationProcessor(it)
        testImplementation(it)
        mockitoAgent(it)
    }

    // Web, security, validation
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation(libs.springdoc.webmvc.ui)

    // Persistence
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-flyway")
    implementation("org.hibernate.orm:hibernate-spatial")
    runtimeOnly("org.flywaydb:flyway-database-postgresql")
    runtimeOnly("org.postgresql:postgresql")

    // Observability
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-opentelemetry")
    runtimeOnly("io.micrometer:micrometer-registry-prometheus")

    // Modularity
    implementation("org.springframework.modulith:spring-modulith-api")

    // Resilience, rate limiting, scheduling locks (configured in later milestones)
    implementation(libs.resilience4j.spring.boot)
    implementation("org.springframework.boot:spring-boot-starter-aspectj")
    implementation(libs.bucket4j.core)
    implementation(libs.shedlock.spring)
    implementation(libs.shedlock.jdbc)

    // Mapping
    implementation(libs.mapstruct)
    annotationProcessor(libs.mapstruct.processor)
    annotationProcessor("org.springframework.boot:spring-boot-configuration-processor")

    // Outbound HTTP (vendor clients are built on this, ADR 0009)
    implementation("org.springframework.boot:spring-boot-starter-restclient")

    // Tests (docs/TESTING.md). Versions come from the Boot and Modulith BOMs except
    // ArchUnit and WireMock (version catalog).
    testImplementation("org.springframework.boot:spring-boot-starter-test") // JUnit, AssertJ, Mockito
    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test") // MockMvc
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.springframework.modulith:spring-modulith-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
    // JWT test fixtures and jwt() request post-processors. Plain libraries, not the Boot
    // starter, so no resource-server auto-configuration appears only in tests.
    testImplementation("org.springframework.security:spring-security-oauth2-jose")
    testImplementation("org.springframework.security:spring-security-oauth2-resource-server")
    testImplementation("org.testcontainers:testcontainers-junit-jupiter")
    testImplementation("org.testcontainers:testcontainers-postgresql")
    testImplementation("org.awaitility:awaitility")
    testImplementation(libs.archunit.junit5)
    testImplementation(libs.wiremock.standalone)
    testImplementation("org.junit.platform:junit-platform-launcher") // VendorCallGuard

    mockitoAgent("org.mockito:mockito-core") { isTransitive = false }
}

tasks.withType<JavaCompile>().configureEach {
    options.encoding = "UTF-8"
    options.compilerArgs.addAll(
        listOf(
            // "processing" warns about annotations no processor claims, which is normal
            // when MapStruct and the configuration processor run beside JPA and Spring.
            "-Xlint:all,-processing",
            "-Werror",
            "-parameters",
            "-Amapstruct.defaultComponentModel=spring",
            "-Amapstruct.unmappedTargetPolicy=ERROR",
        ),
    )
}

tasks.test {
    useJUnitPlatform()
    // Integration tests share one database container per JVM and clean it before each test,
    // so test classes run one at a time in a single JVM (docs/TESTING.md).
    maxParallelForks = 1
    jvmArgs(
        "-Duser.timezone=UTC",
        "-Duser.language=en",
        "-Duser.country=US",
        "-XX:+EnableDynamicAgentLoading", // JaCoCo and Byte Buddy (Spring test) attach agents
    )
    jvmArgumentProviders.add(MockitoAgentArgument(mockitoAgent))
    // No real vendor can be reached from tests: see support/VendorCallGuard (a JUnit launcher
    // listener, so the guard also applies in IDE runs).
    testLogging {
        events("failed", "skipped")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
    finalizedBy(tasks.jacocoTestReport)
}

/** Supplies the Mockito agent path lazily so the configuration cache stays valid. */
class MockitoAgentArgument(
    @get:InputFiles @get:PathSensitive(PathSensitivity.NONE) val agent: FileCollection,
) : CommandLineArgumentProvider {
    override fun asArguments() = listOf("-javaagent:${agent.singleFile.absolutePath}")
}

jacoco {
    toolVersion = libs.versions.jacoco.get()
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required = true
        html.required = true
    }
}

// Coverage baseline (docs/TESTING.md). No global threshold while most modules are empty;
// shared infrastructure must keep the 85% line coverage target from the start.
tasks.jacocoTestCoverageVerification {
    dependsOn(tasks.test)
    violationRules {
        rule {
            element = "PACKAGE"
            includes = listOf("in.proxycare.shared.*")
            limit {
                counter = "LINE"
                value = "COVEREDRATIO"
                minimum = "0.85".toBigDecimal()
            }
        }
    }
}

tasks.check {
    dependsOn(tasks.jacocoTestCoverageVerification)
}

tasks.bootRun {
    jvmArgs("-Duser.timezone=UTC")
    systemProperty("spring.profiles.active", System.getenv("SPRING_PROFILES_ACTIVE") ?: "local")
}

// Only the executable Spring Boot jar is published.
tasks.jar {
    enabled = false
}

spotless {
    java {
        target("src/**/*.java")
        googleJavaFormat(libs.versions.google.java.format.get())
        removeUnusedImports()
        formatAnnotations()
        trimTrailingWhitespace()
        endWithNewline()
    }
    format("misc") {
        target("*.md", "docs/**/*.md", ".gitignore", ".gitattributes", "src/**/*.yml", "src/**/*.sql", "docker/**/*")
        trimTrailingWhitespace()
        endWithNewline()
    }
}
