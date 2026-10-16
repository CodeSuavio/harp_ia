# Harp IA

Plataforma para acompanhar a Câmara dos Deputados e as eleições de 2026: deputados, partidos, candidatos, votações, projetos de lei e gastos da cota parlamentar, com a Harpia, uma assistente de IA que responde perguntas sobre os dados.

Este README é o guia das funções por página: o que cada parte do código faz e por quê. Atualizado em 13/10/2026.

## Visão geral

Toda página do Harp IA segue o mesmo caminho: a rota escolhe o controller, o controller busca os dados (às vezes com ajuda de um service ou query) e a view desenha o HTML com helpers e partials. Este guia explica cada função nessa ordem. Para o histórico de como o código foi construído, veja `docs/PASSO_A_PASSO.md`.

O caminho de um pedido, passo a passo:

1. **Rota** (`config/routes.rb`): liga a URL a uma action. Ex.: `/deputies/5` → `DeputiesController#show`.
2. **`before_action :authenticate_user!`** (Devise, no `ApplicationController`): exige login em todas as páginas, menos onde o controller usa `skip_before_action`.
3. **Action do controller**: carrega os registros, aplica filtros e chama `authorize` (Pundit) para checar a permissão.
4. **Policy** (`app/policies`): diz quem pode ver o quê. `verify_authorized` e `verify_policy_scoped` dão erro se o controller esquecer de chamar `authorize` ou `policy_scope`.
5. **Service / Query** (`app/services`, `app/queries`): contas pesadas (estatísticas, comparações, gastos fora do padrão) ficam fora do controller.
6. **View + partials + helpers** (`app/views`, `app/helpers`): formatam números, datas e badges.
7. **Stimulus** (`app/javascript/controllers`): interações no navegador (filtros, mapa, chat).

| Pasta | O que guarda |
|---|---|
| `app/models` | Tabelas e as regras de cada uma (associações, validações, scopes) |
| `app/controllers` | Uma classe por recurso; cada método público é uma página |
| `app/policies` | Permissões do Pundit |
| `app/services`, `app/queries` | Cálculos e consultas reutilizáveis |
| `app/jobs` | Tarefas em segundo plano (Solid Queue): respostas da Harpia, consulta de CNPJ e recálculo dos alertas de gastos |
| `app/helpers` | Funções de formatação chamadas nas views |
| `app/views` | HTML (ERB); arquivos com `_` na frente são partials |
| `app/javascript/controllers` | Controllers Stimulus (JS) |
| `lib/tasks` | Tarefas `rake` de importação de dados |

O `ApplicationController` também tem `configure_permitted_parameters`, que libera `first_name` e `last_name` no cadastro e na edição de conta do Devise, e `skip_pundit?`, que dispensa o Pundit nas telas do Devise e no `PagesController`.

## Modelos

Cada modelo é uma tabela do banco. As linhas abaixo explicam por que cada declaração existe; as páginas da próxima seção usam essas associações e métodos.

### Deputy (deputado)

| Código | Por que está ali |
|---|---|
| `belongs_to :party` | Todo deputado pertence a um partido; permite `deputy.party`. |
| `has_many :expenses, :bills, :votes, :proposals` | Um deputado tem vários gastos, projetos, votos e propostas. `dependent: :destroy` apaga tudo junto se o deputado for apagado. |
| `has_many :bill_authors` | Tabela de ligação para os projetos em que ele é coautor. |
| `has_many :party_affiliations, -> { order(:started_on, :id) }` | Histórico de partidos do deputado, já em ordem de data. `dependent: :delete_all` apaga o histórico numa só consulta, sem carregar cada registro. |
| `has_many :candidates, foreign_key: :current_deputy_id, primary_key: :json_id` | Liga o deputado à candidatura de 2026. A ligação usa o `json_id` (id da Câmara), não o `id` do banco. |
| `has_one_attached :photo` | Tem uma foto ligada ao deputado (Active Storage + Cloudinary). Permite `deputy.photo.attached?`. |
| `validates :cpf, uniqueness, length: 11` | CPF obrigatório, único e com 11 dígitos. |
| `validates :json_id, uniqueness` | Evita importar o mesmo deputado duas vezes. |
| `scope :running_for_reelection` | Filtra os deputados que são candidatos à reeleição em 2026 (usa `Candidate.reelection`). |

### Party (partido)

| Código | Por que está ali |
|---|---|
| `MERGERS` | Lista fixa de partidos extintos por fusão ou incorporação (TSE) e quem os sucedeu. |
| `has_many :deputies, :candidates, :bills, :proposals` | Um partido tem vários deputados, candidatos, projetos e propostas. |
| `has_many :poll_orientations, dependent: :nullify` | Orientações de voto do partido; se o partido sumir, a orientação fica sem partido em vez de ser apagada. |
| `has_many :party_affiliations, dependent: :nullify` | Filiações de deputados ao partido; se o partido sumir, a filiação fica só com a sigla (`party_label`). |
| `validates :label, uniqueness: { case_sensitive: false }` | A sigla não pode repetir, nem com maiúsculas diferentes. |
| `absorbed` | Devolve os partidos que se fundiram a este (consulta `MERGERS`), do mais recente para o mais antigo. |
| `leader` | Busca o deputado líder pelo `leader_json_id`. |
| `self.logo_files` | Lista as imagens `logo-*` em `app/assets/images`. Em desenvolvimento relê a pasta toda vez; em produção guarda em memória (`@logo_files \|\|=`). |
| `self.logo_key` | Normaliza um texto para achar a logo: tira acento, põe minúsculo e remove símbolos ("União Brasil" → "uniaobrasil"). |
| `logo_file` | Nome do arquivo da logo, procurado pela sigla e depois pelo nome. |

### Candidate (candidato 2026)

| Código | Por que está ali |
|---|---|
| `belongs_to :party` | Todo candidato tem partido. |
| `belongs_to :current_deputy, optional: true` | Se o candidato já é deputado, aponta para ele (pelo `json_id`). `optional` porque a maioria não é. |
| `has_one_attached :photo` | Tem uma foto ligada ao candidato. |
| `scope :reelection` | Candidatos que já são deputados e não marcaram "não" para reeleição. |
| `self.search(term)` | Busca por nome, nome de urna ou sigla exata do partido, atual ou antiga (`former_labels`), para "PT" não trazer PTB ou PSTU. Sem texto, devolve `all`. Usada na lista de candidatos. |
| `reelection?` | O campo do TSE costuma vir vazio; nesse caso considera reeleição quem já é deputado. |

### PartyAffiliation (filiação partidária)

Cada linha diz em que partido um deputado estava a partir de uma data. É montada pelo service `PartyHistory` a partir do histórico da Câmara.

| Código | Por que está ali |
|---|---|
| `KINDS` | Tipos de mudança: `first` (primeiro registro na Câmara), `new_term` (outro partido ao voltar numa nova legislatura), `switch` (troca durante o mandato) e `rename` (o partido mudou de nome ou se fundiu). |
| `belongs_to :deputy` | Toda filiação é de um deputado. |
| `belongs_to :party, optional: true` | Liga ao partido quando ele existe no banco; partidos extintos ficam só com a sigla. |
| `validates :party_label, :legislature, :started_on, presence: true` | Sigla, legislatura e data de início obrigatórias. |
| `validates :kind, inclusion: { in: KINDS }` | Só aceita os quatro tipos acima. |
| `change?` | Diz se foi decisão do deputado (`new_term` ou `switch`); mudança de nome ou fusão não conta como troca. |

### Bill (projeto de lei)

| Código | Por que está ali |
|---|---|
| `belongs_to :deputy, :party, optional: true` | Autor principal e partido; opcionais porque há projetos do Executivo ou de comissões. |
| `has_many :themes, through: :bill_themes` | Temas do projeto (saúde, educação…) via tabela de ligação. |
| `has_many :authors, through: :bill_authors, source: :deputy` | Todos os coautores. `source:` diz que cada autor é um `Deputy`. |
| `has_many :votings, through: :poll_bills, source: :poll` | Votações em que o projeto foi votado. |
| `validates :bill_number, uniqueness: { scope: :year }` | Não pode haver dois "PL 123" no mesmo ano. |

### Poll (votação) e Vote (voto)

| Código | Por que está ali |
|---|---|
| `Poll has_many :votes` | Cada votação tem os votos de cada deputado. |
| `Poll has_many :themes, :bills, :poll_orientations` | Temas, projetos votados e orientações dos partidos naquela votação. |
| `Vote::DECISIVE` | `Sim` e `Não`: os votos que mostram posição. Usado no cálculo de alinhamento. |
| `Vote validates :vote, inclusion:` | Só aceita Sim, Não, Abstenção, Obstrução ou Artigo 17. |
| `Vote validates :deputy_id, uniqueness: { scope: :poll_id }` | Um deputado vota uma vez por votação. |

### PollOrientation (orientação do partido)

| Código | Por que está ali |
|---|---|
| `DECISIVE` | Orientações que indicam lado (Sim/Não); "Liberado" e "Obstrução" não contam. |
| `FEDERATION_PREFIX` | Federações vêm como "Fdr PT-PCdoB-PV". |
| `scope :federations` | Filtra só as orientações de federações. |
| `self.federation_members` | Quebra "Fdr PT-PCdoB-PV" em `["PT", "PCDOB", "PV"]`. |

### Expense (gasto da cota parlamentar)

| Código | Por que está ali |
|---|---|
| `SUPPLIER_KEY` | SQL que agrupa fornecedores pelo CNPJ/CPF; sem documento (ex.: passagens aéreas), usa o nome. |
| `SUPPLIER_NAME` | SQL que escolhe o nome mais frequente do fornecedor no grupo. |
| `DOCUMENT_DIGITS` | SQL que deixa só os dígitos do CNPJ/CPF, porque a base traz formatações variadas (ex.: `560.310.060/0018-0`). 14 dígitos = CNPJ, 11 = CPF. |
| `scope :with_cnpj` | Só notas de empresa (14 dígitos). Usado pela regra de CNAE e pela consulta de fornecedores. |
| `validates :month, 1..12` | Mês válido. |
| `validates :document_amount, :net_amount, numericality` | Aceita negativos, porque estornos vêm com valor negativo. |

### Supplier (fornecedor)

Cadastro de cada empresa (CNPJ) das despesas na Receita Federal, consultado na BrasilAPI por `Suppliers::CnpjLookup` e guardado para não repetir a consulta.

