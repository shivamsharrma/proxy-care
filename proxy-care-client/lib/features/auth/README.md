# features/auth

Authentication feature. The layer folders are in place; no implementation
exists yet. Follow `ARCHITECTURE.md` (Feature module conventions) when
adding code.

```text
auth/
├── auth_providers.dart        Provider wiring for this feature
├── data/
│   ├── datasources/           Remote/local data sources (Dio, storage)
│   ├── dto/                   API request/response shapes (json_serializable)
│   ├── mappers/               DTO <-> entity conversion
│   └── repositories/          Implementations of domain contracts
├── domain/
│   ├── entities/              Business objects (pure Dart)
│   ├── repositories/          Repository interfaces
│   └── usecases/              One action per class
└── presentation/
    └── controllers/           Notifier / AsyncNotifier controllers
```
