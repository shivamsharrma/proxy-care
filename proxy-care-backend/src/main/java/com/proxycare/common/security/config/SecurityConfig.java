package com.proxycare.common.security.config;

import com.proxycare.common.security.handler.RestAccessDeniedHandler;
import com.proxycare.common.security.handler.RestAuthenticationEntryPoint;
import com.proxycare.common.security.jwt.SupabaseJwtAuthenticationConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.annotation.web.configurers.AuthorizeHttpRequestsConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.web.SecurityFilterChain;


/**
 * Stateless bearer-token security: which paths are public, which need a Supabase token, and how failures
 * are answered. How a token is verified lives in the jwt package.
 */
@Configuration(proxyBeanMethods = false)
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private static final String[] HEALTH_PATHS = {"/actuator/health", "/actuator/health/**", "/actuator/info"};
    // Turned off in prod by springdoc settings, so these paths only answer in local and test.
    private static final String[] API_DOCS_PATHS = {"/v3/api-docs", "/v3/api-docs/**", "/swagger-ui.html", "/swagger-ui/**"};
    private static final String ERROR_PATH = "/error";
    private static final String API_PATHS = "/api/**";
    // Vendors call these without a token; each controller verifies the vendor's signature on the raw body instead.
    private static final String[] WEBHOOK_PATHS = {"/api/v1/webhooks/razorpayx"};

    @Bean
    SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            JwtDecoder jwtDecoder,
            SupabaseJwtAuthenticationConverter supabaseJwtAuthenticationConverter,
            RestAuthenticationEntryPoint restAuthenticationEntryPoint,
            RestAccessDeniedHandler restAccessDeniedHandler
    ) throws Exception {

        disableBrowserSessionFeatures(http);

        return http
                .authorizeHttpRequests(SecurityConfig::authorizePaths)
                .oauth2ResourceServer(oauth -> oauth
                        .jwt(jwt -> jwt
                                .decoder(jwtDecoder)
                                .jwtAuthenticationConverter(supabaseJwtAuthenticationConverter))
                        .authenticationEntryPoint(restAuthenticationEntryPoint)
                        .accessDeniedHandler(restAccessDeniedHandler))
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(restAuthenticationEntryPoint)
                        .accessDeniedHandler(restAccessDeniedHandler))
                .build();
    }

    /**
     * Public: health/info, API docs, the error page and the signed vendor webhooks. {@code /api/**} needs a token. <b>Everything else is
     * denied</b>, so a new controller can never become public by accident.
     */
    private static void authorizePaths(
            AuthorizeHttpRequestsConfigurer<HttpSecurity>.AuthorizationManagerRequestMatcherRegistry paths
    ) {
        paths
                .requestMatchers(HEALTH_PATHS).permitAll()
                .requestMatchers(API_DOCS_PATHS).permitAll()
                .requestMatchers(ERROR_PATH).permitAll()
                .requestMatchers(HttpMethod.POST, WEBHOOK_PATHS).permitAll()
                .requestMatchers(API_PATHS).authenticated()
                .anyRequest().denyAll();
    }

    /** Every call carries its own bearer token, so cookies, sessions and their CSRF risk don't exist. */
    private static void disableBrowserSessionFeatures(HttpSecurity http) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .cors(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS));
    }

}
