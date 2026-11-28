package com.proxycare.config.cache;

import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Turns on {@code @Cacheable}. Boot's cache auto-configuration isn't on the classpath, so this declares the same
 * in-memory default it would create: per instance, unbounded, no expiry. Only stable reference data is cached.
 */
@Configuration(proxyBeanMethods = false)
@EnableCaching
public class CacheConfig {

    @Bean
    CacheManager cacheManager() {
        return new ConcurrentMapCacheManager();
    }
}
