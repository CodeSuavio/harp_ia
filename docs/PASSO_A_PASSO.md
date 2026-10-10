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

---

## Onde fica cada coisa

```
app/
  controllers/   uma por recurso; páginas públicas pulam o login
  models/        entidades e associações (+ BrazilMap)
  policies/      regras do Pundit
  services/      cálculos e integrações (IA, métricas, comparações, importação)
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
bin/rails test
bin/dev
```

Variáveis no `.env`: `OPENAI_API_KEY` (chat) e `CLOUDINARY_URL` (fotos).
