package com.proxycare.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.ProxyCareApplication;
import com.proxycare.support.IntegrationTest;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.context.TypeExcludeFilter;
import org.springframework.boot.context.properties.bind.validation.BindValidationException;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.type.classreading.MetadataReader;
import org.springframework.core.type.classreading.MetadataReaderFactory;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * Starts the real application with the prod profile (prod config, no test overrides) against the shared
 * test database, the way it starts in production.
 */
class ProdProfileTest extends IntegrationTest {

    @Autowired
    PostgreSQLContainer postgreSQLContainer;

    private static final String SUPABASE_URL = "--SUPABASE_URL=https://test.supabase.co";

    @Test
    void swaggerAndApiDocsAreDisabled() throws Exception {
        try (ConfigurableApplicationContext app = start(List.of(SUPABASE_URL))) {
            assertThat(get(app, "/v3/api-docs")).isEqualTo(404);
            assertThat(get(app, "/swagger-ui/index.html")).isEqualTo(404);
        }
    }

    @Test
    void startupFailsWithoutSupabaseUrl() {
        assertThatThrownBy(() -> start(List.of()).close())
                .hasRootCauseInstanceOf(BindValidationException.class)
                .rootCause()
                .hasMessageContaining("proxycare.security.jwt")
                .hasMessageContaining("supabaseUrl");
    }

    /** Vendor keys (Razorpay, Google, Uber) are optional until their features are built. */
    @Test
    void startupSucceedsWithoutVendorKeys() {
        try (ConfigurableApplicationContext app = start(List.of(SUPABASE_URL))) {
            assertThat(app.isRunning()).isTrue();
        }
    }

    private ConfigurableApplicationContext start(List<String> extraArgs) {
        List<String> args = new ArrayList<>(List.of(
                "--DB_URL=" + postgreSQLContainer.getJdbcUrl(),
                "--DB_USER=" + postgreSQLContainer.getUsername(),
                "--DB_PASSWORD=" + postgreSQLContainer.getPassword(),
                // The shared DB also holds test migrations; let Flyway resolve them.
                "--spring.flyway.locations=classpath:db/migration,classpath:db/testmigration",
                "--server.port=0"));
        args.addAll(extraArgs);
        return new SpringApplicationBuilder(ProxyCareApplication.class)
                .profiles("prod")
                // Component scanning would otherwise pick up @TestConfiguration classes from the test classpath.
                .initializers(ctx -> ctx.getBeanFactory().registerSingleton("excludeTestConfig", new ExcludeTestConfig()))
                .run(args.toArray(String[]::new));
    }

    private static int get(ConfigurableApplicationContext app, String path) throws Exception {
        int port = ((WebServerApplicationContext) app).getWebServer().getPort();
        try (HttpClient http = HttpClient.newHttpClient()) {
            HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path)).build();
            return http.send(request, HttpResponse.BodyHandlers.discarding()).statusCode();
        }
    }

    static class ExcludeTestConfig extends TypeExcludeFilter {
        @Override
        public boolean match(MetadataReader reader, MetadataReaderFactory factory) {
            return reader.getAnnotationMetadata().isAnnotated(TestConfiguration.class.getName());
        }
    }
}
