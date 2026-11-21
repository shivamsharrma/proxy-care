package com.proxycare.common.security.jwt;

import java.net.MalformedURLException;
import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.jwt.JwtDecoder;

@Configuration(proxyBeanMethods = false)
public class SupabaseJwtDecoderConfig {

    @Bean
    JwtDecoder jwtDecoder(JwtProperties jwtProperties, Clock clock) throws MalformedURLException {
        return SupabaseJwtDecoderFactory.fromSupabaseJwks(jwtProperties, clock);
    }
}
