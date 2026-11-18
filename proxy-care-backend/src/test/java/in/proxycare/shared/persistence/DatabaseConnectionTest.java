package in.proxycare.shared.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.support.IntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

/** Every pooled application connection carries the configured session limits and conventions. */
@IntegrationTest
class DatabaseConnectionTest {

  @Autowired private JdbcClient jdbc;

  @Test
  void appliesTheSessionLimits() {
    assertThat(setting("statement_timeout")).isEqualTo("30s");
    assertThat(setting("lock_timeout")).isEqualTo("10s");
    assertThat(setting("idle_in_transaction_session_timeout")).isEqualTo("1min");
  }

  @Test
  void usesUtcAndFindsPostGisWithoutQualification() {
    assertThat(setting("TimeZone")).isEqualTo("UTC");
    assertThat(setting("search_path")).isEqualTo("proxycare, extensions");
    assertThat(jdbc.sql("select postgis_lib_version()").query(String.class).single())
        .startsWith("3.5");
  }

  @Test
  void identifiesTheApplicationToTheDatabase() {
    assertThat(setting("application_name")).isEqualTo("proxy-care-backend");
  }

  private String setting(String name) {
    return jdbc.sql("select current_setting(:name)")
        .param("name", name)
        .query(String.class)
        .single();
  }
}
