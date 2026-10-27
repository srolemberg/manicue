# Template de Instruções para Agentes (AGENTS.md)

Este documento serve como um template padrão para configurar as diretrizes, contexto e regras para agentes de IA operarem neste repositório Flutter (`manicue`).

---

## 1. Visão Geral do Projeto
- **Nome do Projeto:** manicue
- **Tecnologia Principal:** Flutter / Dart
- **Plataformas Suportadas:** Android, iOS, Web, Desktop (Windows, macOS, Linux)

---

## 2. Arquitetura e Estrutura de Pastas
Descreva aqui a arquitetura utilizada no projeto (ex: Clean Architecture, BLoC, Provider, MVC):
```text
lib/
├── core/          # Utilitários, constantes, temas, injeção de dependência
├── data/          # Fontes de dados, modelos, repositórios (implementações)
├── domain/        # Entidades, casos de uso, contratos de repositório
└── presentation/  # Telas (Views), widgets reutilizáveis e ViewModels/Blocs
```

---

## 3. Padrões de Código e Convenções (Coding Standards)
- **Linguagem:** Dart (sigam o Effective Dart)
- **Gerenciamento de Estado:** [Definir padrão, ex: Riverpod, BLoC, Provider, setState]
- **Tratamento de Erros:** Utilizar `Result<T, Exception>` ou Bloc/State com estados de erro claros.
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

## 5. Instruções e Regras Críticas para o Agente
1. **Nunca** utilize comandos de shell (`sed`, `perl`, `python`, `rm -rf`) para editar arquivos de código diretamente. Utilize sempre as ferramentas nativas de manipulação de arquivos do IDE (`write_file`, `replace_file_content`, etc.).
2. Siga rigorosamente a arquitetura e os padrões existentes no projeto.
3. Garanta que todas as alterações compilem sem erros e passem nos testes existentes.
4. Mantenha o código limpo, documentado com comentários claros quando necessário e sem código morto.
