/** Webhook intake: raw-body verification, inbox, de-duplication and dispatch (ADR 0008). */
@ApplicationModule(
    displayName = "Webhooks",
    allowedDependencies = {"shared", "integrations"})
package in.proxycare.webhooks;

import org.springframework.modulith.ApplicationModule;
