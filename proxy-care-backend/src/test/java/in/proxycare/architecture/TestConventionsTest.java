package in.proxycare.architecture;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noFields;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import java.time.Duration;
import java.util.concurrent.TimeUnit;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;

/** Conventions for the test code itself (docs/TESTING.md). */
@AnalyzeClasses(packages = "in.proxycare", importOptions = ImportOption.OnlyIncludeTests.class)
class TestConventionsTest {

  /** Waiting is done with latches, futures or Awaitility, never with sleeps. */
  @ArchTest
  static final ArchRule noSleeping =
      noClasses()
          .should()
          .callMethod(Thread.class, "sleep", long.class)
          .orShould()
          .callMethod(Thread.class, "sleep", long.class, int.class)
          .orShould()
          .callMethod(Thread.class, "sleep", Duration.class)
          .orShould()
          .callMethod(TimeUnit.class, "sleep", long.class);

  /**
   * Integration tests use {@code @IntegrationTest}, so they share one cached Spring context and one
   * database container, and get cleanup before each test.
   */
  @ArchTest
  static final ArchRule integrationTestsUseTheSharedSetup =
      noClasses()
          .that()
          .areNotAnnotations()
          .should()
          .beAnnotatedWith(SpringBootTest.class)
          .because("integration tests use @IntegrationTest");

  /** Each of these forces a new Spring context and with it a slower, less shared test run. */
  @ArchTest
  static final ArchRule noContextBreakingAnnotations =
      noClasses()
          .should()
          .beAnnotatedWith(DirtiesContext.class)
          .allowEmptyShould(true)
          .because("tests clean up state instead of discarding the context");

  @ArchTest
  static final ArchRule integrationTestsUseRealBeans =
      noFields()
          .should()
          .beAnnotatedWith(MockitoBean.class)
          .orShould()
          .beAnnotatedWith(MockitoSpyBean.class)
          .allowEmptyShould(true)
          .because("integration tests use real beans and WireMock; mocks belong in unit tests");
}
