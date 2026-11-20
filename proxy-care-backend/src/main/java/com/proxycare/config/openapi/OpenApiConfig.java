package com.proxycare.config.openapi;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** API docs: every operation needs a bearer token and documents ApiError as its error response. */
@Configuration(proxyBeanMethods = false)
public class OpenApiConfig {

    static final String BEARER = "bearer";

    @Bean
    OpenAPI openApi() {
        return new OpenAPI()
                .info(new Info().title("Proxy Care API").version("v1"))
                .components(new Components().addSecuritySchemes(BEARER, bearerJwt()))
                .addSecurityItem(new SecurityRequirement().addList(BEARER));
    }

    @Bean
    OpenApiCustomizer apiErrorDefaultResponseCustomizer() {
        return new ApiErrorDefaultResponseCustomizer();
    }

    private static SecurityScheme bearerJwt() {
        return new SecurityScheme()
                .type(SecurityScheme.Type.HTTP)
                .scheme("bearer")
                .bearerFormat("JWT");
    }
}
