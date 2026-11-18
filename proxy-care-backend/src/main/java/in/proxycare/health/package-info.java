/** Liveness and readiness composition for the actuator (ADR 0006). */
@ApplicationModule(displayName = "Health", allowedDependencies = "shared")
package in.proxycare.health;

import org.springframework.modulith.ApplicationModule;