| Código | Por que está ali |
|---|---|
| `normalizes :cnpj` | Guarda só os dígitos; o índice único em `cnpj` impede duplicatas. |
| `cnae_code`, `cnae_description`, `secondary_cnaes` | Atividade principal (7 dígitos) e lista de secundárias `{code, description}` em jsonb. |
| `registration_status`, `registration_status_date` | Situação cadastral (ATIVA, BAIXADA, INAPTA…) e desde quando. |
| `fetched_at`, `fetch_error` | Quando foi consultado e o erro da API, se houve. |
| `scope :stale` | Nunca consultado ou consultado há mais de 90 dias (`REFRESH_AFTER`). |
| `scope :with_activity` | Consultado sem erro e com CNAE. Só esses entram nas regras. |
| `activity_in?(prefixes)` | Diz se a atividade principal ou alguma secundária começa com um dos códigos (divisão `73`, grupo `473`). |
| `inactive_on?(date)` | Situação diferente de ATIVA desde antes da data da nota. Sem a data da situação devolve false: não dá para afirmar que já estava inativa. |
| `Supplier.format_cnae` | `4731800` → `47.31-8/00`. |
| `Supplier.valid_cnpj?` | Confere os dígitos verificadores do CNPJ. O `FetchJob` pula os inválidos (ex.: `00000000000000`, que aparece na base) sem chamar a API. |

### ExpenseAlert (alerta de gasto gravado)

Alertas de `ExpenseAnomalies` gravados por deputado e ano, para o ranking comparar a Câmara inteira sem recalcular as regras a cada visita. A aba Gastos continua calculando na hora.

| Código | Por que está ali |
|---|---|
| `belongs_to :deputy` | `Deputy has_many :expense_alerts`. |
| `enum :severity` | `low`, `medium` ou `high`, gravados como texto. |
| `expense_ids` (bigint array), `details` (jsonb) | Notas do alerta e o resto da linha (fornecedor, tipo, CNAE…). |
| `WEIGHTS` | Peso de cada gravidade na pontuação: alta = 5, média = 2, baixa = 1. |
| `scope :at_least` | Gravidade igual ou acima da pedida, pela ordem de SEVERITY_ORDER (`medium` → média e alta). |
| `attributes_from(row)` | Converte uma linha de `ExpenseAnomalies#for_year` em atributos. |
| `SEVERITY_ORDER` | Ordem das gravidades, da menor para a maior (`low`, `medium`, `high`). O `enum` e o `at_least` usam essa constante, então reordenar o enum não inverte o filtro. |

### Proposal (proposta de campanha ou programa)

| Código | Por que está ali |
|---|---|
| `SOURCE_KINDS` | Tipos de origem: proposta de campanha, plano de governo, programa do partido. |
| `belongs_to :theme` | Toda proposta tem um tema. |
| `has_many :polls, through: :proposal_polls` | Votações que cumprem (ou não) a proposta. |
| `validate :belongs_to_deputy_or_party` | Validação própria: exige deputado ou partido. |
| `scope :for_deputy` | Propostas do deputado + as do partido dele (as estaduais só se forem do estado dele). |
| `source_label` | Traduz `source_kind` para o texto exibido. |
| `ProposalPoll#favorable_vote` | O voto (Sim/Não) que cumpre a proposta naquela votação. |

### Theme (tema)

| Código | Por que está ali |
|---|---|
| `has_many :bills, :polls` | Projetos e votações do tema. |
| `has_many :proposals, dependent: :restrict_with_error` | Impede apagar um tema que ainda tem propostas. |
| `default_scope { order(:position, :name) }` | Toda busca de temas já vem ordenada. |
| `keyword_list` | Transforma o texto "saúde, hospital" em `["saúde", "hospital"]`; usado pelo classificador de temas. |

### User, Chat, Message e Model

| Código | Por que está ali |
|---|---|
| `User devise :database_authenticatable, ...` | Login com e-mail e senha, cadastro, recuperar senha e "lembrar de mim". |
| `User validates :first_name, :last_name` | Nome e sobrenome obrigatórios no cadastro. |
| `User has_many :chats` / `Chat belongs_to :user` | Cada usuário tem suas conversas com a Harpia. |
| `Chat has_many :messages` | Cada conversa tem várias mensagens. |
| `Message validates :role, inclusion: user/assistant` | A mensagem é do usuário ou da IA. |
| `Model acts_as_model` | Tabela da gem `ruby_llm` com a lista de modelos de IA disponíveis. |

### Tabelas de ligação e BrazilMap

`BillAuthor`, `BillTheme`, `PollBill`, `PollTheme` e `ProposalPoll` só têm dois `belongs_to`: ligam um registro ao outro (muitos-para-muitos). As que têm `validates ... uniqueness: { scope: }` impedem a mesma ligação duas vezes. `BrazilMap` não é tabela: é um módulo com os contornos SVG de cada UF (`PATHS`), a posição das siglas (`LABELS`) e as setas dos estados pequenos (`CALLOUTS`), usado no mapa de partidos da home e no mapa da bancada do perfil do partido.

## Páginas

Cada página abaixo segue a ordem em que o código roda: rota → action do controller → o que a view chama. As páginas públicas usam `skip_before_action :authenticate_user!` para abrir sem login; só o chat exige conta.

### Layout comum (todas as páginas)

Arquivo: `app/views/layouts/application.html.erb`.

1. `content_for(:title) || "Harpia"`: título da aba; cada página pode definir o próprio.
2. `csrf_meta_tags` e `csp_meta_tag`: proteções de segurança dos formulários do Rails.
3. `stylesheet_link_tag "application"` e `javascript_importmap_tags`: carregam o CSS e o JavaScript (Stimulus).
4. `render "shared/navbar"`: menu do topo (HOME, CANDIDATOS, DEPUTADOS, ALERTAS, VOTAÇÕES, PROJETOS). Usa `current_page?` para marcar o link ativo (o link ALERTAS leva ao ranking de alertas de gastos, /alertas). Partidos não tem aba própria: o mapa de partidos fica na home. Usa `user_signed_in?` para mostrar "Entrar/Cadastre-se" ou "Sair". O "Sair" usa `data: { turbo_method: :delete }` porque o logout do Devise é um DELETE.
5. `render "shared/flashes"`: mostra `notice` e `alert` (mensagens de sucesso ou erro depois de um redirect).
6. `yield`: onde entra o conteúdo da página.
7. `render "shared/chat_widget"`: botão flutuante da Harpia. Usa `turbo_frame_tag "chat_widget_messages"` para trocar só as mensagens sem recarregar a página e o Stimulus `chat-widget` para abrir, fechar e mostrar "carregando".
8. `render "shared/footer"`: rodapé com links para Sobre e Contato; `Time.current.year` põe o ano atual.

### Home (`/`)

Rota `root to: "pages#home"` → `PagesController#home`. A home tem o hero com o mapa do Brasil e as capitais piscando e, logo abaixo, o mapa de partidos da Câmara (a seção `#partidos`). A busca de candidatos fica na página Candidatos.

1. `include PartyOverview`: concern (`app/controllers/concerns/party_overview.rb`) com a montagem dos dados do mapa de partidos.
2. `load_party_overview`: carrega tudo o que o mapa precisa (passos abaixo).
3. `policy_scope(Party).order(:label).to_a`: todos os partidos em ordem alfabética.
4. `Deputy.group(:state_label, :party_id).count`: quantos deputados cada partido tem em cada estado (`{ ["SP", 3] => 12, ... }`).
5. `@state_seats = Hash.new(0)`: soma as cadeiras por estado. `Hash.new(0)` faz toda chave nova começar em zero.
6. `parties.partition { ... }`: separa os partidos com bancada dos sem bancada (`@parties_without_bench`), mostrados como chips no fim.
7. `party_map_data(with_bench, seats)`: monta num só objeto os partidos (sigla, nome, link, logo), as cadeiras nacionais e as de cada estado. `Hash.new { |hash, uf| hash[uf] = {} }` cria o hash de cada estado na primeira vez que é usado. `helpers.party_logo_path` chama um helper de dentro do controller.
8. `params[:uf].to_s.upcase.presence_in(PartiesController::STATES.keys)`: só aceita uma UF válida vinda da URL (`/?uf=SP`).

Na view (`pages/home.html.erb`):

- Hero: a mira de câmera (`camera-viewfinder`) com a silhueta do Brasil e um ponto por capital (`capital-dot`), só em HTML e CSS.
- `render "parties/overview"`: o mapa de partidos, com `id="partidos"` para os links `root_path(anchor: "partidos")` chegarem direto nele.

No partial `parties/_overview.html.erb`:

- `raw json_escape(@map_data.to_json)`: escreve os dados do mapa como JSON dentro da página; `json_escape` impede que um texto quebre o HTML.
- `data-controller="party-map compare-selection"`: dois Stimulus no mesmo elemento. O `party-map` troca a lista para o estado clicado sem ir ao servidor e põe `?uf=SP` na URL; o `compare-selection` (o mesmo da lista de deputados, com a chave `party-compare` e limite `PartiesController::COMPARE_LIMIT` = 4) guarda os partidos escolhidos.
- Cartão "Comparar partidos": leva ao panorama `/parties/compare`.
- Botão "Escolher partidos": liga o modo de comparação e mostra a caixa "Comparar" em cada linha. A barra "N de 4" tem Limpar e o link Comparar, que abre `/parties/compare?ids[]=...`.
- `<template data-party-map-target="row">`: modelo de cada linha da lista. O `party-map` preenche no `buildRow` o link, a sigla, a logo e o `value` da caixa Comparar (o id do partido), com `aria-label` "Comparar PT" para leitores de tela.
- `BrazilMap::PATHS`, `LABELS` e `CALLOUTS`: desenham cada estado; quanto mais deputados, mais forte a cor (`fill-opacity`).

`PartiesController#index` (`/parties`) não tem mais página própria: redireciona com `status: :moved_permanently` (301) para `/#partidos`, mantendo o `?uf=`, para links antigos continuarem funcionando.

### Sobre (`/sobre`) e Contato (`/contato`)

`PagesController#about` e `#contact` estão vazias: as páginas são só HTML. Em Sobre, `data-controller="github-team"` busca na API do GitHub a foto e o nome de cada pessoa da equipe. Como `skip_pundit?` cobre o `PagesController`, nenhuma das três chama `authorize`.

