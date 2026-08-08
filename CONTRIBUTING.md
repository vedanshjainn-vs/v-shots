# Contributing to Project Lyra

Thank you for your interest in contributing to Project Lyra!

## Development Setup

### Prerequisites
- Flutter SDK ≥ 3.16.0
- Dart SDK ≥ 3.2.0
- Android Studio / VS Code
- Git

### Getting Started

```bash
# Clone the repository
git clone https://github.com/your-org/project-lyra.git
cd project_lyra

# Install dependencies
flutter pub get

# Generate code
make codegen

# Run tests
make test

# Run in development mode
make dev
```

## Architecture

We follow **Clean Architecture** with **Feature-First** organization:

```
features/auth/
├── data/           # Data layer
├── domain/         # Business logic
└── presentation/   # UI layer
```

### Key Principles
- **SOLID** principles
- **Dependency Inversion** — domain never imports data
- **Result<T>** — no raw exceptions
- **Freezed** — immutable models
- **Riverpod** — state management

## Code Style

### Formatting
```bash
dart format lib/ test/
```

### Analysis
```bash
dart analyze --fatal-infos --fatal-warnings
```

### Naming Conventions
- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables**: `camelCase`
- **Constants**: `camelCase` (non-class), `PascalCase` (class-level)
- **Enums**: `PascalCase` for type, `camelCase` for values

## Pull Request Process

1. Create a feature branch from `develop`
2. Make your changes
3. Run tests: `make test`
4. Run analysis: `dart analyze`
5. Format code: `dart format .`
6. Create a PR with a clear description
7. Wait for code review

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add playlist creation
fix: resolve audio playback issue
docs: update README
test: add unit tests for auth
refactor: simplify cache layer
```

## Testing

### Unit Tests
```bash
flutter test test/unit/
```

### Widget Tests
```bash
flutter test test/widget/
```

### Integration Tests
```bash
flutter test integration_test/
```

## Questions?

Open an issue or contact the maintainers.

Thank you for contributing! 🎵
