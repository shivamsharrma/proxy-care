package in.proxycare.support;

import org.junit.platform.launcher.LauncherSession;
import org.junit.platform.launcher.LauncherSessionListener;

/**
 * Stops tests from reaching any real vendor, wherever they run (Gradle or an IDE).
 *
 * <p>Before any test starts, every non-local HTTP(S) request is routed to a proxy on a closed local
 * port, so it fails with a connection error. WireMock (localhost) and Testcontainers (Docker
 * socket, localhost ports) are unaffected. The application's HTTP clients honour these JVM proxy
 * settings ({@code RestClientFactory}).
 *
 * <p>Registered in {@code META-INF/services/org.junit.platform.launcher.LauncherSessionListener}.
 */
public final class VendorCallGuard implements LauncherSessionListener {

  /** Discard port: nothing listens on it, so connections are refused immediately. */
  static final String DEAD_PROXY_HOST = "127.0.0.1";

  static final String DEAD_PROXY_PORT = "9";
  static final String LOCAL_HOSTS = "localhost|127.0.0.1|[::1]";

  @Override
  public void launcherSessionOpened(LauncherSession session) {
    System.setProperty("http.proxyHost", DEAD_PROXY_HOST);
    System.setProperty("http.proxyPort", DEAD_PROXY_PORT);
    System.setProperty("https.proxyHost", DEAD_PROXY_HOST);
    System.setProperty("https.proxyPort", DEAD_PROXY_PORT);
    // Applies to both http and https.
    System.setProperty("http.nonProxyHosts", LOCAL_HOSTS);
  }
}
