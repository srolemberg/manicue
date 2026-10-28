# Agent Instructions

You are an agent responsible for creating and maintaining this project, which integrates Flutter with iCUE through the provided native SDK.

---

## 1. Project Overview
- **Project Name:** manicue
- **Primary Technology:** Flutter / Dart
- **Supported Platforms:** Desktop (Windows, macOS, Linux)

---

## 2. Architecture and Directory Structure
The project architecture has not yet been defined.

---

## 3. Coding Standards and Conventions
- **Language:** Dart (follow Effective Dart)
- **State Management:** setState
- **Error Handling:** Use `Result<T, Exception>`.
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

## 5. Local Reference Materials
Always follow the documentation for the scenarios below:

1. iCUE reference materials
   - [docs/iocue-sdk.md](docs/iocue-sdk.md)
     - Documentation for the iCUE C API
   - [docs/docs.flutter.devplatform-integration.bind-native-code.md](docs/docs.flutter.devplatform-integration.bind-native-code.md)
     - Documentation for integrating Flutter with native code
2. iCUE integration binaries
Binary files or DLLs must be registered in the project's pubspec and copied into an assets directory. The assets directory must also be registered in the pubspec so the files are included in the target project's build.
   - [docs/iCUESDK_4.0.84/iCUESDK/lib/x64/iCUESDK.x64_2019.lib](docs/iCUESDK_4.0.84/iCUESDK/lib/x64/iCUESDK.x64_2019.lib)
   - [docs/iCUESDK_4.0.84/iCUESDK/redist/x64/iCUESDK.x64_2019.dll](docs/iCUESDK_4.0.84/iCUESDK/redist/x64/iCUESDK.x64_2019.dll)
3. iCUE integration source code
   - Refer to the files in [docs/iCUESDK_4.0.84/iCUESDK/include/iCUESDK](docs/iCUESDK_4.0.84/iCUESDK/include/iCUESDK).
4. Flutter template project for native integrations
   - Refer to the [docs/native_add](docs/native_add) package as an initial reference for integrating Flutter with native code.

## 6. Critical Agent Instructions and Rules
1. **Never** use shell commands (`sed`, `perl`, `python`, `rm -rf`) to edit source files directly. Always use the IDE's native file-editing tools (`write_file`, `replace_file_content`, etc.).
2. Strictly follow the architecture and conventions already established in the project.
3. Ensure all changes compile without errors and pass the existing tests.
4. Keep the code clean, add clear comments when needed, and avoid dead code.
5. Always use the `Local Reference Materials` as the primary source of truth.
6. Never use magic numbers. Always use the constants defined by the library.
7. In widgets, whenever an error is returned, preserve the complete error `print` to make the stack trace easier to inspect.
8. Folders and files in `docs` should not be referenced in [README.md](README.md)`
