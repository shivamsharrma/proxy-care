package in.proxycare.shared.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import in.proxycare.support.AdminDatabase;
import in.proxycare.support.IntegrationTest;
import java.sql.SQLException;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.BadSqlGrammarException;
import org.springframework.jdbc.core.simple.JdbcClient;

/**
 * The database privilege model (docs/DATABASE.md), checked in the catalog and by acting as each
 * role. Applies to every table in schema proxycare, including ones added later.
 */
@IntegrationTest
class DatabaseSecurityTest {

  @Autowired private JdbcClient app;
  @Autowired private AdminDatabase admin;

  @Test
  void theApplicationConnectsAsItsOwnRestrictedRole() {
    assertThat(app.sql("select current_user").query(String.class).single())
        .isEqualTo("proxycare_app");
    assertThat(
            admin
                .client()
                .sql(
                    "select rolsuper or rolcreaterole or rolcreatedb or rolbypassrls"
                        + " from pg_catalog.pg_roles where rolname = 'proxycare_app'")
                .query(Boolean.class)
                .single())
        .isFalse();
  }

  @Test
  void theMigratorOwnsTheSchemaAndEveryTable() {
    assertThat(
            admin
                .client()
                .sql(
                    "select nspowner::regrole::text from pg_catalog.pg_namespace"
                        + " where nspname = 'proxycare'")
                .query(String.class)
                .single())
        .isEqualTo("proxycare_migrator");
    assertThat(
            admin
                .client()
                .sql(
                    "select distinct tableowner from pg_catalog.pg_tables where schemaname = 'proxycare'")
                .query(String.class)
                .list())
        .containsExactly("proxycare_migrator");
  }

  @Test
  void everyApplicationTableHasRowLevelSecurityWithOnlyTheApplicationPolicy() {
    List<String> tables = applicationTables();
    assertThat(tables).isNotEmpty();

    assertThat(
            admin
                .client()
                .sql(
                    "select c.relname from pg_catalog.pg_class c"
                        + " join pg_catalog.pg_namespace n on n.oid = c.relnamespace"
                        + " where n.nspname = 'proxycare' and c.relkind = 'r'"
                        + " and c.relname <> 'flyway_schema_history' and not c.relrowsecurity")
                .query(String.class)
                .list())
        .as("tables without row level security")
        .isEmpty();
    assertThat(
            admin
                .client()
                .sql(
                    "select distinct tablename || ':' || policyname || ':' || array_to_string(roles, ',')"
                        + " from pg_catalog.pg_policies where schemaname = 'proxycare'")
                .query(String.class)
                .list())
        .as("policies")
        .containsExactlyInAnyOrderElementsOf(
            tables.stream().map(table -> table + ":proxycare_app_all:proxycare_app").toList());
  }

  @ParameterizedTest
  @ValueSource(strings = {"anon", "authenticated", "service_role"})
  void supabaseApiRolesHaveNoAccess(String apiRole) {
    assertThat(privilege("select has_schema_privilege(:role, 'proxycare', 'USAGE')", apiRole))
        .isFalse();
    for (String table : applicationTables()) {
      assertThat(
              privilege(
                  "select has_table_privilege(:role, 'proxycare."
                      + table
                      + "',"
                      + " 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')",
                  apiRole))
          .as("%s on %s", apiRole, table)
          .isFalse();
    }
  }

  @ParameterizedTest
  @ValueSource(strings = {"anon", "authenticated"})
  void mobileClientRolesAreRefusedWhenTheyTry(String apiRole) {
    assertThatThrownBy(() -> admin.executeAs(apiRole, "select count(*) from proxycare.test_probe"))
        .isInstanceOf(SQLException.class)
        .hasMessageContaining("permission denied for schema proxycare");
  }

  @Test
  void theApplicationCanReadAndWriteButNotChangeTheSchema() {
    assertThat(
            privilege(
                "select has_table_privilege(:role, 'proxycare.test_probe', 'SELECT, INSERT, UPDATE, DELETE')",
                "proxycare_app"))
        .isTrue();
    assertThat(
            privilege(
                "select has_table_privilege(:role, 'proxycare.test_probe', 'TRUNCATE')",
                "proxycare_app"))
        .isFalse();
    assertThat(
            privilege("select has_schema_privilege(:role, 'proxycare', 'CREATE')", "proxycare_app"))
        .isFalse();
    assertThatThrownBy(() -> app.sql("create table proxycare.sneaky (id int)").update())
        .isInstanceOf(BadSqlGrammarException.class)
        .rootCause()
        .hasMessageContaining("permission denied for schema proxycare");
    assertThatThrownBy(() -> app.sql("drop table proxycare.test_probe").update())
        .isInstanceOf(BadSqlGrammarException.class)
        .rootCause()
        .hasMessageContaining("must be owner of table test_probe");
  }

  @Test
  void theApplicationCannotTouchMigrationHistory() {
    assertThat(
            privilege(
                "select has_table_privilege(:role, 'proxycare.flyway_schema_history',"
                    + " 'SELECT, INSERT, UPDATE, DELETE')",
                "proxycare_app"))
        .isFalse();
  }

  @Test
  void postGisLivesInTheExtensionsSchemaLikeOnSupabase() {
    assertThat(
            admin
                .client()
                .sql(
                    "select n.nspname from pg_catalog.pg_extension e"
                        + " join pg_catalog.pg_namespace n on n.oid = e.extnamespace"
                        + " where e.extname = 'postgis'")
                .query(String.class)
                .single())
        .isEqualTo("extensions");
  }

  private List<String> applicationTables() {
    return admin
        .client()
        .sql(
            "select tablename from pg_catalog.pg_tables where schemaname = 'proxycare'"
                + " and tablename <> 'flyway_schema_history' order by tablename")
        .query(String.class)
        .list();
  }

  private boolean privilege(String sql, String role) {
    return admin.client().sql(sql).param("role", role).query(Boolean.class).single();
  }
}
