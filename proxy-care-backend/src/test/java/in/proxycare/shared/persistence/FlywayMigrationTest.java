package in.proxycare.shared.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import in.proxycare.support.AdminDatabase;
import in.proxycare.support.IntegrationTest;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.flywaydb.core.api.MigrationState;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * Every migration (production plus test fixtures) applies cleanly to an empty PostGIS database at
 * start-up, and Hibernate's schema validation accepts the result (the context would not start
 * otherwise).
 */
@IntegrationTest
class FlywayMigrationTest {

  @Autowired private Flyway flyway;
  @Autowired private AdminDatabase admin;

  @Test
  void migratesAnEmptyDatabaseFromTheBaseline() {
    MigrationInfo[] applied = flyway.info().applied();

    assertThat(applied).isNotEmpty();
    assertThat(applied)
        .extracting(MigrationInfo::getState)
        .allMatch(state -> state == MigrationState.SUCCESS);
    assertThat(applied[0].getVersion().getVersion()).isEqualTo("202611181200");
    assertThat(flyway.info().pending()).isEmpty();
  }

  @Test
  void runsAsTheSchemaOwnerNotTheApplication() {
    assertThat(
            admin
                .client()
                .sql("select distinct installed_by from proxycare.flyway_schema_history")
                .query(String.class)
                .list())
        .containsExactly("proxycare_migrator");
  }

  @Test
  void neverCreatesTheSchemaItself() {
    // The schema comes from database/setup/roles.sql; Flyway records a schema it created.
    assertThat(flyway.getConfiguration().isCreateSchemas()).isFalse();
    assertThat(
            admin
                .client()
                .sql("select count(*) from proxycare.flyway_schema_history where type = 'SCHEMA'")
                .query(Long.class)
                .single())
        .isZero();
  }

  @Test
  void checksumsStillMatchTheMigrationFiles() {
    assertThatCode(flyway::validate).doesNotThrowAnyException();
  }

  @Test
  void keepsItsHistoryInTheApplicationSchema() {
    assertThat(flyway.getConfiguration().getDefaultSchema()).isEqualTo("proxycare");
    assertThat(tableExists("flyway_schema_history")).isTrue();
  }

  @Test
  void loadsTheTestOnlyFixtures() {
    assertThat(tableExists("test_probe")).isTrue();
  }

  private boolean tableExists(String table) {
    return admin
        .client()
        .sql(
            "select exists (select 1 from information_schema.tables"
                + " where table_schema = 'proxycare' and table_name = :table)")
        .param("table", table)
        .query(Boolean.class)
        .single();
  }
}