### Padrão das listagens (Candidatos, Deputados, Projetos, Votações)

As quatro listagens repetem o mesmo esqueleto. Vale entender uma vez:

1. `policy_scope(Model)`: ponto de partida exigido pelo Pundit em todo `index`.
2. `apply_search` / `search`: aplica a busca do campo de texto (`params[:q]`) com `ILIKE` (busca sem diferenciar maiúsculas). `sanitize_sql_like` escapa `%` e `_` digitados pelo usuário.
3. `filters = { ... }.compact`: monta só os filtros preenchidos; `.presence` transforma texto vazio em `nil` e `.compact` remove os `nil`.
4. `apply(scope, filters)`: usa `reduce` para encadear um `where` por filtro.
5. Contadores (`@state_counts`, `@party_counts`, `@theme_counts`…): `apply(base, filters.except(:x)).group(:x).count` conta quantos resultados cada opção do filtro X teria, ignorando o próprio X. É o número ao lado de cada opção.
6. Paginação manual: `@total`, `@total_pages` (no mínimo 1), `@page` limitado entre 1 e o total, e `.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)`.
7. `.includes(...)`: carrega as associações usadas nos cards de uma vez (evita N+1).

Nas views:

- `render "painel/hero"`: cabeçalho com título e destaque.
- `data-controller="filter-form"` com `input->filter-form#submit change->filter-form#submit`: envia o formulário sozinho 300 ms depois da última digitação ou troca de filtro (`requestSubmit` com `setTimeout`, para não mandar um pedido por letra).
- `turbo_frame_tag "..._list", data: { turbo_action: "advance" }`: só a lista é trocada; `advance` atualiza a URL para o filtro poder ser compartilhado.
- `data: { turbo_frame: "_top" }` nos links dos cards: faz o clique sair do frame e abrir a página inteira.
- `render partial: "painel/..._card", collection: @x, as: :y`: desenha um card por item.
- `render "painel/empty_state"`: mensagem quando nada foi encontrado.
- `render "painel/pagination"` ou `render "shared/pagination"`: botões Anterior/Próxima. O `shared` recebe `path_for` (um lambda que gera o link de cada página) e mostra uma janela de 2 páginas para cada lado.
- `"candidato".pluralize(@total)`: plural automático ("1 candidato", "5 candidatos").

### Candidatos — lista (`/candidates`)

`CandidatesController#index`, além do padrão acima:

1. `SORTS`: ordenações permitidas (nome, estado, número). `SORTS.key?(params[:sort])` evita que o usuário injete uma ordenação qualquer.
2. `policy_scope(Candidate).search(params[:q])`: a busca fica no modelo (`Candidate.search`). Se o texto for uma sigla de partido (atual ou antiga, em `former_labels`), busca pelos candidatos do partido; senão, pelo nome.
3. `.with_attached_photo`: carrega as fotos de todos os candidatos da página de uma vez.
4. `@deputies_by_json_id`: deputados correspondentes aos candidatos da página, indexados por `json_id` com `index_by`.
5. `DirectoryMetrics.new(...)`: calcula gasto mensal, participação e projetos desses deputados (ver Services).

No card (`painel/_candidate_card`):

- Foto em três tentativas: `photo_file` com URL → `candidate.photo.attached?` (foto ligada ao candidato) → `deputy&.photo&.attached?` (foto do deputado, para quem já tem mandato). `&.` evita erro quando o deputado não existe.
- `render "painel/metrics"`: barra de gasto (`metrics.expense_percent`), participação e projetos. `info_tip` mostra o ⓘ com a explicação do cálculo.

### Candidato — perfil (`/candidates/:id`)

`CandidatesController#show`:

1. `Candidate.find(params[:id])` e `authorize @candidate`: busca e checa permissão (`CandidatePolicy#show?` libera todos).
2. `DeputyOverview.new(@candidate.current_deputy)`: só se o candidato já é deputado; traz gastos e votos do mandato.

Na view:

- `content_for :title` e `content_for :head`: título da aba e metatags (descrição para compartilhamento).
- `@candidate.photo.attached? ? @candidate.photo : deputy&.photo`: usa a foto do candidato ou, sem ela, a do deputado.
- `@candidate.name.casecmp?(...)`: só mostra o nome civil se for diferente do nome de urna.
- `render "deputies/party_history", affiliations: deputy.party_affiliations.includes(:party), candidate: @candidate`: só para quem já é deputado. Mostra a linha do tempo de partidos e fecha com a candidatura de 2026, avisando se é "pelo mesmo partido".
- `render "deputies/spending"` e `render "deputies/votes"`: blocos de gastos e votos, reaproveitados do perfil do deputado.

### Deputados — lista (`/deputies`)

`DeputiesController#index`, além do padrão das listagens:

1. Filtros por estado, partido e situação eleitoral (`electoral_status`).
2. `@reelection = params[:reelection] == "1"` e `.running_for_reelection`: chave "só quem tenta a reeleição"; `@reelection_count` é o número ao lado da chave.
3. `SORTS`: algumas ordenações são SQL (`order:`), outras são indicadores calculados (`metric:`) e ordenadas em Ruby.
4. `params[:page].to_i.clamp(1, @total_pages)`: mantém a página dentro do intervalo válido.
5. `DeputyMetrics.reference_year`, `.expenses`, `.participation`: indicadores de todos os deputados de uma vez, com cache.
6. `summarize(ids)`: resumo do recorte filtrado (gasto mensal médio, participação média, quantos tentam reeleição).
7. `page_of(scope)`: devolve os deputados da página. Se a ordenação é por indicador, ordena os ids em Ruby e busca só os da página; senão, usa `.order(Arel.sql(...))`. `send(sort[:metric])` chama o método cujo nome está no `SORTS`.
8. `monthly_expense_values`, `participation_values`, `alignment_values`, `against_party_values`: métodos de uma linha que transformam cada indicador em `{ deputy_id => número }` para ordenar.
9. `@bill_counts`, `@reelection_ids`: projetos por deputado e quem tenta reeleição, só para os da página. `.to_set` deixa a busca com `include?` rápida.
10. `@parties`: esconde partidos sem deputados no recorte, mas mantém o selecionado.

Na view: `data-controller="compare-selection"` liga o modo "Comparar", com `data-compare-selection-key-value="deputy-compare"` (chave no `sessionStorage`) e `data-compare-selection-limit-value` = `COMPARE_LIMIT` (3). O Stimulus guarda a seleção no `sessionStorage` (sobrevive à troca de página) e é o mesmo usado na lista de partidos da home. Cada card usa `deputy.photo.attached?` + `cl_image_tag` para a foto, `brl` para o gasto e `percent` para a participação.

No topo, `render "painel/hero"` (como nas outras listagens), com os filtros flutuando sobre ele. Abaixo dos filtros, dois cartões lado a lado no estilo `party-compare-cta` do "Comparar partidos": "Comparar deputados" leva ao panorama `/deputies/compare` e "Ranking de alertas de gastos" leva a `/alertas`; como ficam dentro do turbo frame da lista, usam `data: { turbo_frame: "_top" }`.

### Deputado — perfil (`/deputies/:id`)

`DeputiesController#show`:

1. `Deputy.includes(:party).find(params[:id])` e `authorize @deputy`.
2. `LEGACY_TABS.fetch(params[:tab], params[:tab])`: traduz links antigos em português (`?tab=gastos`) para a chave nova (`expenses`).
3. `TABS.key?(tab) ? tab : "overview"`: aba inválida ou escondida cai na Visão geral. `TABS` é `ALL_TABS` sem as abas de `HIDDEN_TABS`.
4. `DeputyStats.new(@deputy)`: objeto com os indicadores individuais (ver Services).
5. `@deputy.candidates.first`: a candidatura de 2026, se houver.
6. `send("load_#{@tab}")`: chama só o método da aba aberta (`load_overview`, `load_expenses`…), para não calcular o que não será mostrado.

Na view: `content_for :head` põe as metatags de compartilhamento (`deputy_url`, `photo_url`). `turbo_frame_tag "deputy_tab"` faz a troca de aba carregar só o conteúdo da aba. `render "deputies/tabs/#{@tab}"` escolhe o arquivo da aba.

**Aba Visão geral** (`load_overview`)

- `@deputy.expenses.maximum(:year)`: o ano mais recente com gastos.
- `@stats.total_expenses`, `vote_participation`, `party_alignment`, `@deputy.bills.count`: os quatro números do topo. Cada um vira link para a aba correspondente com `deputy_tab_path`.
- `render "deputies/party_history", affiliations: @deputy.party_affiliations.includes(:party)`: linha do tempo de partidos. O partial conta as trocas com `change?` (sem contar "S.PART."), escreve "Sempre no mesmo partido" ou "N trocas de partido" e usa `affiliation_party` e `affiliation_event` em cada data.
- `mail_to` gera o link de e-mail; `link_to "tel:..."` o de telefone; `social_links` lista as redes sociais válidas.

**Aba Gastos** (`load_expenses`)

- `policy_scope(@deputy.expenses)`: gastos que podem ser exibidos.
- `@years` e `@year`: anos disponíveis; o ano pedido só vale se existir, senão usa o mais recente.
- `expenses.sum(:net_amount)`: total do ano, já sem estornos.
- `@stats.monthly_average`, `expense_benchmarks`, `year_over_year`, `supplier_concentration`, `expenses_by_type`: média mensal, comparação com estado e partido, variação sobre o ano anterior, peso do maior fornecedor e gasto por tipo.
- `DeputyMetrics.quota_usage` e `expense_rank`: uso da cota (CEAP) e posição no ranking.
- `ExpenseAnomalies.new(@deputy).for_year(@year)`: gastos fora do padrão, calculados na hora; `@anomaly_documents` liga cada um ao PDF da nota. Na view, `expense_anomaly_text` escreve o título e o critério de cada alerta.
- `@alerts_by_expense`: índice `{ expense_id => [alertas] }` montado no controller, para a tabela não percorrer todos os alertas a cada linha. `@anomaly_expense_ids` são as chaves dele.
- `expenses.group(:month).sum(:net_amount)`: gráfico mês a mês; `month_label` escreve "Jan", "Fev"…
- `@top_suppliers`: os 10 maiores fornecedores, agrupados por `Expense::SUPPLIER_KEY`. `supplier_document` esconde parte do CPF (LGPD) e formata o CNPJ (`56.031.006/0001-80`).
- `filtered_expenses` + `paginate(...)`: lista paginada das notas, filtrável por tipo, mês, período (`from`/`to`, mês inicial e final; invertidos são trocados; mudar o período desfaz o filtro de mês, o link de um mês fora do período troca o período pelo mês e um mês fora do período vindo da URL é ignorado) e só notas com alerta (`alerts=1`). O formulário usa o Stimulus `filter-form` e mantém os parâmetros na URL. Estornos (valor negativo) aparecem em verde.
- Cada nota marcada ganha, logo abaixo, um bloco `alert-danger` (se algum alerta é de gravidade alta) ou `alert-warning` com o título e o critério de cada alerta e a atividade (CNAE) do fornecedor, lida de `@suppliers`. A linha mostra o CNPJ formatado e o link "Ver nota na Câmara".

