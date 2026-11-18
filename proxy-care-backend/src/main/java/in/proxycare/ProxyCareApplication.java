package in.proxycare;

import java.time.ZoneOffset;
import java.util.TimeZone;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.boot.security.autoconfigure.UserDetailsServiceAutoConfiguration;

/** Proxy Care backend: a Spring Modulith modular monolith (see docs/ARCHITECTURE.md). */
// Users authenticate with Supabase JWTs (ADR 0004). Boot's default in-memory user would
// otherwise exist with a generated password that is printed to the log.
@SpringBootApplication(exclude = UserDetailsServiceAutoConfiguration.class)
@ConfigurationPropertiesScan
public class ProxyCareApplication {

  public static void main(String[] args) {
    // Persistence and logs are UTC regardless of the host's zone (ADR 0003).
    TimeZone.setDefault(TimeZone.getTimeZone(ZoneOffset.UTC));
    SpringApplication.run(ProxyCareApplication.class, args);
  }
}
