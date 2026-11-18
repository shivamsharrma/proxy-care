package in.proxycare.support.api;

import in.proxycare.shared.api.ApiPaths;
import in.proxycare.shared.error.web.ProblemSecurityHandlers;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/**
 * TEST-ONLY security for the probe API: open, except {@code /secured} (any authenticated caller)
 * and {@code /admin} (a role no test user has). Uses the production problem handlers, so errors
 * from this chain look exactly like production's.
 */
@Configuration(proxyBeanMethods = false)
class ProbeSecurityConfiguration {

  private static final String PROBES = ApiPaths.V1 + "/probes";

  @Bean
  @Order(Ordered.HIGHEST_PRECEDENCE)
  SecurityFilterChain probeSecurity(HttpSecurity http, ProblemSecurityHandlers problems)
      throws Exception {
    return http.securityMatcher(PROBES + "/**", PROBES)
        .authorizeHttpRequests(requests ->
            requests
                .requestMatchers(PROBES + "/secured")
                .authenticated()
                .requestMatchers(PROBES + "/admin")
                .hasRole("ADMIN")
                .anyRequest()
                .permitAll())
        .exceptionHandling(exceptions ->
            exceptions.authenticationEntryPoint(problems).accessDeniedHandler(problems))
        .sessionManagement(
            session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .csrf(AbstractHttpConfigurer::disable)
        .build();
  }
}
