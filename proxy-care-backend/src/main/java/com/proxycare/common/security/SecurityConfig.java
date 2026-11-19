package com.proxycare.common.security;

import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.jwk.source.JWKSourceBuilder;
import com.nimbusds.jose.proc.SecurityContext;
import com.proxycare.common.config.AppProperties;
import com.proxycare.common.error.ErrorCode;
import com.proxycare.common.error.GlobalExceptionHandler;
import java.net.MalformedURLException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.util.List;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.util.StringUtils;

/**
 * Validates Supabase access tokens and decides which paths need them.
 *
 * <p>Paths: health/info, webhooks (signature checked in code) and API docs (disabled in prod) are
 * public; {@code /api/v1/**} needs a valid token; <b>everything else is denied</b>, so an unknown path
 * outside {@code /api/v1} gets 401/403 instead of 404 and no new controller can become public by accident.
 */
@Configuration(proxyBeanMethods = false)
@EnableMethodSecurity
public class SecurityConfig {

    static final String AUDIENCE = "authenticated";

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http, JwtDecoder decoder, SupabaseJwtConverter converter)
            throws Exception {
        AuthenticationEntryPoint unauthenticated = (request, response, ex) -> {
            response.setHeader("WWW-Authenticate", "Bearer");
            GlobalExceptionHandler.writeProblem(
                    request, response, ErrorCode.UNAUTHENTICATED, "A valid access token is required.");
        };
        AccessDeniedHandler forbidden = (request, response, ex) -> GlobalExceptionHandler.writeProblem(
                request, response, ErrorCode.FORBIDDEN, "You are not allowed to do this.");

        return http.authorizeHttpRequests(auth -> auth.requestMatchers(
                                "/actuator/health", "/actuator/health/**", "/actuator/info")
                        .permitAll()
                        .requestMatchers("/webhooks/**")
                        .permitAll()
                        .requestMatchers("/v3/api-docs", "/v3/api-docs/**", "/swagger-ui.html", "/swagger-ui/**")
                        .permitAll()
                        .requestMatchers("/error")
                        .permitAll()
                        .requestMatchers("/api/v1/**")
                        .authenticated()
                        .anyRequest()
                        .denyAll())
                .oauth2ResourceServer(oauth -> oauth.jwt(jwt -> jwt.decoder(decoder).jwtAuthenticationConverter(converter))
                        .authenticationEntryPoint(unauthenticated)
                        .accessDeniedHandler(forbidden))
                .exceptionHandling(ex -> ex.authenticationEntryPoint(unauthenticated).accessDeniedHandler(forbidden))
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .csrf(AbstractHttpConfigurer::disable)
                .cors(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .build();
    }

    /**
     * Supabase's JWKS (asymmetric keys) by default. When {@code proxycare.supabase.jwt-secret} is set,
     * the legacy HS256 secret is used instead; otherwise HS256 tokens are rejected.
     */
    @Bean
    JwtDecoder jwtDecoder(AppProperties props, Clock clock) throws MalformedURLException {
        String supabaseUrl = props.supabase().url();
        String secret = props.supabase().jwtSecret();
        if (StringUtils.hasText(secret)) {
            var key = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            var decoder = NimbusJwtDecoder.withSecretKey(key).macAlgorithm(MacAlgorithm.HS256).build();
            decoder.setJwtValidator(validators(supabaseUrl, clock));
            return decoder;
        }
        // Keys are fetched lazily and cached by Nimbus, so startup makes no network call.
        JWKSource<SecurityContext> keys = JWKSourceBuilder.create(
                        URI.create(supabaseUrl + "/auth/v1/.well-known/jwks.json").toURL())
                .build();
        return jwksDecoder(keys, supabaseUrl, clock);
    }

    /**
     * The one place that sets the accepted algorithms (ES256, Supabase's default, and RS256) and the
     * claim rules. Prod passes the real Clock; tests pass the MutableClock and their own keys.
     */
    public static NimbusJwtDecoder jwksDecoder(JWKSource<SecurityContext> keys, String supabaseUrl, Clock clock) {
        var decoder = NimbusJwtDecoder.withJwkSource(keys)
                .jwsAlgorithms(algs -> {
                    algs.add(SignatureAlgorithm.ES256);
                    algs.add(SignatureAlgorithm.RS256);
                })
                .build();
        decoder.setJwtValidator(validators(supabaseUrl, clock));
        return decoder;
    }

    private static OAuth2TokenValidator<Jwt> validators(String supabaseUrl, Clock clock) {
        var timestamps = new JwtTimestampValidator(Duration.ofSeconds(30));
        timestamps.setClock(clock);
        return new DelegatingOAuth2TokenValidator<>(
                timestamps,
                new JwtIssuerValidator(supabaseUrl + "/auth/v1"),
                new JwtClaimValidator<List<String>>("aud", aud -> aud != null && aud.contains(AUDIENCE)));
    }
}