**Aba Projetos de lei** (`load_bills`)

- `DeputyMetrics.average_bills` + `compared_to_average`: "35% acima da média".
- `top_keywords`: palavras-chave mais frequentes dos projetos, sem termos genéricos (`GENERIC_KEYWORDS`) e só as que aparecem mais de uma vez.
- `DeputyThemeProfile#bills_by_theme` + `themes_with_counts`: projetos por tema, na ordem do catálogo.
- Filtros por ano, tema (`Theme.find_by(slug:)`) e palavra-chave; `proposicao_label(bill)` escreve "PL 123/2025".

**Aba Votações** (`load_votes`)

- `@deputy.votes.group(:vote).count`: distribuição dos votos (Sim, Não…); `vote_badge_class` dá a cor de cada um e `vote_explanation` explica Abstenção, Obstrução e Artigo 17.
- `@stats.against_party_poll_ids`: votações em que votou contra a maioria do partido; o filtro `against_party` usa essa lista.
- `@stats.party_majorities(...)`: o voto da maioria do partido em cada votação da página, para mostrar lado a lado.
- `.joins(:poll).includes(poll: :bill)`: junta a votação para ordenar pela data e carrega o projeto de cada uma.

**Aba Promessas × Atuação** (`load_promises`)

Escondida por enquanto: `"promises"` está em `DeputiesController::HIDDEN_TABS`, então a aba não aparece no perfil e `?tab=promises` cai na Visão geral. O código (`load_promises`, `deputies/tabs/_promises.html.erb` e os testes, com `skip`) continua no projeto; para reativar, tire a chave de `HIDDEN_TABS`.

- `DeputyThemeProfile.new(@deputy)`: cruza, por tema, as propostas (do deputado e do partido) com os projetos e votos dele.
- `@profile.rows`: uma linha por tema; `@profile.coherence`: % de votos no sentido que cumpre as propostas. Se `conclusive` for falso, a view avisa que há pouca evidência (menos de `MIN_EVIDENCE` votos).

**Aba Eleições 2026** (`load_elections`)

O método está vazio: a aba usa só o `@candidate` já carregado no `show`. A view avisa se o deputado concorre por um partido diferente do atual (`@candidate.party_id != @deputy.party_id`).

### Comparar deputados (`/deputies/compare`)

`DeputiesController#compare`, no mesmo formato de `/parties/compare`: sem `ids`, mostra o panorama dos 513 deputados em exercício; com `?ids[]=`, a comparação lado a lado (próxima seção).

1. `authorize Deputy`: autoriza a classe, porque não há um registro só (`DeputyPolicy#compare?`).
2. `if params.key?(:ids)`: desvia para a comparação lado a lado com `return render :compare_selected`.
3. `DeputyPanorama.new`: calcula os indicadores de todos os deputados (ver Services).
4. `@sort` e `@direction`: coluna e sentido da ordenação, só entre os valores de `DeputyPanorama::SORTS` (padrão: governismo, do maior para o menor).
5. `@state` e `@party`: filtros da tabela. `presence_in(...)` só aceita uma UF que existe; `Party.find_by` ignora um partido inexistente.
6. `@panorama.sorted_rows(@sort, @direction, state:, party_id:)`: as linhas filtradas e ordenadas; quem não tem o dado vai para o fim.
7. Paginação em Ruby com `PANORAMA_PER_PAGE = 50`: `@page` limitado com `clamp` e `rows.slice(...)`.
8. `@positioned = @panorama.positioned`: os deputados do mapa de posicionamento, sempre todos (o filtro vale só para a tabela).
9. `@filter_averages = @panorama.averages(rows) if @state || @party`: médias do recorte filtrado (todos os filtrados, não só a página).

Na view (`deputies/compare.html.erb`), de cima para baixo:

- `@panorama.insights`: frases de destaque geradas a partir dos números (blocos, deputados fora do bloco do partido, quem mais vota contra o partido, menor presença, maior e menor gasto, projetos de lei e reeleição).
- `@panorama.blocs`: deputados contados um a um em governista, centro e oposição pelo próprio governismo (as mesmas faixas de `PartyComparison::BLOCS`), com a barra e a linha da maioria (257). `@panorama.off_bloc` lista quem está num bloco diferente da maioria do próprio partido.
- `deputy_positioning_chart(@positioned)`: gráfico em SVG com um ponto por deputado (governismo × alinhamento ao partido), cor do bloco e link para o perfil.
- Tabela "Indicadores lado a lado": deputado, partido, UF, governismo, alinhamento ao partido, votos contra o partido, participação, gasto mensal, projetos de lei e reeleição. `deputy_panorama_sort_link` gera o link de ordenação mantendo os filtros e `party_sort_aria` informa a ordenação para leitores de tela.
- `turbo_frame_tag "deputies_panorama_table", data: { turbo_action: "advance" }`: filtros (estado e/ou partido, com o Stimulus `filter-form`), ordenação e paginação trocam só a tabela e atualizam a URL. Os links para deputado e partido usam `data: { turbo_frame: "_top" }`.
- Rodapé da tabela: "Média da Câmara" (sempre dos 513, `@panorama.averages`) e, com filtro, "Média do filtro" com quantos deputados entram no recorte.
- "Como calculamos e limites dos dados": metodologia recolhível.

### Comparar deputados escolhidos (`/deputies/compare?ids[]=...`)

Mesma action `DeputiesController#compare`, no desvio `params.key?(:ids)`:

1. `Array(params[:ids]).reject(&:blank?).first(COMPARE_LIMIT)`: no máximo 3 ids.
2. `.includes(:party, photo_attachment: :blob)`: carrega partido e foto.
3. `.index_by { ... }.values_at(*ids)`: mantém a ordem em que o usuário escolheu.
4. `DeputyComparison.new(@deputies)`: monta as linhas da tabela.
5. `render :compare_selected`: usa a view `deputies/compare_selected.html.erb`.

Na view: `@comparison.rows` dá cada linha; `@comparison.highlight(row, deputy)` marca `:best` ou `:worst`; `compare_value(row, cell)` formata como moeda, % ou número; `@comparison.divergences` mostra, para cada par, em quantas votações votaram diferente. Com menos de dois deputados, pede para escolher na listagem ou ver o panorama.

`ExpensesController#index` (`/deputies/:id/expenses`) não tem página própria: redireciona com `status: :moved_permanently` (301) para a aba Gastos do deputado.

### Alertas de gastos — ranking (`/alertas`)

Rota `get "alertas", to: "expense_alerts#index"` → `ExpenseAlertsController#index`, pública (`skip_before_action :authenticate_user!`), com `authorize ExpenseAlert` e `policy_scope` (`ExpenseAlertPolicy`).

1. `read_filters`: ano (padrão `DeputyMetrics.reference_year`), UF, partido, gravidade mínima (`SEVERITY_LABELS`: todas, média e alta, só alta) e ordenação (`ORDERS`: pontuação ou parte do gasto em notas com alerta).
2. `@computed_at` (`ranking.computed_at`): o `updated_at` mais recente dos alertas do ano, ou seja, quando o `RefreshJob` rodou. `nil` = ano ainda não calculado.
3. `ExpenseAlertRanking.new(year:, state:, party:, severity:, order:, scope: policy_scope(ExpenseAlert))`: o ranking saiu do controller para um service, usado também pela Harpia (`ExpenseAlertRankingTool`), para os dois mostrarem os mesmos números (ver Services).
4. `ranking.rows`: uma consulta agregada em `expense_alerts`, agrupada por `deputy_id`. A pontuação é `SCORE_SQL` (`SUM(CASE severity ...)` com os pesos de `ExpenseAlert::WEIGHTS`); desempate por `VALUE_SQL` (soma do valor sinalizado) e depois pelo nome. `COUNT_SQL` conta os alertas de cada gravidade.
5. `with_shares` (no service): soma o valor das notas com alerta de cada deputado (`UNNEST(expense_ids)`, então a mesma nota em dois alertas conta uma vez) e divide pelo total gasto no ano (`DeputyMetrics.expenses(@year)`). Com `order=share`, a lista é reordenada por essa fração, mantendo a pontuação como desempate.
6. `page_of`: paginação em Ruby sobre essa lista (no máximo ~513 linhas), 24 por página.
7. `with_deputies`: só os deputados da página, numa consulta (`includes(:party).with_attached_photo`), sem N+1.
8. `@note_counts` conta as notas de cada deputado da página.

Na view (`expense_alerts/index`): `painel/hero` no topo e um aviso fixo de que alerta não é prova de irregularidade. Acima dos cards, "Alertas calculados em dd/mm/aaaa"; ano sem cálculo mostra "ainda não foram calculados" em vez de "nenhum deputado". O formulário de filtros usa o Stimulus `filter-form`. Cada card (grid `row-cols-1 row-cols-md-2 row-cols-xl-3`) mostra posição, foto, nome, partido/UF, total gasto, notas, valor em notas com alerta (e o percentual do gasto), alertas e pontuação, e badges por gravidade (`text-bg-danger`, `text-bg-warning`, `text-bg-secondary`). O card leva a `deputy_path(deputy, tab: "expenses", year:)`. `shared/pagination` faz a paginação.

### Partido — perfil (`/parties/:id`)

`PartiesController#show`:

1. `Party.find` + `authorize @party`.
2. `TABS.key?(params[:tab])`: aba válida ou "overview".
3. `@party.deputies.with_attached_photo.order(:name).to_a`: bancada com fotos.
4. `PartyStats.new(@party, @deputies)`: todos os indicadores do partido (ver Services).
5. `@party.candidates.count`: candidatos de 2026.

