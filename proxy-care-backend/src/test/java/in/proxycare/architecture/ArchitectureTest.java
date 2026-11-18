package in.proxycare.architecture;

import static com.tngtech.archunit.core.domain.JavaClass.Predicates.assignableTo;
import static com.tngtech.archunit.core.domain.JavaClass.Predicates.resideInAPackage;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.codeUnits;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.methods;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noFields;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noMethods;

import com.tngtech.archunit.base.DescribedPredicate;
import com.tngtech.archunit.core.domain.Dependency;
import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.domain.JavaCodeUnit;
import com.tngtech.archunit.core.domain.JavaMethod;
import com.tngtech.archunit.core.domain.JavaMethodCall;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;
import com.tngtech.archunit.library.GeneralCodingRules;
import jakarta.persistence.Entity;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.repository.Repository;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Example architecture test: the rules of ADR 0002 and ADR 0009 that Spring Modulith does not cover
 * (ModularityTest covers module cycles and named interfaces). Rules about code that does not exist
 * yet allow an empty match, so they guard every future module from its first class.
 */
@AnalyzeClasses(packages = "in.proxycare", importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

  private static final String[] FEATURE_MODULES = {
    "in.proxycare.identity..", "in.proxycare.integrations..", "in.proxycare.webhooks..",
    "in.proxycare.health..", "in.proxycare.booking..", "in.proxycare.dispatch..",
    "in.proxycare.ride..", "in.proxycare.billing..", "in.proxycare.settlement..",
    "in.proxycare.kyc..", "in.proxycare.notification.."
  };

  /** Vendor SDK packages; only the integrations module may touch them (ADR 0009). */
  private static final String[] VENDOR_SDKS = {
    "com.razorpay..", "com.google.firebase..", "com.google.maps..", "com.uber..",
    "co.hyperverge..", "com.hyperverge..", "com.freshdesk..", "io.supabase.."
  };

  /** in.proxycare.(module).(layer)... */
  private static final Pattern MODULE_LAYER =
      Pattern.compile(
          "^in\\.proxycare\\.([a-z]+)\\.(api|application|domain|infrastructure)(\\..*)?$");

  // ---- Module boundaries -------------------------------------------------------------------

  @ArchTest
  static final ArchRule sharedDependsOnNoFeatureModule =
      noClasses()
          .that()
          .resideInAPackage("in.proxycare.shared..")
          .should()
          .dependOnClassesThat()
          .resideInAnyPackage(FEATURE_MODULES);

  @ArchTest
  static final ArchRule modulesUseOnlyEachOthersPublicApi =
      classes()
          .that()
          .resideInAPackage("in.proxycare..")
          .should(notReachIntoAnotherModulesLayers())
          .allowEmptyShould(true);

  @ArchTest
  static final ArchRule vendorSdksStayInsideIntegrations =
      noClasses()
          .that()
          .resideOutsideOfPackage("in.proxycare.integrations..")
          .should()
          .dependOnClassesThat()
          .resideInAnyPackage(VENDOR_SDKS)
          .allowEmptyShould(true);

  // ---- Layers inside a module ---------------------------------------------------------------

  @ArchTest
  static final ArchRule domainIsPureJava =
      noClasses()
          .that()
          .resideInAPackage("in.proxycare..domain..")
          .should()
          .dependOnClassesThat()
          .resideInAnyPackage(
              "org.springframework..",
              "jakarta.persistence..",
              "org.hibernate..",
              "tools.jackson..",
              "com.fasterxml.jackson..",
              "in.proxycare.integrations..")
          .allowEmptyShould(true);

  @ArchTest
  static final ArchRule domainDoesNotUseTheWeb =
      noClasses()
          .that()
          .resideInAPackage("in.proxycare..domain..")
          .should()
          .dependOnClassesThat()
          .resideInAnyPackage(
              "org.springframework.web..", "org.springframework.http..", "jakarta.servlet..")
          .allowEmptyShould(true);

  @ArchTest
  static final ArchRule domainDependsOnNoOuterLayer =
      noClasses()
          .that()
          .resideInAPackage("in.proxycare.*.domain..")
          .should()
          .dependOnClassesThat()
          .resideInAnyPackage(
              "in.proxycare.*.api..",
              "in.proxycare.*.application..",
              "in.proxycare.*.infrastructure..")
          .allowEmptyShould(true);

  @ArchTest
  static final ArchRule applicationDependsOnNeitherWebNorInfrastructure =
      noClasses()
          .that()
          .resideInAPackage("in.proxycare.*.application..")
          .should()
          .dependOnClassesThat()
          .resideInAnyPackage("in.proxycare.*.api..", "in.proxycare.*.infrastructure..")
          .allowEmptyShould(true);

  @ArchTest
  static final ArchRule controllersDoNotAccessRepositories =
      noClasses()
          .that()
          .areAnnotatedWith(RestController.class)
          .or()
          .resideInAPackage("in.proxycare.*.api..")
          .should()
          .dependOnClassesThat(
              assignableTo(Repository.class)
                  .or(resideInAPackage("in.proxycare.*.infrastructure..")))
          .allowEmptyShould(true);

  @ArchTest
  static final ArchRule controllersLiveInTheApiLayer =
      classes()
          .that()
          .areAnnotatedWith(RestController.class)
          .should()
          .resideInAPackage("in.proxycare.*.api..")
          .allowEmptyShould(true);

  /**
   * The /api/v1 prefix is added centrally (ApiWebConfiguration); a controller must not repeat it.
   */
  @ArchTest
  static final ArchRule controllersDeclareOnlyResourcePaths =
      classes()
          .that()
          .areAnnotatedWith(RestController.class)
          .should(notMapPathsStartingWith("/api"))
          .allowEmptyShould(true);

  /**
   * Domain code throws these, so they stay plain Java (shared.error.web holds the HTTP mapping).
   */
  @ArchTest
  static final ArchRule errorTypesArePlainJava =
      noClasses()
          .that()
          .resideInAPackage("in.proxycare.shared.error")
          .should()
          .dependOnClassesThat()
          .resideInAnyPackage(
              "org.springframework..", "jakarta..", "tools.jackson..", "com.fasterxml.jackson..");

  @ArchTest
  static final ArchRule entitiesLiveInTheInfrastructureLayer =
      classes()
          .that()
          .areAnnotatedWith(Entity.class)
          .should()
          .resideInAPackage("in.proxycare.*.infrastructure..")
          .allowEmptyShould(true);

  @ArchTest
  static final ArchRule controllersNeverExposeEntities =
      methods()
          .that()
          .areDeclaredInClassesThat()
          .areAnnotatedWith(RestController.class)
          .should(neverMentionAnEntity())
          .allowEmptyShould(true);

  // ---- Coding rules -------------------------------------------------------------------------

  @ArchTest
  static final ArchRule noFieldInjection = GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION;

  @ArchTest
  static final ArchRule noSetterInjection =
      noMethods().should().beAnnotatedWith(Autowired.class).allowEmptyShould(true);

  @ArchTest
  static final ArchRule noJavaUtilLogging =
      GeneralCodingRules.NO_CLASSES_SHOULD_USE_JAVA_UTIL_LOGGING;

  @ArchTest
  static final ArchRule noStandardStreams =
      GeneralCodingRules.NO_CLASSES_SHOULD_ACCESS_STANDARD_STREAMS;

  @ArchTest
  static final ArchRule timeComesFromTheInjectedClock =
      noClasses()
          .that()
          .resideOutsideOfPackage("in.proxycare.shared.time..")
          .should()
          .callMethodWhere(readsTheSystemClock())
          .allowEmptyShould(true);

  // ---- Money --------------------------------------------------------------------------------

  @ArchTest
  static final ArchRule moneyFieldsAreNeverFloatingPoint =
      noFields()
          .that()
          .areDeclaredInClassesThat(areAboutMoney())
          .should()
          .haveRawType(floatingPoint())
          .allowEmptyShould(true);

  @ArchTest
  static final ArchRule moneyMethodsNeverTakeOrReturnFloatingPoint =
      codeUnits()
          .that()
          .areDeclaredInClassesThat(areAboutMoney())
          .should(neverUseFloatingPoint())
          .allowEmptyShould(true);

  // ---- Predicates and conditions --------------------------------------------------------------

  private static ArchCondition<JavaClass> notReachIntoAnotherModulesLayers() {
    return new ArchCondition<>(
        "not depend on another module's api/application/domain/infrastructure") {
      @Override
      public void check(JavaClass origin, ConditionEvents events) {
        String originModule = moduleOf(origin.getPackageName()).orElse(null);
        for (Dependency dependency : origin.getDirectDependenciesFromSelf()) {
          Matcher target = MODULE_LAYER.matcher(dependency.getTargetClass().getPackageName());
          if (target.matches()
              && !target.group(1).equals("shared")
              && !target.group(1).equals(originModule)) {
            events.add(SimpleConditionEvent.violated(origin, dependency.getDescription()));
          }
        }
      }
    };
  }

  private static ArchCondition<JavaClass> notMapPathsStartingWith(String prefix) {
    return new ArchCondition<>("not map paths starting with " + prefix) {
      @Override
      public void check(JavaClass controller, ConditionEvents events) {
        controller
            .tryGetAnnotationOfType(RequestMapping.class)
            .ifPresent(mapping -> {
              for (String path : concat(mapping.value(), mapping.path())) {
                if (path.startsWith(prefix)) {
                  events.add(
                      SimpleConditionEvent.violated(
                          controller, controller.getName() + " maps " + path));
                }
              }
            });
      }
    };
  }

  private static List<String> concat(String[] first, String[] second) {
    List<String> all = new java.util.ArrayList<>(List.of(first));
    all.addAll(List.of(second));
    return all;
  }

  private static Optional<String> moduleOf(String packageName) {
    String prefix = "in.proxycare.";
    if (!packageName.startsWith(prefix)) {
      return Optional.empty();
    }
    String rest = packageName.substring(prefix.length());
    int dot = rest.indexOf('.');
    return Optional.of(dot < 0 ? rest : rest.substring(0, dot));
  }

  private static DescribedPredicate<JavaMethodCall> readsTheSystemClock() {
    // Covers Instant.now(), LocalDateTime.now(), LocalDate.now() and every other java.time now(),
    // the system clocks, and the host's time zone (business time is BusinessTime.ZONE).
    Set<String> clockReads = Set.of("now", "systemUTC", "systemDefaultZone", "systemDefault");
    return DescribedPredicate.describe(
        "java.time now()/system clock/system zone or System.currentTimeMillis()",
        call ->
            (call.getTargetOwner().getPackageName().equals("java.time")
                    && clockReads.contains(call.getName()))
                || (call.getTargetOwner().isEquivalentTo(System.class)
                    && call.getName().equals("currentTimeMillis")));
  }

  private static DescribedPredicate<JavaClass> areAboutMoney() {
    return DescribedPredicate.describe(
        "are about money",
        javaClass ->
            javaClass.getPackageName().matches(".*\\.(money|billing|settlement)(\\..*)?")
                || javaClass
                    .getSimpleName()
                    .matches(".*(Money|Price|Fee|Amount|Payout|Paise|Wallet|Earning).*"));
  }

  private static DescribedPredicate<JavaClass> floatingPoint() {
    return DescribedPredicate.describe(
        "a floating-point type",
        type ->
            type.isEquivalentTo(float.class)
                || type.isEquivalentTo(double.class)
                || type.isEquivalentTo(Float.class)
                || type.isEquivalentTo(Double.class));
  }

  private static ArchCondition<JavaCodeUnit> neverUseFloatingPoint() {
    DescribedPredicate<JavaClass> floatingPoint = floatingPoint();
    return new ArchCondition<>("never take or return a floating-point type") {
      @Override
      public void check(JavaCodeUnit codeUnit, ConditionEvents events) {
        boolean returns = floatingPoint.test(codeUnit.getRawReturnType());
        boolean takes = codeUnit.getRawParameterTypes().stream().anyMatch(floatingPoint);
        if (returns || takes) {
          events.add(
              SimpleConditionEvent.violated(
                  codeUnit, codeUnit.getFullName() + " uses floating point for money"));
        }
      }
    };
  }

  private static ArchCondition<JavaMethod> neverMentionAnEntity() {
    return new ArchCondition<>("never take or return a JPA entity") {
      @Override
      public void check(JavaMethod method, ConditionEvents events) {
        boolean returnsEntity =
            method.getReturnType().getAllInvolvedRawTypes().stream()
                .anyMatch(type -> type.isAnnotatedWith(Entity.class));
        boolean takesEntity =
            method.getParameterTypes().stream()
                .flatMap(type -> type.getAllInvolvedRawTypes().stream())
                .anyMatch(type -> type.isAnnotatedWith(Entity.class));
        if (returnsEntity || takesEntity) {
          events.add(
              SimpleConditionEvent.violated(
                  method, method.getFullName() + " exposes a JPA entity through the API"));
        }
      }
    };
  }
}
