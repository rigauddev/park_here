# Instruções de Uso do Chat para o Projeto ParkHere

Este documento serve como referência rápida para lembrar como interagir com o assistente de IA durante o desenvolvimento do **ParkHere**. Ele deve permanecer no repositório e pode ser aberto a qualquer momento para consulta.

---

## 1. Como fazer solicitações ao assistente
- **Envolva sua solicitação entre tags `<USER_REQUEST>`** (ou `<USER_REQUEST>` já reconhecido). Exemplo:
  ```
  <USER_REQUEST>
  Preciso corrigir o arquivo convenience_pos_page.dart
  </USER_REQUEST>
  ```
- Seja **claro e específico** sobre o que precisa: nome do arquivo, linha aproximada, comportamento desejado, restrições.
- Quando quiser que o assistente **gere código**, inclua a assinatura exata do método ou o trecho que deve ser alterado.

## 2. Estrutura de respostas do assistente
- O assistente sempre **retorna texto** ou **chamadas de ferramentas** (ex.: `read_file`, `edit_file`, `write_file`).
- Caso o assistente precise de mais informações, ele fará perguntas usando a ferramenta `ask_question`.
- Se houver erro de execução, o assistente deverá **relatar o erro** e propor correção.

## 3. Boas práticas de desenvolvimento no projeto
- **Mantenha a consistência de estilo**: camelCase para variáveis Flutter, snake_case para código Python.
- **Não desative módulos existentes** (ex.: estacionamento). Crie novos módulos de forma isolada.
- Sempre **atualize a documentação** (`docs/api-contracts.md`, `docs/features.md`, etc.) ao alterar endpoints ou fluxos.
- **Não versionar** diretórios gerados (`build/`, `__pycache__/`, `.dart_tool/`).
- Use **branches** com nomes descritivos, ex.: `feature/rental-module-backend`.

## 4. Fluxo típico de correção ou implementação
1. **Abrir o arquivo** (ex.: `read_file`).
2. **Identificar a linha/problem**.
3. **Usar `edit_file` ou `write_file`** para aplicar a mudança, sempre passando o **Target** exato para `edit_file`.
4. **Compilar/rodar** (`run_command`) para garantir que não há erros.
5. **Commitar** e **push** a branch.

## 5. Como solicitar criação de artefatos
- Use a ferramenta `write_file` apontando para o caminho desejado dentro do repositório.
- Para gerar documentos de análise ou relatórios, use a pasta `artifact` automática (`/Users/luisrigaud/.gemini/antigravity/brain/<conversation-id>/`).

## 6. Perguntas frequentes
- **_“Como faço para gerar a UI do drawer com o novo módulo?”_** – Crie/edite o widget do drawer e adicione a lógica de verificação de `serviceModules`.
- **_“Preciso de um logo SVG?”_** – Salve o SVG na pasta `assets/images/` e registre-o no `pubspec.yaml`.
- **_“Quais são as regras de trabalho?”_** – Consulte o arquivo `AGENTS.md` que contém políticas de anti‑duplicação, validação de fluxo e atualização de seeds.

---

**Uso rápido:**
```bash
# Exemplo de abrir este arquivo no VS Code
code CHAT_INSTRUCTIONS.md
```

Mantendo este arquivo atualizado, você garante que toda a equipe (e o assistente) tenha acesso a diretrizes claras e consistentes.