Na view: o link "Voltar para Partidos" leva a `root_path(anchor: "partidos")`. `@party.leader` busca o líder; `party_logo(...) || tag.i(...)` mostra a logo ou um ícone de bandeira; `render "parties/tabs/#{@tab}"` abre a aba.

| Aba | O que chama | Para quê |
|---|---|---|
| Visão geral | `@stats.cohesion`, `@party.absorbed`, `@stats.federation`, `@stats.state_bench` | Coesão, partidos incorporados, federação e mapa da bancada por UF (`render "parties/bench_map"`, com `bench_map_weight`; cada estado leva a `/?uf=SP#partidos`). `deputy.json_id == @party.leader_json_id` marca o líder na lista. |
| Votações | `divided_polls`, `orientation_adherence`, `affinity`, `contested_polls`, `dissidents` | Votações em que a bancada rachou, quanto segue o líder, partidos que mais e menos votam igual, placares apertados e deputados que mais votam contra o partido. `bench_position` diz se a bancada foi Sim, Não ou dividida. |
| Gastos | `@stats.expenses` | Gasto mensal médio da bancada contra a média da Câmara (`compared_to_average`), quem mais gasta e os tipos de despesa. |
| Projetos de lei | `bills`, `bill_types`, `bill_themes`, `recent_bills`, `proposals` | Projetos do partido por tipo e tema, os mais recentes e as propostas do programa. Os links usam `bills_path(party:, type:, theme:)` para abrir a lista já filtrada. |
| Candidatos 2026 | `@stats.candidate_profile` | Perfil dos candidatos: gênero, cor/raça, escolaridade e estados. `render "parties/distribution"` desenha cada distribuição em barras. |

### Comparar partidos (`/parties/compare`)

`PartiesController#compare`:

1. `authorize Party`: autoriza a classe (`PartyPolicy#compare?`).
2. `PartyComparison.new`: calcula tudo sobre todos os partidos com bancada.
3. `if params.key?(:ids)`: se a URL trouxe partidos escolhidos, desvia para a comparação lado a lado (próxima seção) com `return render :compare_selected`. Sem `ids`, segue o panorama abaixo.
4. `@sort` e `@direction`: coluna e sentido da ordenação, só entre os valores permitidos em `PartyComparison::SORTS`.
5. `@comparison.sorted_rows(@sort, @direction)`: as linhas da tabela ordenadas; quem não tem o dado vai para o fim.

Na view, de cima para baixo:

- `@comparison.insights`: frases de destaque geradas a partir dos números.
- `@comparison.blocs`: partidos agrupados em governo, centro e oposição pelo governismo, com a barra de cadeiras e a linha da maioria (`PartyComparison::MAJORITY` = 257).
- `positioning_chart(@comparison.positioned)`: gráfico de bolhas em SVG (governismo × coesão, tamanho = bancada). O helper calcula posições e testa onde cada rótulo cabe sem cobrir outro (`label_spots`, `inside?`, `overlap?`).
- Tabela de indicadores: `party_sort_link` gera o link que inverte a ordenação e `party_sort_aria` informa a ordenação para leitores de tela.
- `@comparison.affinity` + `affinity_cell_style(pct)`: matriz de afinidade; quanto mais votos iguais, mais escuro o azul.

Abaixo da tabela de indicadores, um texto aponta para "Escolher partidos" no mapa de partidos da home, para quem quer ver só alguns.

### Comparar partidos escolhidos (`/parties/compare?ids[]=...`)

Mesma action `PartiesController#compare`, no desvio `params.key?(:ids)`:

1. `Array(params[:ids]).reject(&:blank?).first(COMPARE_LIMIT).map(&:to_i)`: no máximo 4 ids, como números.
2. `@comparison.rows.index_by { |row| row.party.id }`: as linhas do panorama indexadas por partido, para reaproveitar os mesmos números.
3. `rows.values_at(*ids).compact.uniq`: mantém a ordem em que o usuário escolheu e descarta ids inexistentes ou repetidos.
4. `PartySelectionComparison.new(..., @comparison)`: monta a tabela lado a lado (ver Services).
5. `render :compare_selected`: usa a view `parties/compare_selected.html.erb` em vez de `compare`.

Na view:

- `if parties.size < 2`: com menos de dois partidos, pede para escolher de 2 a 4 na lista de partidos da home.
- Cabeçalho de cada coluna: `party_logo`, sigla com link, nome e o bloco (`@selection.bloc_label(row.bloc)`: governo, centro ou oposição).
- `@selection.rows`: uma linha por indicador, com `info_tip(row.info)` explicando o cálculo e `compare_value(row, cell)` formatando o valor (o formato `:decimal` foi criado para "projetos por deputado", com uma casa e vírgula). `cell[:detail]` mostra um texto menor embaixo, como "+2 desde a posse".
- `@selection.highlight(row, party)`: marca `:best` ou `:worst` só nas linhas com direção; governismo, coesão e disciplina não têm lado melhor. Um texto `visually-hidden` repete a marca para leitores de tela.
- `@selection.affinities`: para cada par de partidos, em quantas votações em comum votaram do mesmo lado, ou "poucas votações em comum" abaixo de `PartyStats::AFFINITY_MIN_POLLS`.

### Projetos de lei — lista (`/bills`)

`BillsController#index`, além do padrão das listagens:

1. `BillSearch.new(policy_scope(Bill), query:, year:, theme:, party:, type:, author:)` (`app/queries/bill_search.rb`): a busca e os filtros ficam num objeto de consulta, usado também pela Harpia (`BillListTool`), para os dois mostrarem os mesmos projetos na mesma ordem (`BillSearch::ORDER`, os mais recentes primeiro).
2. `BillSearch::NUMBER_QUERY`: expressão regular que reconhece buscas como "PL 1234/2025" ou "PEC 45". Se a busca bate, procura pelo tipo, número e (se houver) ano; senão, procura o texto na ementa (`summary`) e nas palavras-chave.
3. Filtros por ano, tema, partido, tipo e autor. Tema e autor usam subconsultas nas tabelas de ligação (`BillTheme`, `BillAuthor`). `search.results(except: :theme)` ignora o filtro de tema para contar os projetos de cada tema (`@theme_counts`).
4. `.includes(:deputy, :party, :themes, bill_authors: :deputy)`: tudo que o card mostra.
5. `@years`, `@types`, `@parties`, `@themes`: opções dos filtros. `@themes` esconde temas sem projetos, menos o selecionado.

Na view: `hidden_field_tag :author` mantém o filtro de autor (vindo do perfil do deputado) ao trocar outros filtros. No card (`painel/_bill_card`): `proposicao_label(bill)` escreve "PL 123/2025"; `bill.deputy || bill.bill_authors.min_by(&:id)&.deputy` escolhe o autor principal; `truncate(bill.summary, length: 220)` encurta a ementa.

### Projeto de lei — detalhe (`/bills/:id`)

`BillsController#show`: `Bill.includes(:deputy, :party, :themes, :authors).find`, `authorize @bill` e `@bill.votings.order(date: :desc)` (votações do projeto, mais recentes primeiro).

Na view: `@bill.keywords.to_s.split(/[;,]/)` separa as palavras-chave, cada uma com link para `bills_path(q: word)`; `coauthors` tira o autor principal da lista de autores; `safe_join(...)` junta os links dos coautores com vírgula sem escapar o HTML; `poll_result_badge(poll)` mostra Aprovada, Rejeitada ou Texto mantido.

### Votações — lista (`/polls`)

`PollsController#index`, além do padrão das listagens:

1. `PollSearch.new(policy_scope(Poll), query:, all:, year:, theme:, approval:, government:)` (`app/queries/poll_search.rb`): a mesma busca da Harpia (`PollListTool`), na mesma ordem (`PollSearch::ORDER`, as mais recentes primeiro). Busca na descrição com `ILIKE`.
2. `all`: por padrão mostra só votações com votos nominais; a caixa "Incluir sem votos nominais" mostra todas.
3. Filtros por ano (`EXTRACT(YEAR FROM polls.date)`), tema, resultado (`approval`) e resultado para o Governo (`governo`: "venceu" ou "perdeu", conforme a orientação do Governo).
4. `@tallies = Vote.where(poll_id: ...).group(:poll_id, :vote).count`: placar de cada votação da página numa só consulta.

No card (`painel/_poll_card`): `unanimous_vote(counts)` detecta votação unânime; `poll_summary(poll)` tira o placar que vem colado no fim da descrição; `vote_color` e `bar_percent` desenham a barra de votos.

### Votação — detalhe (`/polls/:id`)

`PollsController#show`: `Poll.find`, `authorize @poll` e `PollBreakdown.new(@poll)`.

Na view:

- `@breakdown.tally`: total de cada tipo de voto; `@breakdown.unanimous` mostra o selo de unanimidade (ignorando o Art. 17).
- `render "polls/bills"`: projetos votados, com link.
- `@breakdown.by_party`: como cada bancada votou, com a maioria (`row[:majority]`) e a coesão.
- `render "polls/dissidents"`: deputados que votaram diferente da maioria do próprio partido (`@breakdown.dissidents`). Para votações antes de 4/4/2026 avisa que o deputado pode ter trocado de partido na janela partidária.

A rota `/polls/:poll_id/votes` e o namespace `/admin` existem no `routes.rb`, mas não há `VotesController` nem controllers em `app/controllers/admin`: essas URLs ainda não funcionam.

### Chat — Meus chats e conversa (`/chats`, `/chats/:id`)

São as únicas páginas que exigem login (`before_action :authenticate_user!`). A resposta da Harpia é gerada em segundo plano e chega à tela pelo WebSocket (Action Cable; Solid Cable em produção), sem prender a requisição.

