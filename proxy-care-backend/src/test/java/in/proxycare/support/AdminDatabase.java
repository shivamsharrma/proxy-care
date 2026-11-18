package in.proxycare.support;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Set;
import javax.sql.DataSource;
import org.springframework.jdbc.core.simple.JdbcClient;

/**
 * Superuser SQL for tests that inspect or bypass privileges: catalog checks, acting as another
 * role, cleanup. Code under test always uses the application role; this exists only in tests.
 */
public final class AdminDatabase {

  /** Roles a test may act as; never interpolated from anything else. */
  private static final Set<String> ROLES =
      Set.of("anon", "authenticated", "service_role", "proxycare_app", "proxycare_migrator");

  private final DataSource dataSource = PostgresTestcontainersConfiguration.adminDataSource();
  private final JdbcClient jdbc = JdbcClient.create(dataSource);

  public JdbcClient client() {
    return jdbc;
  }

  /**
   * Executes {@code sql} on one connection after {@code SET ROLE role}, the way PostgREST runs a
   * mobile client's request. Throws the database's error, for example "permission denied".
   */
  public void executeAs(String role, String sql) throws SQLException {
    if (!ROLES.contains(role)) {
      throw new IllegalArgumentException("unknown test role: " + role);
    }
    try (Connection connection = dataSource.getConnection();
        Statement statement = connection.createStatement()) {
      statement.execute("set role " + role);
      statement.execute(sql);
    }
  }
}
