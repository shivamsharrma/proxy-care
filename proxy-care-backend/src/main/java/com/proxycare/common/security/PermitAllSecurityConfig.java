package com.proxycare.common.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

/** TEMPORARY (M0–M3): permits every request. M4 deletes this class and adds SecurityConfig. */
@Configuration(proxyBeanMethods = false)
class PermitAllSecurityConfig {

    @Bean
    SecurityFilterChain permitAll(HttpSecurity http) throws Exception {
        return http.authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
                .csrf(AbstractHttpConfigurer::disable)
                .build();
    }
}
