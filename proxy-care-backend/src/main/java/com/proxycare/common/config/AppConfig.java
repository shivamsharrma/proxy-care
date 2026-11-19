package com.proxycare.common.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.media.ArraySchema;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.IntegerSchema;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.media.ObjectSchema;
import io.swagger.v3.oas.models.media.Schema;
import io.swagger.v3.oas.models.media.StringSchema;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import java.net.http.HttpClient;
import java.time.Clock;
import java.time.Duration;
import java.util.Optional;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Scope;
import org.springframework.data.auditing.DateTimeProvider;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

@Configuration(proxyBeanMethods = false)
@EnableJpaAuditing(dateTimeProviderRef = "auditingDateTimeProvider")
public class AppConfig {

    /** Inject this instead of calling Instant.now(); tests replace it with a MutableClock. */
    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    DateTimeProvider auditingDateTimeProvider(Clock clock) {
        return () -> Optional.of(clock.instant());
    }

    /** API docs: bearer auth, and RFC 9457 problem JSON as every operation's error response. */
    @Bean
    OpenAPI openApi() {
        var problem = new ObjectSchema()
                .addProperty("type", new StringSchema())
                .addProperty("title", new StringSchema())
                .addProperty("status", new IntegerSchema())
                .addProperty("detail", new StringSchema())
                .addProperty("instance", new StringSchema())
                .addProperty("code", new StringSchema().description("Stable error code the apps switch on"))
                .addProperty("requestId", new StringSchema())
                .addProperty("errors", new ArraySchema().items(new ObjectSchema()
                        .addProperty("field", new StringSchema())
                        .addProperty("message", new StringSchema())));
        return new OpenAPI()
                .info(new Info().title("Proxy Care API").version("v1"))
                .components(new Components()
                        .addSecuritySchemes("bearer", new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT"))
                        .addSchemas("Problem", problem))
                .addSecurityItem(new SecurityRequirement().addList("bearer"));
    }

    @Bean
    OpenApiCustomizer problemJsonErrors() {
        var error = new ApiResponse()
                .description("Error (application/problem+json)")
                .content(new Content().addMediaType(
                        "application/problem+json",
                        new MediaType().schema(new Schema<>().$ref("#/components/schemas/Problem"))));
        return api -> api.getPaths()
                .values()
                .forEach(path -> path.readOperations()
                        .forEach(op -> op.getResponses().addApiResponse("default", error)));
    }

    /** For vendor clients: 3s connect, 10s read. Prototype, because builders are mutable. */
    @Bean
    @Scope("prototype")
    RestClient.Builder restClientBuilder() {
        var http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build();
        var factory = new JdkClientHttpRequestFactory(http);
        factory.setReadTimeout(Duration.ofSeconds(10));
        return RestClient.builder().requestFactory(factory);
    }
}
