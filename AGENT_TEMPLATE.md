# Agent Instructions Template (AGENTS.md)

This document is a standard template for configuring the guidelines, context, and rules for AI agents working in this Flutter repository (`manicue`).

---

## 1. Project Overview
- **Project Name:** manicue
- **Primary Technology:** Flutter / Dart
- **Supported Platforms:** Android, iOS, Web, Desktop (Windows, macOS, Linux)

---

## 2. Architecture and Directory Structure
Describe the architecture used in the project here (e.g., Clean Architecture, BLoC, Provider, MVC):
```text
lib/
├── core/          # Utilities, constants, themes, dependency injection
├── data/          # Data sources, models, repositories (implementations)
├── domain/        # Entities, use cases, repository contracts
└── presentation/  # Screens (views), reusable widgets, and ViewModels/Blocs
```

---

## 3. Coding Standards and Conventions
- **Language:** Dart (follow Effective Dart)
- **State Management:** [Define the pattern, e.g., Riverpod, BLoC, Provider, setState]
- **Error Handling:** Use `Result<T, Exception>` or Bloc/State with clear error states.
- **Naming:**
  - Classes use `UpperCamelCase` (e.g., `UserProfileScreen`)
  - Variables and functions use `lowerCamelCase` (e.g., `fetchUserData`)
  - Files use `snake_case` (e.g., `user_profile_screen.dart`)

---

## 4. Testing
- **Unit Tests:** Located in `test/`, mirroring the structure of `lib/`.
- **Widget / UI Tests:** Use `testWidgets` to validate visual components.
- **Run:**
  ```bash
  flutter test
  ```

---

## 5. Critical Agent Instructions and Rules
1. **Never** use shell commands (`sed`, `perl`, `python`, `rm -rf`) to edit source files directly. Always use the IDE's native file-editing tools (`write_file`, `replace_file_content`, etc.).
2. Strictly follow the architecture and conventions already established in the project.
3. Ensure all changes compile without errors and pass the existing tests.
4. Keep the code clean, add clear comments when needed, and avoid dead code.
