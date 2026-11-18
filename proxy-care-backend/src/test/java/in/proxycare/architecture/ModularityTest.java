package in.proxycare.architecture;

import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.ProxyCareApplication;
import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModule;
import org.springframework.modulith.core.ApplicationModules;
import org.springframework.modulith.docs.Documenter;

/** Module boundaries from ADR 0002, checked by Spring Modulith. */
class ModularityTest {

  private static final ApplicationModules MODULES =
      ApplicationModules.of(ProxyCareApplication.class);

  @Test
  void detectsTheAgreedModules() {
    assertThat(MODULES.stream().map(ApplicationModule::getIdentifier).map(Object::toString))
        .containsExactlyInAnyOrder("shared", "identity", "integrations", "webhooks", "health");
  }

  @Test
  void respectsModuleBoundaries() {
    MODULES.verify();
  }

  /** Writes module diagrams to build/spring-modulith-docs for review. */
  @Test
  void documentsModules() {
    new Documenter(MODULES).writeDocumentation();
  }
}
