package in.proxycare.shared.security;

import in.proxycare.shared.error.web.ProblemSecurityHandlers;
import jakarta.servlet.DispatcherType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Deny-by-default baseline until authentication arrives (ADR 0004).
 *
 * <p>Only health, info, metrics scraping and API documentation are reachable; every other request
 * is refused with a problem response: 401 for an anonymous caller, 403 for an authenticated one
 * (ADR 0012). API documentation is switched off in production by configuration, and the actuator
 * runs on an internal management port in staging and production.
 *
 * <p>CSRF protection is off: the API is stateless and authenticated by bearer tokens, never by
 * cookies, so there is no ambient credential to forge (ADR 0004).
 */
@Configuration(proxyBeanMethods = false)
class SecurityConfiguration {

  private static final String[] PUBLIC_PATHS = {
    "/actuator/health",
    "/actuator/health/**",
    "/actuator/info",
    "/actuator/prometheus",
    "/v3/api-docs",
    "/v3/api-docs/**",
    "/swagger-ui.html",
    "/swagger-ui/**"
  };

  @Bean
  SecurityFilterChain securityFilterChain(HttpSecurity http, ProblemSecurityHandlers problems)
      throws Exception {
    return http.authorizeHttpRequests(requests ->
            requests
                // The container's error page renders errors already decided elsewhere.
                .dispatcherTypeMatchers(DispatcherType.ERROR)
                .permitAll()
                .requestMatchers(PUBLIC_PATHS)
                .permitAll()
                .anyRequest()
                .denyAll())
        .exceptionHandling(exceptions ->
            exceptions.authenticationEntryPoint(problems).accessDeniedHandler(problems))
        .sessionManagement(
            session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .csrf(AbstractHttpConfigurer::disable)
        .httpBasic(AbstractHttpConfigurer::disable)
        .formLogin(AbstractHttpConfigurer::disable)
        .logout(AbstractHttpConfigurer::disable)
        .requestCache(AbstractHttpConfigurer::disable)
        .build();
  }
}