1. `ChatsController#index`: `policy_scope(Chat)` traz só os chats do usuário (`ChatPolicy::Scope#resolve` filtra por `user`).
2. `set_chat`: `current_user.chats.find(params[:id])` garante que ninguém abra o chat de outra pessoa.
3. `#show`: `authorize @chat`. Pedido em Turbo Stream com cabeçalho `Turbo-Frame` (`turbo_frame_request?`): devolve o estado atual da conversa, pedido pelo Stimulus `chat` quando a resposta demora a chegar pelo WebSocket; enquanto a Harpia ainda responde (`awaiting_response?`), devolve `head(:no_content)` para a tela não pular. Os demais pedidos recebem a página HTML, inclusive o redirect do botão "Novo Chat", que o Turbo segue pedindo Turbo Stream sem `Turbo-Frame`.
4. `#create`: cria o chat com `current_user.chats.new`. Se já veio uma pergunta (`params.dig(:message, :content)`, como no widget), chama `MessageProcessorService` com a página de origem (`page_path`).
5. `#destroy`: `authorize @chat` (só o dono, `ChatPolicy#destroy?`) e apaga.
6. `MessagesController#create`: monta a mensagem com `Message.new` só para o `authorize` (`MessagePolicy#create?` checa se o chat é do usuário). Uma pergunta por vez: se `@chat.awaiting_response?`, responde "Aguarde a Harpia terminar a resposta anterior". `message_params` aceita só `content` e `page_path`. `rescue ActiveRecord::RecordInvalid` mostra "Não foi possível enviar a mensagem".
7. `ChatResponder` (concern dos dois controllers): `respond_with_conversation` lê o cabeçalho `Turbo-Frame` e responde só o que cada tela precisa: o widget (`chat_widget_messages`) recebe as mensagens e a lista de "Meus Chats"; o chat principal (`chat_conversation`) recebe as mensagens e o título; os demais pedidos são redirecionados para a conversa.
8. `MessageProcessorService#call`: salva a pergunta com `status: :pending`, a descrição da página (`PageContextService`) e o caminho, e agenda `ChatResponseJob.perform_later`.
9. `ChatResponseJob` (fila `harpia`, com worker próprio): chama o `ChatbotService`, grava a resposta (com `out_of_scope`, os botões de próximos passos, `actions`, e os deputados e partidos que ela apresentou, `records`) e marca a pergunta como `answered`, ou `failed` em caso de erro (sem nova tentativa, para não duplicar resposta e custo). Enquanto a IA escreve, `broadcast_partial` envia o texto recebido até ali (no máximo a cada `STREAM_INTERVAL`, 0,1 s), que substitui o "Estamos de olho..." no chat principal e no widget; cada envio leva o texto inteiro, então um envio perdido é coberto pelo seguinte. No final, envia a conversa pelo WebSocket com `broadcast_replace_to` (alvos com `dom_id`, para a resposta de uma conversa nunca aparecer em outra), substituindo o texto parcial, e gera o título depois, só para perguntas dentro do escopo.

`Message` tem `enum :status` (`pending`, `answered`, `failed`); `Chat#awaiting_response?` diz se a última pergunta ainda espera resposta; `Chat::DEFAULT_TITLE` é "Nova Investigação".

Nas views: `turbo_stream_from @chat` (no chat principal e no widget) assina o canal da conversa; `render_markdown(message.content)` converte o Markdown da resposta da IA em HTML seguro; `render "chats/actions"` mostra os próximos passos como botões abaixo da resposta (perguntas que a Harpia responde ou links para páginas da plataforma); `form_with model: [chat, Message.new]` gera o formulário que posta em `/chats/:id/messages`; `data-controller="chat"` cuida do envio, do aviso de carregamento, do bloqueio de envios e da rolagem; `button_to chat_path(chat)` é o botão de apagar.

### Login e cadastro (Devise)

As telas em `app/views/devise` (entrar, cadastrar, editar conta, esqueci a senha) são do Devise, só estilizadas. O que o projeto acrescenta: os campos `first_name` e `last_name` no cadastro e na edição, liberados por `configure_permitted_parameters` e obrigatórios pela validação do `User`.

### Páginas de erro (404 e 500)

Arquivos: `public/404.html` e `public/500.html`. Não passam por rota, controller nem layout: são HTML estático que o Rails devolve quando a página não existe (por exemplo, `find` sem resultado) ou quando o código dá erro. Por isso não usam ERB, helpers nem o CSS do app.

- CSS dentro do próprio arquivo (`<style>`) e as fontes Nunito e Work Sans do Google Fonts, para parecer com o site sem depender do asset pipeline.
- `/harpia-logo.png` (também em `public`): logo no cabeçalho e ícone da aba.
- 404 "Página não encontrada": botões "Ir para o início" e "Voltar" (`history.back()`) e links para Deputados, Partidos (mapa de partidos da home, `/#partidos`), Candidatos e Projetos de lei.
- 500 "Algo deu errado do nosso lado": botão "Tentar de novo" (`location.reload()`) e "Ir para o início".

Em desenvolvimento o Rails mostra a tela de erro detalhada no lugar delas; elas aparecem em produção.

## Services, queries, helpers e tarefas

Services e queries guardam as contas que várias páginas usam; helpers formatam o resultado na tela; as tarefas `rake` trazem os dados para o banco.

### Services e queries

