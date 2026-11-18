package in.proxycare.support;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;

/**
 * The full application against the test database, with MockMvc and a {@link MutableClock}.
 *
 * <p>Every integration and API test uses exactly this annotation and adds no other context
 * configuration, so all of them share one cached Spring context (ArchitectureTest's test
 * conventions enforce this). Before each test the database is emptied and the clock reset.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(IntegrationTestConfiguration.class)
@ExtendWith(IntegrationTestExtension.class)
public @interface IntegrationTest {}
