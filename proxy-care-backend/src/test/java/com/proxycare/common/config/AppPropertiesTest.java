package com.proxycare.common.config;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.support.TestConfig;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
@Import(TestConfig.class)
class AppPropertiesTest {

    @Autowired
    AppProperties props;

    @Test
    void bindsTestValues() {
        assertThat(props.supabase().url()).isEqualTo("https://test.supabase.co");
        assertThat(props.supabase().jwtSecret()).isNullOrEmpty();
        assertThat(props.razorpay().keyId()).isEqualTo("rzp_test_fake");
        assertThat(props.razorpay().keySecret()).isEqualTo("test-key-secret");
        assertThat(props.razorpay().webhookSecret()).isEqualTo("test-webhook-secret");
        assertThat(props.google().mapsApiKey()).isEqualTo("test-maps-key");
        assertThat(props.uber().clientId()).isEqualTo("test-uber-client");
        assertThat(props.uber().clientSecret()).isEqualTo("test-uber-secret");
    }
}
