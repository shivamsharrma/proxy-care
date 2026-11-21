# core/services

Cross-cutting application services that are not HTTP or storage: for
example analytics, connectivity or clock abstractions.

- Each service is defined as an interface plus an implementation, and
  registered as a provider in `core/di`.
- Services must not depend on features.
