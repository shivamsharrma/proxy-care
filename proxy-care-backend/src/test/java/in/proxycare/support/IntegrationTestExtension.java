package in.proxycare.support;

import org.junit.jupiter.api.extension.BeforeEachCallback;
import org.junit.jupiter.api.extension.ExtensionContext;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.junit.jupiter.SpringExtension;

/**
 * Gives every integration test the same starting state: empty tables and the clock at {@link
 * MutableClock#DEFAULT_INSTANT}. Cleaning before (not after) each test means a test that crashed
 * cannot leave state for the next one.
 */
final class IntegrationTestExtension implements BeforeEachCallback {

  @Override
  public void beforeEach(ExtensionContext context) {
    reset(SpringExtension.getApplicationContext(context));
  }

  static void reset(ApplicationContext applicationContext) {
    applicationContext.getBean(DatabaseCleaner.class).clean();
    applicationContext.getBean(MutableClock.class).reset();
  }
}
