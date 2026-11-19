package com.proxycare;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class ProxyCareApplication {

    public static void main(String[] args) {
        SpringApplication.run(ProxyCareApplication.class, args);
    }
}
