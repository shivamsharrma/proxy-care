plugins {
    java
    id("org.springframework.boot") version "4.1.2"
    id("io.spring.dependency-management") version "1.1.7"
    id("com.gorylenko.gradle-git-properties") version "4.0.1"
}

group = "com.proxycare"
version = "0.1.0-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

springBoot {
    // Exposed at /actuator/info. No timestamp, so the output stays cacheable.
    buildInfo {
        excludes = setOf("time")
    }
}

// The repo root (monorepo) holds .git; the Docker build context has none, so don't fail there.
gitProperties {
    dotGitDirectory = layout.projectDirectory.dir("../.git")
    failOnNoGitDirectory = false
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-security-oauth2-resource-server")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-flyway")
    implementation("org.flywaydb:flyway-database-postgresql")
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:3.2.0")
    runtimeOnly("org.postgresql:postgresql")
    implementation("org.mapstruct:mapstruct:1.6.3")
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")
    // After Lombok, so MapStruct sees the generated getters and setters.
    annotationProcessor("org.projectlombok:lombok-mapstruct-binding:0.2.0")
    annotationProcessor("org.mapstruct:mapstruct-processor:1.6.3")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
    testImplementation("org.springframework.security:spring-security-test")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.testcontainers:testcontainers-postgresql")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

// Only the executable jar is built, so the Dockerfile can copy build/libs/*.jar.
tasks.jar {
    enabled = false
}

tasks.withType<JavaCompile> {
    options.compilerArgs.add("-parameters")
    // Mappers are Spring beans, and a response field no mapping fills fails the build.
    options.compilerArgs.addAll(listOf(
        "-Amapstruct.defaultComponentModel=spring",
        "-Amapstruct.unmappedTargetPolicy=ERROR"))
}

tasks.test {
    // Sequential: JUnit parallel mode stays off.
    useJUnitPlatform()
    testLogging {
        events("failed")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
}
