/**
 * Technical kernel shared by every module: API conventions, errors, security plumbing, logging,
 * persistence configuration, money, time, idempotency, outbox, jobs, integration base and i18n.
 *
 * <p>Open module: any module may use its packages. It must not depend on any other module (enforced
 * by {@code ArchitectureTest}).
 */
@ApplicationModule(displayName = "Shared kernel", type = ApplicationModule.Type.OPEN)
package in.proxycare.shared;

import org.springframework.modulith.ApplicationModule;
