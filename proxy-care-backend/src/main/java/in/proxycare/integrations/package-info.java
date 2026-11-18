/**
 * Vendor clients, one sub-package per vendor (for example {@code integrations.razorpay}): HTTP,
 * authentication, signatures and typed vendor DTOs. No business meaning (ADR 0009).
 */
@ApplicationModule(displayName = "Integrations", allowedDependencies = "shared")
package in.proxycare.integrations;

import org.springframework.modulith.ApplicationModule;
