package in.proxycare.support;

import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.inOrder;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationContext;

/**
 * Example Mockito unit test: collaborators are mocked, behaviour is verified. {@link
 * DatabaseCleaner} and {@link MutableClock} are final classes, so this also proves the inline mock
 * maker agent is attached (build.gradle.kts).
 */
@ExtendWith(MockitoExtension.class)
class IntegrationTestExtensionTest {

  @Mock private ApplicationContext applicationContext;
  @Mock private DatabaseCleaner cleaner;
  @Mock private MutableClock clock;

  @Test
  void cleansTheDatabaseAndResetsTheClockBeforeEachTest() {
    // Arrange
    given(applicationContext.getBean(DatabaseCleaner.class)).willReturn(cleaner);
    given(applicationContext.getBean(MutableClock.class)).willReturn(clock);

    // Act
    IntegrationTestExtension.reset(applicationContext);

    // Assert
    InOrder order = inOrder(cleaner, clock);
    order.verify(cleaner).clean();
    order.verify(clock).reset();
    order.verifyNoMoreInteractions();
  }
}