| Classe | Usada em | O que faz |
|---|---|---|
| `DeputyMetrics` | Lista e comparação de deputados, partidos | Indicadores de todos os deputados de uma vez: `expenses`, `participation`, `alignment`, `party_cohesion` (índice de Rice), `party_affinity`, `quota_usage`, `expense_rank`, `average_bills`. `cached` guarda o resultado com uma chave que muda quando a tabela muda. `reference_year` = ano mais recente com gastos. |
| `DeputyStats` | Perfil do deputado | Os mesmos indicadores para um deputado só: média mensal, comparação com estado e partido, variação anual, concentração em fornecedor (alerta a partir de 50%), participação, alinhamento e votos contra o partido. |
| `ExpenseAnomalies` | Aba Gastos, chat (DeputyDetailsTool) e ExpenseAlerts::RefreshJob | Nove regras de gasto fora do padrão: nota duplicada, notas fracionadas no mesmo dia, nota atípica (acima do percentil 99,5), atividade do fornecedor incompatível com o tipo de despesa (nenhum CNAE, principal ou secundário, na lista ACTIVITY_RULES do tipo; alta a partir de R$ 5.000 pagos ao fornecedor no ano, senão média), fornecedor com CNPJ fora da situação ATIVA na data da nota (alta), pico mensal (2,5× a mediana), salto por tipo, fornecedor exclusivo e fornecedor novo. Tipos sem regra de CNAE, CPFs e passagens aéreas ficam fora da regra de atividade. Não indica irregularidade. |
| `Suppliers::CnpjLookup` | Suppliers::FetchJob | Consulta `https://brasilapi.com.br/api/cnpj/v1/{cnpj}` com `Net::HTTP` e timeout e grava no `Supplier`. Erros não levantam exceção: ficam em `fetch_error`. 404 e 400 só voltam a ser consultados depois de 90 dias; 429, 5xx e falhas de rede (inclusive `EOFError`, conexão fechada no meio) ficam sem `fetched_at` e entram na próxima rodada. `persist!` trata duas consultas do mesmo CNPJ ao mesmo tempo: a segunda atualiza o registro em vez de quebrar no índice único. |
| `Suppliers::FetchJob` | Agendado aos domingos (`config/recurring.yml`); tarefa `harpia:suppliers` | Job (Solid Queue) em lotes de 200 CNPJs (cerca de 5 min cada); cada lote enfileira o próximo, então nenhum prende uma thread por horas. `pending_cnpjs` ignora CPFs, notas sem documento, passagens aéreas e CNPJs com dígito verificador errado; com `since:`, ignora os já tentados na rodada, para que um CNPJ que falhou não seja repetido e a rodada termine. 1,5 s entre chamadas, 60 s depois de um 429. No fim, se algo foi consultado, agenda o recálculo dos alertas (`RefreshJob.refresh_all_later`). |
| `ExpenseAlerts::RefreshJob` | Ranking /alertas | Roda `ExpenseAnomalies` para cada deputado com despesas no ano e troca os alertas gravados dele numa transação (cerca de 20 s para a Câmara toda). `refresh_all_later` e `refresh_all_now` recalculam todos os anos. Roda no fim do `FetchJob`, no `db:seed`, todo dia às 5h (`config/recurring.yml`) e com `harpia:expense_alerts`. |
| `DeputyThemeProfile` | Abas Projetos, Votações e Promessas | Cruza por tema as propostas com projetos e votos; `coherence` mede quantos votos cumpriram as propostas. |
| `DeputyComparison` | Comparar deputados escolhidos | Linhas da tabela lado a lado (`Row`), `highlight` (melhor/pior) e `divergences` entre pares. `DeputyComparison.for(ids)` monta a seleção como a página (ordem da escolha, até `LIMIT` = 3), para o controller e a Harpia; `SECTIONS`, as seções da página. |
| `DeputyPanorama` | Comparar deputados (panorama) | Uma linha (`Row`) por deputado em exercício: governismo próprio (votações com orientação Sim/Não do Governo em que votou igual, mínimo `MIN_GOVERNMENT_POLLS` = 20, em cache via `DeputyMetrics.cached`), bloco (as faixas de `PartyComparison::BLOCS`), alinhamento ao partido, votos contra o partido, participação, gasto mensal, projetos de lei e reeleição. `sorted_rows` ordena e filtra por estado e partido; `blocs`, `off_bloc` (quem está num bloco diferente da maioria do partido), `positioned`, `averages` (da Câmara ou de um recorte) e `insights` (frases de destaque). `SECTIONS`: títulos e explicações das seções da página, usados pela view e pela Harpia. |
| `PartyStats` | Perfil do partido | Bancada por UF, gastos, coesão, votações divididas, adesão à orientação do líder, federação, afinidade, dissidentes, projetos e perfil dos candidatos. |
| `PartyOverview` (concern) | Home | Monta o mapa de partidos: cadeiras por estado, partidos com e sem bancada e o JSON do Stimulus `party-map` (`party_map_data`). |
| `PartyComparison` | Comparar partidos | Uma linha (`Row`) por partido, blocos por governismo (`BLOCS`), afinidade e frases de destaque (`insights`). `SECTIONS`: títulos e explicações das seções da página, usados pela view e pela Harpia. |
| `PartySelectionComparison` | Comparar partidos escolhidos | Tabela lado a lado no formato de `DeputyComparison` (reusa `DeputyComparison::Row`), com os números das linhas de `PartyComparison`: deputados, estados, governismo, coesão, segue a liderança, participação, gasto mensal, projetos por deputado, tema principal, candidatos e mulheres candidatas. `better` (`:higher`, `:lower` ou `nil`) diz se a linha tem melhor/pior; `affinities` dá a afinidade de cada par com `combination(2)`. `PartySelectionComparison.for(ids)` monta a seleção como a página (ordem da escolha, sem repetidos, até `LIMIT` = 4), para o controller e a Harpia; `SECTIONS`, as seções da página. |
| `PartyHistory` | Tarefa `partidos:historico` | Monta a linha do tempo de partidos de um deputado a partir do histórico da API da Câmara. Descarta registros "início da legislatura" com data fora da legislatura, junta siglas antigas e novas do mesmo partido (`predecessors`: `former_labels`, `MERGERS` e `HISTORICAL_RENAMES`, como PFL → DEM) e classifica cada mudança em `first`, `new_term`, `switch` ou `rename`. `legislature_period(n)` dá as datas de cada legislatura. |
| `ExpenseAlertRanking` | Ranking /alertas e Harpia (`ExpenseAlertRankingTool`) | Ranking dos deputados pelos alertas gravados: filtros de ano, UF, partido e gravidade mínima, pontuação ponderada (`SCORE_SQL`), parte do gasto em notas com alerta (`with_shares`) e data do cálculo (`computed_at`). |
| `BillSearch`, `PollSearch` | Listas de projetos e votações e Harpia (`BillListTool`, `PollListTool`) | Busca e filtros das listagens num objeto de consulta (`app/queries`), para a página e a Harpia mostrarem os mesmos registros na mesma ordem (`ORDER`). `results(except:)` ignora um filtro para contar as opções dele. |
| `DeputyOverview` | Perfil do candidato | Resumo de gastos por ano e tipo, maiores fornecedores, votos e projetos de um deputado. `\|\|=` guarda cada conta para não repetir a consulta. |
| `DirectoryMetrics` | Cards de candidatos | Gasto mensal, participação e projetos dos deputados da página, e `expense_percent` para a barra. |
| `PollBreakdown` | Detalhe da votação | Placar total (`tally`), por partido (`by_party`), unanimidade e dissidentes. |
| `MessageProcessorService` | Chat | Salva a pergunta como `pending`, com a página de origem (`PageContextService`), e agenda `ChatResponseJob`. |
| `ChatResponseJob` | Chat (fila `harpia`) | Gera a resposta em segundo plano, mostra o texto aos poucos enquanto a IA escreve (`broadcast_partial`), grava a mensagem da IA (com `out_of_scope` e `actions`), marca a pergunta como `answered` ou `failed`, envia a conversa pelo WebSocket e gera o título depois da resposta. |
| `ChatbotService` | Chat | Conversa com a IA pela gem `ruby_llm`: `SYSTEM_PROMPT` define o comportamento neutro e o formato da resposta (texto, `out_of_scope`, ações, `descobertas` — até 2 perguntas para continuar explorando, escritas pela IA — e `quick_replies`); `call` envia o histórico + a pergunta com as ferramentas (`TOOLS`) e as instruções de página (`page_instructions`: a página atual com as seções dela, os gráficos das páginas de perguntas anteriores só como referência, os gráficos parecidos em mais de uma página, calculados por `PageGuide.shared_sections`, e os deputados e partidos das últimas 3 respostas, com os ids e a pergunta de cada uma, para entender "esses deputados" ou "qual deles"); devolve também os registros que a resposta apresentou (`HarpiaRecords#presented_in`); com um bloco, recebe a resposta em streaming e passa o texto parcial ao bloco (uma falha no streaming só o desliga, sem perder a resposta); `generate_title` cria um título de até 6 palavras. |
| `StreamedContent` | Chat | Junta os pedaços do JSON que a IA envia em streaming e extrai o texto parcial do campo `content`, ignorando escapes que chegaram pela metade. |
| `PageContextService` | Chat | Descreve para a IA a página em que o usuário está, a partir do caminho enviado pelo widget (ex.: `/deputies/12?tab=expenses`), para entender "este deputado" ou "esse alerta". `guide` devolve o `PageGuide` da página, quando ela tem gráficos mapeados. Os filtros vão como na URL, mas com o partido pela sigla (`party=PL`), como a Harpia o informa às ferramentas. |
| `PageGuide` | Chat | Gráficos de cada página (`GUIDES`), para a Harpia reconhecer o gráfico citado ("o mapa de posicionamento", "o quadro azul"). Separa identificar o gráfico de consultar os números: `data` indica a ferramenta com os números (`party_comparison`, `deputy_panorama`, `selection_comparison`), ou `nil` quando ainda não há. As comparações por seleção (`selection: true`) só valem como página atual ou anterior: o conteúdo depende dos escolhidos, então ficam fora dos gráficos conhecidos em qualquer pergunta (`with_data`). `text` é o guia da página atual; `summary`, o resumo das páginas anteriores; `shared_sections`, as seções presentes em mais de uma página (pelo id da seção, como `blocs`), que a Harpia recebe como gráficos parecidos fora de uma página com gráficos. As seções vêm de `PartyComparison::SECTIONS` e `DeputyPanorama::SECTIONS`, os mesmos textos que as páginas exibem. |
| `HarpiaActions` | Chat | Próximos passos oferecidos como botões abaixo da resposta: perguntas que a Harpia responde (`question`) ou páginas da plataforma (`link`). As ferramentas registram as ações; a IA só escolhe pelo id, então não inventa páginas. `pick` recebe o texto da resposta: a continuação de uma lista cortada ("Ver lista completa", ou "Ver mais" quando não há página com a lista) só entra quando o último item aparece na resposta (`shown_if`) e o usuário não está na página da lista; depois vêm as descobertas e as ações escolhidas. No máximo `MAX` = 4; descarta links para a página atual. |
| `HarpiaRecords` | Chat | Deputados e partidos que as ferramentas devolveram numa resposta (`cite_deputy`, `cite_party`). `presented_in` guarda só os que o texto apresentou: o deputado pelo nome ou pelo primeiro nome (sem títulos, quando nenhum outro consultado o tem) e o partido pela sigla, ignorando a sigla que acompanha um deputado ("(PT-PR)") e o tipo de projeto ("PL 1234/2025"). |
| Ferramentas (`app/tools`) | Chat | Consultas somente leitura que a Harpia chama, com os mesmos cálculos das páginas: `SearchPlatformTool` (acha o id pelo nome), `DeputyDetailsTool`, `PartyDetailsTool`, `BillDetailsTool`, `PollDetailsTool`, `CandidateDetailsTool`, `PartyRankingTool` (`PartyComparison`), `PartyComparisonTool` (gráficos da comparação de partidos, uma seção por consulta: blocos, mapa de posicionamento, quem vota com quem e destaques), `DeputyPanoramaTool` (gráficos e tabela do panorama de deputados, com `DeputyPanorama`: blocos, mapa resumido por bloco, destaques e a tabela com os filtros de estado e partido da página — quantos deputados, médias e ranking de governismo), `SelectionComparisonTool` (partidos ou deputados escolhidos lado a lado, com `PartySelectionComparison` e `DeputyComparison`: a tabela com melhor e pior de cada linha e como votaram entre si — afinidade entre partidos, divergência entre deputados —, do par mais parecido ao mais diferente; compara até 10, mais que as páginas, e só oferece o link da página quando o conjunto cabe nela), `DeputyRankingTool` (`DeputyMetrics`), `DeputyStateRankingTool` (bancada ou líder de um indicador por UF), `CandidateRankingTool` (candidatos por estado, partido, gênero etc.), `ExpenseAlertRankingTool`, `BillListTool` e `PollListTool`. Herdam de `ApplicationTool`. |
| `ThemeClassifier` | Tarefa `harpia:themes` | Classifica projetos e votações em temas por palavras-chave (`hospita*` casa com hospital e hospitalar). |
| `ProposalImporter` | Tarefa `harpia:proposals` | Importa propostas de um JSON e liga cada uma às votações que a cumprem. |

### Helpers

| Helper | Função | O que faz |
|---|---|---|
| `ApplicationHelper` | `render_markdown` | Converte Markdown em HTML (Commonmarker) e limpa com `sanitize`. |
| `DeputiesHelper` | `brl`, `percent`, `month_label` | Formata reais ("R$ 1.234,56"), porcentagem ("—" se vazio) e mês ("Jan"). |
| `DeputiesHelper` | `vote_badge_class`, `vote_explanation` | Cor e explicação de cada tipo de voto. |
| `DeputiesHelper` | `info_tip` | Ícone ⓘ com tooltip "como calculamos"; funciona com teclado e sem JavaScript. |
| `DeputiesHelper` | `supplier_document` | Mostra só os dígitos do meio do CPF (LGPD) e formata o CNPJ no padrão 00.000.000/0000-00. |
| `DeputiesHelper` | `cnae_label` | Escreve o CNAE com a descrição, ex.: "01.11-3/01 (cultivo de arroz)". Usado nos textos dos alertas de atividade do fornecedor. |
| `DeputiesHelper` | `social_links`, `camara_expenses_url` | Redes sociais válidas e link para a página de gastos da Câmara. |
| `DeputiesHelper` | `compared_to_average`, `expense_type_label`, `expense_anomaly_text`, `compare_value`, `deputy_tab_path` | Texto "X% acima da média", nome do tipo de despesa, texto de cada alerta, valor da comparação (moeda, %, decimal com uma casa ou número) e link para uma aba. |
| `PartiesHelper` | `party_logo_path`, `party_logo`, `party_badge_link` | Caminho da logo (arquivo local ou API da Câmara), imagem da logo e sigla com link. |
| `PartiesHelper` | `affiliation_party`, `affiliation_event` | Histórico de partidos: a sigla com link (ou "Sem partido" no lugar do `S.PART.` da Câmara, constante `NO_PARTY_LABEL`) e o que aconteceu na data ("Troca de partido", "Saiu do partido", "PRB mudou de nome ou foi incorporado", "Início da 57ª legislatura, por outro partido"…). |
| `PartiesHelper` | `bench_map_weight`, `bench_position`, `party_tab_path` | Intensidade da cor no mapa, posição da bancada numa votação e link para uma aba. |
| `PartiesHelper` | `positioning_chart`, `affinity_cell_style`, `party_sort_link`, `party_sort_aria` | Gráfico de bolhas, cor da matriz de afinidade e cabeçalhos ordenáveis da comparação (`party_sort_aria` também é usado no panorama de deputados). |
| `DeputiesHelper` | `deputy_panorama_sort_link`, `deputy_positioning_chart` | Cabeçalho ordenável da tabela do panorama de deputados (mantém os filtros de estado e partido) e posições dos pontos do mapa governismo × alinhamento ao partido. |
| `PainelHelper` | `bar_percent`, `vote_color`, `unanimous_vote`, `poll_summary` | Largura das barras, cor do voto, voto unânime e descrição sem o placar. |
| `ProposicoesHelper` | `proposicao_label` | "PL 123/2025" ou "Proposição nº ...". |
| `VotacoesHelper` | `poll_result_badge` | Selo Aprovada, Rejeitada ou Texto mantido. |

