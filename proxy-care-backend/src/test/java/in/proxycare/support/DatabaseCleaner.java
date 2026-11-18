package in.proxycare.support;

import java.util.List;
import java.util.stream.Collectors;
import org.springframework.jdbc.core.simple.JdbcClient;

/**
 * Empties every table in the application schema except Flyway's history, in one statement.
 *
 * <p>Truncation (not transaction rollback) is the default isolation strategy because integration
 * tests often commit: concurrency tests, listeners running after commit, MockMvc requests.
 */
public final class DatabaseCleaner {

  static final String SCHEMA = "proxycare";
  private static final List<String> PRESERVED_TABLES = List.of("flyway_schema_history");

  private final JdbcClient jdbc;

  public DatabaseCleaner(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public void clean() {
    List<String> tables =
        jdbc
            .sql(
                "select tablename from pg_catalog.pg_tables where schemaname = :schema"
                    + " order by tablename")
            .param("schema", SCHEMA)
            .query(String.class)
            .list()
            .stream()
            .filter(table -> !PRESERVED_TABLES.contains(table))
            .toList();
    if (tables.isEmpty()) {
      return;
    }
    // Identifiers cannot be bind parameters; these come from the catalog, quoted defensively.
    String qualified =
        tables.stream()
            .map(table -> quote(SCHEMA) + "." + quote(table))
            .collect(Collectors.joining(", "));
    jdbc.sql("truncate table " + qualified + " restart identity cascade").update();
  }

  private static String quote(String identifier) {
    return '"' + identifier.replace("\"", "\"\"") + '"';
  }
}
