package com.proxycare.infrastructure.payout.razorpayx.config;

import com.proxycare.infrastructure.payout.NameMatchPolicy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** The name-match rule with RazorpayX's threshold, since the score it compares is RazorpayX's. */
@Configuration(proxyBeanMethods = false)
public class RazorpayXConfig {

    @Bean
    NameMatchPolicy nameMatchPolicy(RazorpayXProperties razorpayXProperties) {
        return new NameMatchPolicy(razorpayXProperties.nameMatchThreshold());
    }
}