### Stimulus (JavaScript)

| Controller | Página | O que faz |
|---|---|---|
| `filter-form` | Listagens, ranking de alertas e tabela do panorama de deputados | Envia o filtro sozinho após 300 ms. |
| `compare-selection` | Lista de deputados e lista de partidos da home | Seleciona itens para comparar lado a lado. Recebe a URL da comparação, a chave no `sessionStorage` (`deputy-compare` ou `party-compare`) e o limite (3 deputados, 4 partidos). Guarda o rótulo do botão vindo do servidor (`idleLabel`) para voltar a ele ao cancelar. Antes se chamava `deputy-compare`. |
| `party-map` | Mapa de partidos da home | Troca a bancada exibida ao clicar num estado, põe `?uf=` na URL e preenche a caixa Comparar de cada linha com o id do partido. |
| `tooltip` | Todas com ⓘ | Liga o tooltip do Bootstrap. |
| `chat` | Chat principal e widget | Comportamento comum às duas formas de conversar: envio, aviso de carregamento, bloqueio de envios enquanto a Harpia responde e rolagem até a última mensagem. Enquanto a Harpia escreve, a conversa acompanha o texto se estiver no fim; se o usuário rolar para cima, ela para até ele voltar ao fim. Se a resposta demora a chegar pelo WebSocket, pede ao servidor o estado da conversa. Substituiu o antigo `chat-scroll`. |
| `chat-widget` | Widget | Abre e fecha a janela do widget; a conversa fica no `chat`. |
| `hints` | Várias páginas | Dicas localizadas: o ponto fica até a pessoa tocar em "Entendi" ou usar o recurso; o X desliga as dicas da página e "Rever dicas" no rodapé religa. |
| `onboarding` | Todas | Abre o "Como funciona" na primeira visita; depois, só pelo link do rodapé. |
| `github-team` | Sobre | Busca foto e nome da equipe no GitHub. |

### Tarefas de importação (`lib/tasks`)

| Comando | O que faz |
|---|---|
| `bin/rails db:seed` | Baixa e grava partidos, deputados, candidatos, proposições, gastos, votações e votos. No fim, calcula os alertas de gastos (ExpenseAlerts::RefreshJob) para o ranking. |
| `bin/rails harpia:themes` | Cria o catálogo de temas e reclassifica projetos e votações (`ThemeClassifier`). |
| `bin/rails harpia:proposals[arquivo.json]` | Importa propostas (`ProposalImporter`). |
| `bin/rails partidos:tse` | Atualiza o histórico dos partidos (TSE). |
| `bin/rails partidos:camara` | Logo, líder e bancada na posse de cada partido (API da Câmara). |
| `bin/rails partidos:historico` | Histórico de partidos de cada deputado (API da Câmara, `/deputados/{id}/historico`). Passa os dados pelo `PartyHistory`, apaga e regrava as filiações de cada deputado numa transação com `insert_all` e espera 0,2 s entre pedidos porque a API recusa muitos seguidos. Não roda no `db:seed`: precisa ser chamada à parte. |
| `bin/rails partidos:orientacoes` | Orientação de voto das lideranças em cada votação. |
| `bin/rails proposicoes:cruzar` | Número oficial, autores, projeto de cada votação e temas. |
| `bin/rails harpia:suppliers[limite]` | Consulta na hora (sem a fila) o CNAE e a situação cadastral dos fornecedores pendentes, com limite opcional, e recalcula os alertas de gastos no fim. Demora: uma consulta por CNPJ, cerca de 2,5 horas para a base inteira. Não roda no `db:seed`. |
| `bin/rails harpia:expense_alerts` | Recalcula os alertas de gastos gravados (ranking `/alertas`) de todos os anos. |

## Cores e acessibilidade

A paleta fica em `app/assets/stylesheets/config/_colors.scss` e as cores de tema do Bootstrap em `config/_bootstrap_variables.scss`. Toda combinação de texto e fundo segue o WCAG 2.1 AA, conferido com a mesma fórmula do [verificador de contraste da Accessible Web](https://accessibleweb.com/color-contrast-checker/): 4,5:1 para texto normal, 3:1 para texto grande (18 pt, ou 14 pt em negrito) e para ícones e componentes.

| Cor | Valor | Onde usar | Contraste |
|---|---|---|---|
| `$navy-blue` | #0A1128 | Navbar, hero, rodapé, textos (`text-navy`), `btn-dark` / `text-bg-dark` (`$dark`) | branco sobre ele: 18,7:1 |
| `$royal-blue` | #1C3B87 | Links, checkboxes e foco (`$primary`), mapa de partidos | no branco: 10,4:1 |
| `$gold` | #F08A5D | Fundos de botão (`btn-auth`, `btn-gold`, paginação ativa), chips, barras, bordas e texto **em fundo azul-marinho** | azul-marinho sobre ele: 7,6:1 · no navy: 7,6:1 |
| `$gold-dark` | #B14210 | Texto e ícones dourados **em fundo claro** (`text-gold` fora das áreas azul-marinho) | no branco: 5,7:1 · no fundo da página: 5,3:1 |
| `$success` | #157347 | `text-success`, selos | 5,9:1 |
| `$danger` | #B02A37 | `text-danger`, selos de gravidade alta | 6,5:1 |
| `$warning` | #9A5B00 | `text-warning`, selos de gravidade média | 5,4:1 |

Regras:

- **Nada de texto branco no `$gold`** (2,5:1). Botões e selos dourados usam texto azul-marinho.
- **`text-gold`** vira `$gold-dark` em fundo claro e volta ao `$gold` dentro de `.hero-section`, `.custom-navbar`, `.custom-footer`, `.bg-navy`, `.text-bg-dark` e `.chat-widget-header`.
- **`btn-auth`** vale no site todo (antes só tinha estilo dentro da navbar).
- **Mapa de partidos:** as siglas têm um halo na cor oposta (`paint-order: stroke`), e o texto só fica branco quando o estado passa de 70% de opacidade.
- **Fora da paleta:** cores novas não entram direto no SCSS nem em `style=""`. O `$orange` e o `$red`/`$green`/`$blue` do template não são mais usados.
- **Cores dos blocos:** as cores de governista (#5b48c2), centro (#a8a8a0) e oposição (#c27c00) são uma paleta à parte, só para gráficos. O número dentro da parcela usa branco no governista e azul-marinho nos outros dois.

## Glossário de Rails e Ruby

Métodos que se repetem em várias páginas, com o motivo de uso no projeto.

| Método | O que faz | Exemplo no projeto |
|---|---|---|
| `has_one_attached :photo` | Liga um arquivo (foto) ao registro via Active Storage | Deputy e Candidate têm foto |
| `photo.attached?` | Diz se há foto ligada | Decide entre mostrar a foto ou um ícone |
| `with_attached_photo` | Carrega as fotos de vários registros numa consulta | Listas de candidatos e deputados |
| `cl_image_tag photo.key` | Mostra a imagem guardada no Cloudinary | Cards e perfis |
| `includes(...)` | Carrega associações junto (evita N+1) | `includes(:party)` nas listas |
| `joins(...)` | Faz JOIN no SQL para filtrar ou ordenar por outra tabela | Votos ordenados pela data da votação |
| `where`, `where.not`, `or` | Filtros SQL | Filtros das listagens |
| `group(...).count` / `.sum` | Conta ou soma por grupo | Gastos por mês, votos por tipo |
| `pluck(...)` | Busca só algumas colunas, como array | Lista de anos e estados |
| `distinct` | Remove repetidos | Anos disponíveis |
| `select(:id)` dentro de `where` | Vira subconsulta SQL | `where(id: BillTheme.where(...).select(:bill_id))` |
| `offset` / `limit` | Paginação | 20 ou 24 itens por página (o panorama de deputados pagina em Ruby, 50 por página) |
| `find` / `find_by` | Busca um registro (`find` dá 404 se não achar) | `Deputy.find(params[:id])` |
| `index_by` | Transforma uma lista em hash por uma chave | `index_by(&:json_id)` |
| `presence` | Devolve o valor ou `nil` se vazio | `params[:state].presence` |
| `compact` / `compact_blank` | Remove `nil` / vazios | Montagem dos filtros |
| `&.` | Chama o método só se o objeto não for `nil` | `deputy&.photo` |
| `\|\|=` | Calcula uma vez e guarda | Memoização nos services |
| `send("load_#{@tab}")` | Chama um método pelo nome | Carregar a aba certa |
| `authorize` / `policy_scope` | Checagens do Pundit | Todas as actions |
| `skip_before_action :authenticate_user!` | Libera a action sem login | Páginas públicas |
| `content_for` | Envia conteúdo para o layout | Título da aba e metatags |
| `render partial:, collection:` | Um partial por item | Cards |
| `turbo_frame_tag` | Troca só um pedaço da página | Listas, abas, widget e tabela do panorama de deputados |
| `turbo_stream_from` / `broadcast_replace_to` | Assina um canal do WebSocket / envia um trecho por ele | Resposta da Harpia chegando ao chat e ao widget |
| `perform_later` | Agenda um job em segundo plano (Solid Queue) | `ChatResponseJob`, `Suppliers::FetchJob` |
| `respond_to` + `format.turbo_stream` | Responde HTML ou só um trecho | Chat e widget |
| `link_to`, `button_to`, `mail_to` | Links, botões de formulário e e-mail | Navegação e apagar chat |
| `pluralize` | Plural automático | "3 deputados" |
| `truncate` | Corta textos longos | Ementas nos cards |
| `number_to_currency` | Formata moeda | Base do helper `brl` |
| `sanitize_sql_like` | Escapa `%` e `_` na busca | Campo de busca |

---

Rails app generated with [lewagon/rails-templates](https://github.com/lewagon/rails-templates), created by the [Le Wagon coding bootcamp](https://www.lewagon.com) team.
