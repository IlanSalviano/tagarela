# tagarela

Codinome do projeto. Nome final do produto será definido depois.

**O que é:** clone do Wispr Flow para uso individual. Aplicativo macOS nativo de ditado por voz, com pós-processamento por LLM (Ollama local, OpenAI API, ou sem LLM). Foco em português com regionalização.

**Onde fica a documentação:** `/Users/tars/Dev/tagarela/tagarela_docs` (vault Obsidian).

---

## Regras invioláveis

Estas regras valem para qualquer agente (humano ou IA) trabalhando neste repositório.

### 1. Nada é feito sem antes ler a documentação

Antes de qualquer ação não-trivial — propor design, escrever código, mexer em arquitetura, instalar dependência, mudar fluxo — **leia primeiro o que já está escrito** em `tagarela_docs/`.

Comece sempre pelo `tagarela_docs/README.md` (índice do vault). De lá, navegue para o que for relevante à tarefa.

Se a documentação está incompleta ou ambígua para a tarefa em mãos: **pare e pergunte**, ou escreva/atualize o doc primeiro. Nunca prossiga adivinhando.

### 2. Nada é marcado como pronto sem antes atualizar a documentação

"Pronto" significa: código funciona **E** o doc reflete a realidade.

Antes de declarar uma tarefa concluída, abrir PR, ou dizer "está feito":

1. Atualize o(s) doc(s) afetado(s) em `tagarela_docs/`.
2. Se uma decisão de design foi tomada, registre-a (ADR ou nota equivalente).
3. Se uma funcionalidade foi adicionada/mudada/removida, atualize a descrição dela.
4. Commit do código e do doc juntos (ou doc primeiro).

Se você terminou o código mas ainda não atualizou o doc: **não está pronto**.

### 3. Documentação é a fonte da verdade

Quando código e doc divergem, o doc descreve o que **deveria** ser. Reconciliar é parte do trabalho:

- Doc certo, código errado → corrija o código.
- Código certo, doc errado → atualize o doc (e investigue por que divergiu).
- Ambos errados → escreva o doc primeiro, depois ajuste o código.

### 4. Idioma

Documentação e UI: **português brasileiro**. Código (identificadores, comentários técnicos): inglês. Mensagens ao usuário: português, com atenção a regionalismos.

---

## Estrutura mínima do vault

```
tagarela_docs/
├── README.md              # índice e ponto de entrada (Obsidian home note)
├── 00-visao/              # visão, objetivos, escopo
├── 01-pesquisa/           # análise do Wispr Flow e referências
├── 02-arquitetura/        # decisões arquiteturais, stack, diagramas
├── 03-funcionalidades/    # spec por funcionalidade
├── 04-decisoes/           # ADRs (decisões com contexto e alternativas)
└── specs/                 # specs de design vindas do fluxo de brainstorming
```

Pastas são criadas conforme necessário. Não precisa estar tudo lá no dia 1.

---

## Para o agente Claude especificamente

- Antes de qualquer skill de implementação, leia `tagarela_docs/README.md`.
- Use o skill `superpowers:brainstorming` para qualquer trabalho criativo novo. O spec resultante vai em `tagarela_docs/specs/`.
- Use o skill `superpowers:writing-plans` antes de implementar. O plano vai em `tagarela_docs/specs/` junto do design correspondente.
- Não crie arquivos `.md` fora de `tagarela_docs/` exceto este `CLAUDE.md` e `README.md` na raiz do projeto.
