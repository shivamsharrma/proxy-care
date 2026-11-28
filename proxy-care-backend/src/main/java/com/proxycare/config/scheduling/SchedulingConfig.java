package com.proxycare.config.scheduling;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/** Runs {@code @Scheduled} jobs. Tests turn it off ({@code proxycare.scheduling.enabled=false}) and call jobs directly. */
@Configuration(proxyBeanMethods = false)
@EnableScheduling
@ConditionalOnProperty(name = "proxycare.scheduling.enabled", havingValue = "true", matchIfMissing = true)
public class SchedulingConfig {}
