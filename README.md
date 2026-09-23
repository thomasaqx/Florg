# FLORG

Organizador financeiro pessoal com IA. Flutter no frontend, FastAPI no backend.

O projeto tem **Fase 1 (MVP)** fechada — autenticação, contas, lançamento de
transações (à mão ou importando a planilha do banco), categorização automática,
orçamento, metas e dashboard — e a **FLORA AI**, a assistente financeira, já
responde sobre os números do usuário. Open Finance vem depois (ver
[Roadmap](#roadmap)).

## Arquitetura

```
backend/            FastAPI + SQLAlchemy 2.0 + Alembic + PostgreSQL
  app/core/         configuração, segurança (bcrypt, JWT), erros e log
  app/db/           engine, sessão, seed de categorias
  app/modules/      um pacote por domínio: router / service / schemas / models
    ai/             FLORA: contexto financeiro, prompt, providers
lib/                Flutter
  src/data/         ApiClient, repositórios e controllers (ChangeNotifier)
  src/models/       modelos de domínio
  src/screens/      telas
  src/shared/       widgets reutilizáveis, gráficos e o chat
  src/core/         tema/tokens, formatadores e os cálculos (analytics.dart)
```

Os módulos do backend seguem sempre o mesmo formato: `router` recebe a
requisição, `service` tem a regra, `schemas` valida entrada e saída, `models`
mapeia a tabela. `imports` adiciona um `parser` porque ler planilha de banco é
um problema à parte.

O `router` não decide status HTTP: o `service` levanta um erro de domínio
(`app/core/errors.py`) e um handler único em `main.py` traduz para a resposta.
É o que mantém `404 Conta não encontrada` com a mesma cara venha ele de onde
vier — e o que impede "não existe" e "não é sua" de virarem respostas
diferentes.

O estado é injetado com `provider`, montado uma única vez em `FlorgBootstrap`
(`lib/main.dart`). Todos os repositórios compartilham o mesmo `ApiClient`, então
a URL base da API muda em um ponto só.

## Rodando o backend

Requer [uv](https://docs.astral.sh/uv/) e Docker (para o PostgreSQL).

```bash
cd backend
cp .env.example .env
```

Gere uma `SECRET_KEY` de verdade e coloque no `.env`:

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Suba tudo (API + banco + migrations):

```bash
cd backend && docker compose up --build
```

A API fica em `http://localhost:8000` e a documentação interativa em
`http://localhost:8000/docs`.

### Sem Docker

Com um PostgreSQL já rodando, ajuste `DATABASE_URL` para `localhost` e:

```bash
cd backend && uv sync && uv run alembic upgrade head && uv run uvicorn app.main:app --reload
```

### Testes do backend

Rodam em SQLite em memória — não precisam de Docker, de banco no ar nem de
`.env`:

```bash
cd backend && uv run pytest
```

### Testes do app

Não precisam de API no ar: os testes de widget injetam repositórios falsos em
`FlorgBootstrap` (ver `test/support/fakes.dart`).

```bash
flutter test
```

## Rodando o app

```bash
flutter pub get && flutter run
```

O app descobre a URL da API sozinho: `10.0.2.2:8000` no emulador Android
(onde `localhost` é a própria VM) e `127.0.0.1:8000` no resto. Para apontar
para outro host:

```bash
flutter run --dart-define=FLORG_API_BASE_URL=http://192.168.0.10:8000
```

### Quando o login não passa

A mensagem de erro diz em qual endereço a tentativa falhou. Leia a porta:

- **`8000`** e mesmo assim falhou → o backend não está no ar. Confira com
  `curl http://127.0.0.1:8000/health`, que deve responder `{"status":"ok"}`.
- **Outra porta** → `FLORG_API_BASE_URL` está errada. O engano mais comum é
  apontar para a porta em que o *app* é servido (`--web-port`, `8080` no
  `.claude/launch.json`) em vez da porta da *API*. Aí o app chama a si mesmo.

Em debug, a tela de login mostra embaixo para onde o app vai mandar o pedido,
e **de onde essa URL veio**:

```
API: http://127.0.0.1:8000 (padrão do app)
API: http://127.0.0.1:8080 (definida por --dart-define=FLORG_API_BASE_URL na compilação)
```

A segunda linha é a armadilha: `--dart-define` é lido **na compilação**.
Trocar a flag e apertar `r` ou `R` (hot reload / hot restart) **não** atualiza
o valor — o app segue com a URL antiga. Encerre o processo (`q`) e rode de
novo. Se a linha disser "definida por --dart-define" e você não passou flag
nenhuma, quem passou foi o atalho da sua IDE.
- **"E-mail ou senha inválidos"** → chegou no backend. O FLORG não semeia
  usuário nenhum; crie o seu pela tela "Criar conta" ou com
  `POST /auth/register`.

Celular físico ou outra máquina: `127.0.0.1` é o próprio dispositivo e nunca
vai achar o seu backend. Use o IP da máquina onde a API roda, e suba-a em
todas as interfaces:

```bash
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Importando extrato do banco

O caminho principal para pôr dados no app na Fase 1. A tela **Importar** aceita
`.xlsx` e `.csv` de até 5 MB.

O envio acontece em dois passos, e o primeiro não grava nada:

1. `POST /imports/preview` lê o arquivo e devolve as linhas que entendeu, quais
   colunas achou que são data / descrição / valor / tipo, e as linhas que não
   conseguiu ler e por quê.
2. Você confere na tela, desmarca o que não quiser e corrige as colunas se o
   palpite errou. `POST /imports/commit` grava só o que sobrou.

O que o parser resolve sozinho:

- Cabeçalho abaixo do logo e do resumo que os bancos põem no topo do arquivo
- `1.234,56` e `1,234.56`, com `R$`, com espaço, e `(1.234,56)` como negativo
- `dd/mm/aaaa`, `aaaa-mm-dd` e as variações com `-` e `.`
- CSV com `;` ou `,`, em UTF-8 ou Latin-1
- Coluna `Saldo` não é confundida com a coluna `Valor`
- Sem coluna de tipo, o sinal do valor decide: negativo é despesa

**Reimportar o mesmo arquivo não duplica lançamento.** Cada linha ganha uma
impressão digital de data + descrição + valor + tipo + ordem de repetição,
gravada em `transactions.external_reference`. A ordem de repetição é o que faz
dois cafés de R$ 5,00 no mesmo dia entrarem os dois, e o mesmo arquivo enviado
duas vezes não entrar nenhuma vez a mais.

O saldo da conta é atualizado uma vez por arquivo, não uma vez por linha.

## FLORA AI

A FLORA é a inteligência financeira do FLORG. Ela responde sobre o dinheiro de
quem perguntou — nunca com média de mercado, sempre com a conta já feita:

> **Quanto eu posso gastar essa semana?**
> Considerando o que entrou e o que já saiu em setembro de 2026, sobram
> R$ 5.045,80 até o fim do mês. Faltam 9 dias, então dá cerca de R$ 3.924,51
> por semana para gasto variável. Vale olhar Lazer: o teto do mês já foi
> passado.

### Como está montada

```
Flutter (FloraController)
   │  POST /ai/chat
   ▼
AIService ── FinancialContext (lê o banco uma vez, por usuário)
   │
   ├── MockAIProvider    responde offline, a partir do contexto
   └── ClaudeProvider    monta o prompt e chama a API da Anthropic
```

O `FinancialContext` (`app/modules/ai/context.py`) é o único lugar que lê o
banco para a IA: saldo, entradas e saídas do mês, gasto por categoria com a
variação contra o mês anterior, tetos, metas com quanto falta por mês,
cobranças recorrentes, maiores despesas e capacidade de aporte. Os dois
providers recebem exatamente os mesmos números, então trocar um pelo outro não
muda a conta — muda quem escreve a frase.

**Nada de sessão no servidor.** O app manda os últimos turnos junto com a
pergunta, limitados no cliente e validados no backend.

### Sem chave da Anthropic

É o estado padrão, e o chat funciona assim. O `MockAIProvider` classifica a
intenção da pergunta (`app/modules/ai/intents.py`) e monta a resposta a partir
do contexto. Quando não há dado suficiente, ele diz isso em vez de inventar:

> Ainda não tenho lançamentos para analisar. Assim que você importar o extrato
> do banco ou registrar algumas movimentações, eu consigo responder isso com os
> seus números de verdade.

A tela mostra um selo **Modo local** enquanto for esse o provider, para ninguém
confundir a resposta com a de um modelo.

### Ligando a FLORA no Claude

Um lugar só, no backend. Em `backend/.env`:

```bash
ANTHROPIC_API_KEY=sk-ant-...
```

E pronto: com `AI_PROVIDER=auto` (o padrão), a presença da chave já troca o
provider. A interface do chat não muda uma linha.

| Variável | Padrão | Para quê |
|----------|--------|----------|
| `AI_PROVIDER` | `auto` | `auto` usa o Claude se houver chave; `mock` força o offline; `claude` exige a chave e recusa subir sem ela |
| `ANTHROPIC_API_KEY` | vazio | a chave. Fica só no servidor |
| `ANTHROPIC_MODEL` | `claude-sonnet-5` | modelo usado |
| `ANTHROPIC_MAX_TOKENS` | `1024` | teto de tokens da resposta |
| `ANTHROPIC_TIMEOUT_SECONDS` | `30` | timeout da chamada |

Se a API da Anthropic cair, o `AIService` responde pelo provider offline e
marca a resposta como degradada, em vez de mostrar erro para quem perguntou.

O `GET /ai/context` devolve os mesmos números que a FLORA leu, para conferir de
onde veio cada valor de uma resposta.

## Segurança

Este é um app financeiro; alguns pontos não são negociáveis:

- Senhas são guardadas com **bcrypt**, nunca em texto puro
- O JWT é guardado no cofre do sistema operacional (Keychain / Keystore /
  DPAPI) via `flutter_secure_storage`, nunca em `SharedPreferences`
- Valores monetários usam `Numeric(12,2)` / `Decimal` no backend — **nunca**
  ponto flutuante
- Toda rota que recebe um id valida **dono**, não apenas existência
  (ver `backend/tests/test_isolation.py`)
- Segredos vivem em variáveis de ambiente. `backend/.env` está no `.gitignore`;
  apenas `.env.example` é versionado
- Em produção a API se recusa a subir com `SECRET_KEY` de exemplo ou menor
  que 32 bytes, e o CORS aceita apenas as origens declaradas em `CORS_ORIGINS`
- A chave da Anthropic vive **só no backend**. O app fala com `/ai/chat`; quem
  fala com `api.anthropic.com` é o servidor
- Erro inesperado devolve `500` com mensagem genérica; o traceback fica no log,
  não na resposta

## Roadmap

| Fase | Escopo | Status |
|------|--------|--------|
| 1 | MVP: auth, contas, transações, importação de planilha, categorias, dashboard | concluída |
| 2 | FLORA AI: chat sobre os próprios números, orçamento e metas no servidor | concluída (provider offline; Claude pronto para plugar) |
| 3 | Open Finance (BACEN): conexão de contas e sincronização de extratos | não iniciada |
| 4 | IA assessor de investimentos: comparativos de produtos | não iniciada |

Cada fase só começa depois que a anterior estiver validada.

Enquanto o Open Finance não chega, a importação de planilha é como o extrato
entra no app. As duas coisas gravam na mesma tabela e usam o mesmo
`external_reference` para não duplicar, então a Fase 2 entra como uma segunda
origem de dados, sem mexer no que já existe.

Metas (`/goals`) e tetos de gasto (`/budgets`) agora ficam no banco. Antes
viviam só na sessão do app: fechou, perdeu.

O motor de categorização já está atrás da interface `CategorizationStrategy`
(`backend/app/modules/categorization/engine.py`), hoje com regras por
palavra-chave. Trocar por um modelo de ML/LLM é mudar uma linha em
`get_categorization_strategy()`.
