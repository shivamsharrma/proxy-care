package in.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

@IntegrationTest
class DatabaseCleanerTest {

  @Autowired private DatabaseCleaner cleaner;
  @Autowired private JdbcClient jdbc;
  @Autowired private AdminDatabase admin;
  @Autowired private MutableClock clock;

  @Test
  void emptiesApplicationTablesAndKeepsMigrationHistory() {
    long migrations = count("flyway_schema_history");
    for (int i = 1; i <= 3; i++) {
      jdbc.sql(
              "insert into proxycare.test_probe (id, natural_key, amount_paise, created_at)"
                  + " values (:id, :key, 0, :createdAt)")
          .param("id", TestIds.uuid(9, i))
          .param("key", "row-" + i)
          .param("createdAt", clock.instant().atOffset(ZoneOffset.UTC))
          .update();
    }

    cleaner.clean();

    assertThat(count("test_probe")).isZero();
    assertThat(count("flyway_schema_history")).isEqualTo(migrations).isPositive();
  }

  /** As admin: the application role may not read Flyway's history, by design. */
  private long count(String table) {
    return admin.client().sql("select count(*) from proxycare." + table).query(Long.class).single();
  }
}
