# Harp_IA — passo a passo do que foi feito

Este documento conta, em ordem, como o código do Harp_IA foi construído: do
template inicial até a página de comparação de partidos (PR #110, 08/10/2026).
A ordem segue o histórico do git (`git log --reverse`); os números entre
parênteses são os pull requests.

O Harp_IA é uma plataforma de informação política: reúne dados de deputados
federais, partidos, candidatos de 2026, projetos de lei, votações e gastos da
cota parlamentar, e tem um assistente de IA (a "Harpia") que responde
perguntas sobre esses dados.

---

## Visão geral da stack

| Camada | Tecnologia |
| --- | --- |
| Framework | Ruby on Rails 8.1 (template do Le Wagon) |
| Banco | PostgreSQL |
| Front-end | Bootstrap 5, SCSS, Hotwire (Turbo + Stimulus), importmap |
| Login | Devise (com nome e sobrenome) |
| Autorização | Pundit |
| IA | gem `ruby_llm` com a API da OpenAI (`OPENAI_API_KEY`) |
| Imagens | Active Storage + Cloudinary |
| Infra Rails 8 | Solid Queue, Solid Cache, Solid Cable |
| Deploy | Heroku (`DATABASE_URL`), Dockerfile/Kamal do template |

---

## Etapa 1 — Fundação do projeto (19/09)

1. **Template inicial.** O app foi gerado com o template `devise` do Le Wagon,
   que já traz Devise, Bootstrap, Simple Form e Font Awesome.
2. **Rotas e controllers.** Criados os controllers públicos só com `index` e
   `show` (deputados, partidos, candidatos, projetos, votações, despesas) e
   views com títulos provisórios (#18, #22).
3. **Models e migrations** (#21). As entidades principais:
   - `Party` (partido) → tem muitos `Deputy` e `Candidate`
   - `Deputy` (deputado) → tem `Expense` (gastos), `Vote` (votos) e `Bill` (projetos)
   - `Poll` (votação) → tem muitos `Vote`
   - `User` → tem muitos `Chat` → tem muitas `Message`
4. **Validações** (#23) e `dependent: :destroy` nas associações (#25), para
   não deixar registros órfãos.
5. **Configuração de Heroku e Cloudinary**, e o `.env` para as chaves.
6. **Pundit** (#28): toda ação passa por uma policy. O `ApplicationController`
   exige `authorize` em cada ação e `policy_scope` nos `index`. As policies
   públicas (`DeputyPolicy`, `PartyPolicy` etc.) liberam `show?` para todos;
   a `ChatPolicy` só deixa o dono ver e apagar o próprio chat.
7. **Estrutura do chat** (#26): models `Chat` e `Message` (com `role` `user`
   ou `assistant`), rotas aninhadas `chats/:id/messages` e a primeira view.

## Etapa 2 — Telas, dados e IA (22/09 a 26/09)

1. **Devise com nome e sobrenome** (#35): `first_name` e `last_name` liberados
   em `configure_permitted_parameters`.
2. **Homepage** com busca de candidatos e filtro por estado (#50); depois a
   paleta de cores, o mapa do Brasil, o hero e o footer (#53, #54).
3. **Primeira integração com IA** (#49): a pergunta do usuário vai para a LLM
   e a resposta é salva como mensagem.
4. **Seeds.** O `db/seeds.rb` baixa os dados de um repositório público
   (`gabsgarcia/harpia-seed-data`): partidos, deputados, candidatos 2026,
   proposições, despesas, votações e votos. Ajustes ao longo do caminho:
   - o seed passou a atualizar em vez de apagar (`1d007b6`);
   - cópias comprimidas (`db/seed_data/*.json.gz`) foram versionadas (`0526e7c`).
5. **Filtros, ordenação e paginação** nas listas de candidatos, deputados e
   partidos (`a3bc563`), usando Turbo Frames para trocar só a lista. Os links
   dos cards saem do frame para abrir a página inteira (`65a7834`).
6. **Telas do Devise** estilizadas: cadastro, login, senha e e-mail (#62).
7. **Páginas institucionais** (#63): Sobre (com a equipe puxada da API do
   GitHub pelo `github_team_controller.js`) e Contato.

## Etapa 3 — O chatbot (26/09 a 08/10)

O fluxo do chat ficou assim:

```
Usuário envia pergunta
  → MessagesController#create (ou ChatsController#create no widget)
    → MessageProcessorService
        1. salva a mensagem do usuário
        2. ChatbotService#call  → envia histórico + pergunta à LLM
        3. salva a resposta como mensagem "assistant"
        4. na primeira interação, ChatbotService#generate_title dá nome ao chat
  → resposta em HTML (página do chat) ou Turbo Stream (widget)
```

Passos:

1. **`ChatbotService`** (#64): define o *system prompt* (neutralidade política,
   não recomendar voto, não inventar dados, respostas curtas em português) e
   reenvia as mensagens anteriores para a IA ter contexto.
2. **Histórico de chats por usuário** (#66): página "Meus chats", cada um vê
   só os seus (`policy_scope` + `current_user.chats.find`).
3. **Layout do chat** (#72) e **widget flutuante** "Estamos de Olho" (#73),
   controlado por `chat_widget_controller.js`.
4. **Conversa pelo widget sem trocar de página** (#85): os controllers
   respondem com `turbo_stream`, atualizando `chat_widget_messages` e a lista
   de chats. Nessa etapa foram instalados Solid Queue e Action Cable.
5. **Indicador de carregamento** (#91), **estado de login no widget** (#98) e
   **bloqueio de envio duplicado** (#108).

## Etapa 4 — Painéis de deputados e candidatos (01/10 a 06/10)

1. **Correções no seed** (#74, #75) e filtro de partidos na home (#76).
2. **Produção usa `DATABASE_URL`** para todos os bancos (principal, cache,
   fila e cable) (`8fc8c6a`).
3. **Página de deputados com dashboard** (#46, #82). Para não espalhar
   cálculo nas views, foram criados objetos dedicados:
   - `DeputyMetrics` (`app/services/deputy_metrics.rb`): indicadores de
     **todos** os deputados de uma vez, com cache — gasto mensal, ranking,
     uso da cota CEAP por UF, participação nas votações (contando só o
     período em que o deputado estava em exercício), alinhamento e coesão.
   - `DeputyStats`: indicadores de **um** deputado — comparação com a média
     do estado e do partido, variação ano a ano, gasto por tipo e
     concentração em um fornecedor (alerta acima de 50%).
   - `DeputyOverview` e `DirectoryMetrics` (`app/queries/`): consultas para
     a página e para a listagem.
   - A página tem abas: visão geral, gastos, projetos, votações,
     promessas × atuação e eleições 2026.
4. **Comparação de deputados** lado a lado (até 3), com `DeputyComparison`
   destacando o melhor e o pior em cada linha e `deputy_compare_controller.js`
   para a seleção (#82, #105).
5. **Fotos no Cloudinary** (#83): o seed sobe as fotos em paralelo, com
   threads e o pool de conexões, pulando as que falham.
6. **Perfil do candidato** no visual da home, usando as mesmas métricas do
   painel do deputado quando o candidato é deputado atual, e botão
   "Perguntar à Harpia" (#106 e commits de 06/10).

## Etapa 5 — Votações, projetos e cruzamento de dados (06/10 a 08/10)

1. **Votações** (#94): listagem com filtros e página com o voto de cada
   partido. `PollBreakdown` (`app/queries/poll_breakdown.rb`) calcula o
   placar, a unanimidade, a coesão de cada partido e os dissidentes.
2. **Coesão partidária** e seed completo com fotos (#93).
3. **Projetos de lei** (#95): listagem com filtros por ano, tema e partido,
   e página de cada proposição (PL, PDL, PRC, PEC).
4. **Temas.** `ThemeClassifier` classifica projetos e votações em temas
   (saúde, educação…) por palavras-chave. As votações herdam o tema do
   projeto votado. A tela avisa que a classificação é automática.
   Comando: `bin/rails harpia:themes`.
5. **Promessas.** `ProposalImporter` importa propostas de campanha/programa
   de partido a partir de JSON e as liga às votações; `DeputyThemeProfile`
   mede a coerência entre o que foi prometido e como o deputado votou.
   Comando: `bin/rails "harpia:proposals[arquivo.json]"`.
6. **Rake tasks de dados** (`lib/tasks/`), que buscam na API de Dados
   Abertos da Câmara:
   - `partidos:tse` — número, registro, siglas antigas e partidos extintos (#96)
   - `partidos:camara` — logo, líder e bancada na posse
   - `partidos:orientacoes` — orientação de voto das lideranças em cada votação
   - `proposicoes:cruzar` — número oficial, coautores e ligação
     votação ↔ projeto (#97, #99)

## Etapa 6 — Partidos (08/10)

1. **Mapa do Brasil com bancadas por estado** (#107). `BrazilMap` guarda os
   contornos do IBGE como SVG; `party_map_controller.js` desenha e trata o
   clique. Correção relevante: um getter chamado `data` sobrescrevia o
   `this.data` do Stimulus (`9951a42`).
2. **Página do partido** (#109) com abas e `PartyStats`: bancada por UF,
   gastos, coesão, afinidade com outras bancadas, deputados que mais votam
   contra o partido, projetos, temas e candidaturas de 2026.
3. **Comparação de partidos** (#110) com `PartyComparison`: governismo
   (quanto a bancada segue a orientação do Governo) × coesão, divisão em
   blocos, indicadores lado a lado, afinidade e frases de destaque geradas a
   partir dos números (ex.: cota de gênero de 30% nas candidaturas).

## Etapa 7 — Alertas de gastos com atividade do fornecedor (12/10)

A base da Câmara não traz os itens da nota fiscal, então não dá para saber
*o que* foi comprado. O que dá para cruzar é o **tipo de despesa** com a
**atividade econômica (CNAE) da empresa** na Receita Federal.

1. **Cache de fornecedores.** `Supplier` guarda, por CNPJ (só dígitos), o
   CNAE principal, os secundários e a situação cadastral (com a data).
   `Suppliers::CnpjLookup` consulta `brasilapi.com.br/api/cnpj/v1/{cnpj}`
   com timeout; erros ficam em `fetch_error` em vez de levantar exceção.
   404/400 só voltam a ser consultados depois de 90 dias; 429, 5xx e falhas
   de rede ficam sem `fetched_at` e entram na rodada seguinte.
   `Suppliers::FetchJob` (Solid Queue) percorre os CNPJs das despesas sem
   cadastro ou com mais de 90 dias, com pausa de 1,5 s entre chamadas (60 s
   depois de um 429), em lotes de 200 que se reenfileiram: nenhum lote prende
   uma thread por horas, e um deploy no meio só interrompe um lote. Um CNPJ que
   falhou não é tentado de novo na mesma rodada. CPFs, notas sem documento,
   passagens aéreas e CNPJs com dígito verificador errado ficam de fora.
   Comando: `bin/rails "harpia:suppliers[100]"` (limite opcional, roda na hora).
2. **Duas regras novas em `ExpenseAnomalies`**, no mesmo formato das outras
   (o chat usa sem mudança):
   - `incompatible_supplier_activity`: nenhuma atividade da empresa
     (principal **ou** secundária) está na lista de CNAEs compatíveis com o
     tipo de despesa (`ExpenseAnomalies::ACTIVITY_RULES`, por divisão ou
     grupo, ex.: combustíveis → 47.3, 46.8). Tipos sem regra não geram
     alerta. Gravidade alta quando o deputado pagou ao menos R$ 5.000 ao
     fornecedor no ano; abaixo disso, média.
   - `inactive_supplier` (alta): nota emitida quando o CNPJ já não estava
     ATIVO (baixado, inapto, suspenso).
3. **Alertas gravados para o ranking.** `ExpenseAlert` (tabela
   `expense_alerts`) guarda os alertas por deputado e ano;
   `ExpenseAlerts::RefreshJob(year)` recalcula todos (≈20 s para a Câmara
   inteira) e troca os de cada deputado numa transação. Roda no fim do
   `Suppliers::FetchJob` (se algo foi consultado), na carga das despesas
   (`db/seeds.rb`), todo dia às 5h UTC e com `bin/rails harpia:expense_alerts`.
   Em produção, `config/recurring.yml` também agenda o `FetchJob` aos domingos
   (3h UTC). Esses agendamentos só rodam em produção a partir da Etapa 8, que
   liga o Solid Queue no Heroku (fila `maintenance`).
   A aba Gastos continua calculando os alertas na hora.
4. **Ranking em `/alertas`** (público): pontuação ponderada (alta = 5,
   média = 2, baixa = 1) calculada em SQL, desempate pelo valor sinalizado,
   filtros de ano, UF, partido e gravidade mínima. Também ordena pela parte do
   gasto do ano em notas com alerta (cada nota conta uma vez), para comparar
   deputados com volumes de gasto diferentes. Mostra a data do cálculo e avisa
   quando o ano ainda não foi calculado. Link na navbar e atalho
   na listagem de deputados. O aviso no topo deixa claro que alerta não é
   prova de irregularidade.
5. **Aba Gastos do deputado**: filtro "Só notas com alerta" (`alerts=1`) e
   de período (`from`/`to`); cada nota marcada mostra o título e o critério
   dos alertas e a atividade do fornecedor; CNPJ formatado e link "Ver nota
   na Câmara".

## Etapa 8 — Respostas assíncronas da Harpia e jobs no Heroku (12/10)

Até aqui a resposta da IA era gerada dentro da requisição: o usuário esperava
tudo terminar (várias chamadas às ferramentas, depois o título) e uma thread
do Puma ficava presa o tempo todo. E, no Heroku, nenhum job rodava: o
template prevê o Solid Queue dentro do Puma pela variável
`SOLID_QUEUE_IN_PUMA`, definida no `config/deploy.yml` do Kamal, mas o
Heroku não lê esse arquivo e a variável nunca foi definida.

### Fluxo do chat

```
Usuário envia pergunta
  → MessagesController#create (ou ChatsController#create no widget)
    → MessageProcessorService
        1. salva a pergunta com status "pending"
        2. enfileira ChatResponseJob (fila harpia)
  → resposta imediata: pergunta + "Estamos de olho...", formulário bloqueado
ChatResponseJob (em segundo plano)
  → ChatbotService#call → salva a resposta → pergunta "answered" (ou "failed")
  → envia a conversa pelo WebSocket (turbo_stream_from) às telas abertas
  → gera o título depois que a resposta já está na tela
```

1. **`Message#status`** (`pending`, `answered`, `failed`): a falha fica
   registrada junto à pergunta. Uma pergunta pendente há mais de 2 minutos
   (`Message::RESPONSE_TIMEOUT`) aparece como falha e libera o formulário.
2. **WebSocket com Solid Cable.** Os alvos usam o `dom_id` da conversa, para
   uma conversa nunca aparecer na tela de outra. Só usuários logados abrem
   conexão (`ApplicationCable::Connection`).
3. **Respostas que não chegam pelo WebSocket.** Quando a conversa aparece
   pendente, o `chat_controller.js` confere o estado na hora
   (`ChatsController#show` em Turbo Stream) e depois a cada 10 s; enquanto a
   Harpia responde, o servidor devolve 204 e nada muda na tela. Isso cobre a
   resposta transmitida antes de a tela se inscrever no canal e as quedas de
   conexão. A rolagem da conversa é preservada entre as atualizações.
4. **Sem nova tentativa automática** no `ChatResponseJob`: repetir a chamada
   poderia duplicar a resposta e o custo da IA.

### Jobs no Heroku

O `Procfile` define os dois processos do deploy:

```
release: bin/rails db:migrate
web: SOLID_QUEUE_IN_PUMA=true bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
```

- **`release`:** a cada deploy, o Heroku roda as migrations antes de liberar a
  versão nova. Se uma migration falhar, o deploy é cancelado e a versão
  anterior continua no ar. Antes, as migrations eram rodadas à mão.
- **`web`:** o mesmo comando que o Heroku usava, mais `SOLID_QUEUE_IN_PUMA`,
  que liga o Solid Queue dentro do Puma em modo `async` (`config/puma.rb`):
  threads no próprio processo, sem dyno extra. No dyno Basic (512 MB), o modo
  padrão (`fork`) foi de 208 MB para 430 MB; o `async`, 229 MB.
- A tabela `solid_cable_messages` é criada por migration: em produção o banco
  `cable` usa o mesmo `DATABASE_URL` do principal.

### Filas em produção

Só duas filas têm worker (`config/queue.yml`), cada uma com threads próprias:

| Fila | Jobs | Worker |
| --- | --- | --- |
| `harpia` | `ChatResponseJob` | 2 threads, consulta a fila a cada 0,1 s |
| `maintenance` | `Suppliers::FetchJob`, `ExpenseAlerts::RefreshJob`, tarefas do `config/recurring.yml` e o padrão do `ApplicationJob` | 1 thread |
| `default` | jobs antigos do Active Storage | **nenhum** (fila pausada) |

O dispatcher e o scheduler também rodam, então as tarefas agendadas
(fornecedores aos domingos às 3h UTC, alertas todo dia às 5h UTC e limpeza
dos jobs concluídos a cada hora) passam a rodar sozinhas em produção, sempre
na fila `maintenance`. As rotinas nunca ocupam as threads da Harpia. Elas
continuam dividindo com o site a CPU, a memória e o banco do mesmo dyno.

O pool de conexões de produção tem 8 conexões (`config/database.yml`): 3
threads do Puma + 2 da `harpia` + 1 da `maintenance` + folga para o WebSocket.

### A fila `default` não é processada

Em 12/10 a fila `default` de produção tinha **9.322 jobs parados desde 03/10**,
gerados pelo Active Storage na importação das fotos (`db/seeds.rb`) e nunca
executados, porque nenhum job rodava no Heroku:

- 8.808 `ActiveStorage::AnalyzeJob`: leriam as dimensões de cada foto no
  Cloudinary (metadado que o site não usa);
- 514 `ActiveStorage::PurgeJob`: **apagariam do Cloudinary, sem volta**, 514
  fotos sem anexo, criadas em 03/10 numa reimportação. Nenhuma tem a chave de
  uma foto em uso.

A decisão é deixá-los exatamente como estão: enfileirados, sem execução, sem
exclusão e sem alteração. Para isso:

1. **Nenhum worker lê a `default` nem usa `"*"`** em `config/queue.yml`.
2. **A fila `default` é pausada em produção**, uma vez, antes do primeiro
   deploy com jobs. A pausa grava uma linha em `solid_queue_pauses` e não toca
   nos jobs. Ela exclui a fila até de um worker configurado com `"*"`:

   ```bash
   heroku run -a harp-ia "rails runner 'SolidQueue::Queue.find_by_name(\"default\").pause'"
   ```

   Para desfazer: `SolidQueue::Queue.find_by_name("default").resume`.
3. **`test/jobs/queue_configuration_test.rb`** falha se um job do projeto ou
   uma tarefa agendada for para uma fila sem worker, ou se um worker passar a
   ler `"*"` ou `default`.

Novas fotos anexadas em produção continuam gerando `AnalyzeJob` e `PurgeJob`
na `default`, que também ficam parados (o mesmo de antes).

**Nunca** rode, na fila `default`, `SolidQueue::Queue#clear` (descarta todos
os jobs prontos), `discard` ou `perform_now` dos jobs parados, nem remova a
pausa sem decidir antes o que fazer com os 514 `PurgeJob`.

### Regras para jobs novos

- Jobs do projeto herdam a fila `maintenance` do `ApplicationJob`. Use
  `queue_as :harpia` só para respostas do chat.
- **Não use `queue_as :default`:** em produção, o job ficaria parado para sempre.
- Tarefas com `command:` no `config/recurring.yml` precisam de
  `queue: maintenance`; sem isso, vão para a fila `solid_queue_recurring`, que
  não tem worker.
- Uma fila nova só é processada se ganhar um worker em `config/queue.yml`.

### Verificação depois de um deploy

Antes do deploy, guarde a foto da fila `default`; depois, compare. Todos os
números devem ser iguais (jobs com `id` maior que o máximo anterior são fotos
novas, também paradas):

```ruby
d = SolidQueue::Job.where(queue_name: "default")
puts d.group(:class_name).count, d.where(finished_at: nil).count, d.maximum(:id), d.sum(:id)
puts SolidQueue::ReadyExecution.where(queue_name: "default").count
puts SolidQueue::ClaimedExecution.count, SolidQueue::FailedExecution.count
puts ActiveStorage::Blob.left_joins(:attachments).where(active_storage_attachments: { id: nil }).count
```

Depois do deploy, confira também:

- **Logs** (`heroku logs -a harp-ia --source app | grep SolidQueue`):
  `Started Dispatcher`, `Started Scheduler` e dois `Started Worker`, com
  `queues: "harpia"` e `queues: "maintenance"`; nenhum com `*` ou `default`.
- `SolidQueue::Queue.find_by_name("default").paused?` → `true`.
- `SolidQueue::RecurringTask.pluck(:key, :queue_name)` → as três tarefas na
  `maintenance`.
- Uma pergunta à Harpia recebe resposta.
- No dia seguinte: execuções em `SolidQueue::RecurringExecution` e
  `ExpenseAlert.count` maior que zero.

---

## Onde fica cada coisa

```
app/
  controllers/   uma por recurso; páginas públicas pulam o login
  models/        entidades e associações (+ BrazilMap)
  policies/      regras do Pundit
  services/      cálculos e integrações (IA, métricas, comparações, importação, CNPJ)
  jobs/          Solid Queue: resposta da Harpia (fila harpia), consulta de CNPJ
                 e recálculo dos alertas de gastos (fila maintenance)
  channels/      conexão do WebSocket (só usuários logados)
  queries/       consultas de leitura para as páginas
  helpers/       formatação (moeda, rótulos, painéis)
  views/painel/  componentes reaproveitados (cards, métricas, paginação, hero)
  javascript/controllers/  Stimulus (widget de chat, filtros, mapa, comparação)
db/
  seeds.rb       carga completa a partir do harpia-seed-data
  seed_data/     cópias comprimidas dos dados
lib/tasks/       rake tasks de enriquecimento dos dados
test/            testes de models, controllers e services
```

## Como rodar

```bash
bundle install
bin/rails db:create db:migrate
bin/rails db:seed            # baixa e importa todos os dados (demora)
bin/rails harpia:themes      # classifica temas
bin/rails proposicoes:cruzar partidos:tse partidos:camara partidos:orientacoes
bin/rails harpia:suppliers   # CNAE dos fornecedores (horas: 1 consulta por CNPJ)
bin/rails test
bin/dev
```

Variáveis no `.env`: `OPENAI_API_KEY` (chat) e `CLOUDINARY_URL` (fotos).

### Deploy no Heroku

O deploy roda as migrations (fase `release` do `Procfile`) e liga os jobs
dentro do Puma. Antes do **primeiro** deploy com jobs, pause a fila `default`
e guarde a foto dela (Etapa 8, "A fila `default` não é processada"); depois,
siga a "Verificação depois de um deploy".
