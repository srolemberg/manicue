# Instruções para Agentes

Agente de criação e manutenção do projeto que visa realizar a integração entre Flutter e iCUE. através do SDK nativo fornecido.

---

## 1. Visão Geral do Projeto
- **Nome do Projeto:** manicue
- **Tecnologia Principal:** Flutter / Dart
- **Plataformas Suportadas:** Desktop (Windows, macOS, Linux)

---

## 2. Arquitetura e Estrutura de Pastas
Arquitetura do projeo ainda será definida.

---

## 3. Padrões de Código e Convenções (Coding Standards)
- **Linguagem:** Dart (sigam o Effective Dart)
- **Gerenciamento de Estado:** setState
- **Tratamento de Erros:** Utilizar `Result<T, Exception>`.
- **Nomenclatura:**
    - Classes em `UpperCamelCase` (ex: `UserProfileScreen`)
    - Variáveis e funções em `lowerCamelCase` (ex: `fetchUserData`)
    - Arquivos em `snake_case` (ex: `user_profile_screen.dart`)

---

## 4. Testes
- **Testes Unitários:** Localizados em `test/` espelhando a estrutura de `lib/`.
- **Testes de Widget / UI:** Utilizar `testWidgets` para validar componentes visuais.
- **Execução:**
  ```bash
  flutter test
  ```

---

## 6. Base de Consulta de informação local
Observe sempre o que está definido na documentação para os cenários abaixo:

1. Para consulta de referência ao iCUE
   - [docs/iocue-sdk.md](docs/iocue-sdk.md)
     - Documentação da api em C do iCUE
   - [docs/docs.flutter.devplatform-integration.bind-native-code.md](docs/docs.flutter.devplatform-integration.bind-native-code.md)
     - Documentação da integração do Flutter com código nativo
2. Binários de integração do iCUE
   - [docs/iCUESDK_4.0.84/iCUESDK/lib/x64/iCUESDK.x64_2019.lib](docs/iCUESDK_4.0.84/iCUESDK/lib/x64/iCUESDK.x64_2019.lib)
   - [docs/iCUESDK_4.0.84/iCUESDK/redist/x64/iCUESDK.x64_2019.dll](docs/iCUESDK_4.0.84/iCUESDK/redist/x64/iCUESDK.x64_2019.dll)
3. Código fonte da integração do iCUE
Observar os arquivos em: [docs/iCUESDK_4.0.84/iCUESDK/include/iCUESDK](docs/iCUESDK_4.0.84/iCUESDK/include/iCUESDK)

## 5. Instruções e Regras Críticas para o Agente
1. **Nunca** utilize comandos de shell (`sed`, `perl`, `python`, `rm -rf`) para editar arquivos de código diretamente. Utilize sempre as ferramentas nativas de manipulação de arquivos do IDE (`write_file`, `replace_file_content`, etc.).
2. Siga rigorosamente a arquitetura e os padrões existentes no projeto.
3. Garanta que todas as alterações compilem sem erros e passem nos testes existentes.
4. Mantenha o código limpo, documentado com comentários claros quando necessário e sem código morto.
5. Sempre utilize a `Base de Consulta de informação local` como fonte primária da verdade.
