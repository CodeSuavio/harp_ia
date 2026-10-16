# Seções das páginas de um registro (perfil do deputado, página do partido,
# votação) e do mapa de partidos, no formato do PageGuide: título (o mesmo da
# página), o que a seção mostra (chart), como ler (reading) e de onde vêm os
# números (data: a ferramenta e a seção dela). heading: false quando a seção
# não tem título na página (ex.: os cartões do topo) e o título só a nomeia.
#
# As páginas de comparação guardam as seções nos próprios serviços
# (PartyComparison::SECTIONS etc.). Estas ficam juntas aqui porque cada página
# reúne dados de vários serviços; o teste de páginas confere que os títulos
# continuam os mesmos das views.
module PageSections
  DEPUTY_DETAILS = "deputy_details com o deputy_id".freeze
  PARTY_DETAILS = "party_details com o party_id".freeze

  # Perfil do deputado, por aba (DeputiesController::TABS)
  DEPUTY = {
    "overview" => {
      "profile_cards" => {
        title: "Indicadores do deputado",
        heading: false,
        chart: "cartões com o gasto do ano, os projetos de lei, a participação nas votações e o alinhamento com o " \
               "partido",
        data: DEPUTY_DETAILS
      },
      "party_history" => {
        title: "Histórico de partidos",
        chart: "linha do tempo com o partido em cada período como deputado federal",
        reading: "Mudanças de nome e fusões de partido não contam como troca",
        data: "#{DEPUTY_DETAILS} e section historico_de_partidos"
      }
    },
    "expenses" => {
      "expense_cards" => {
        title: "Uso da cota",
        chart: "cartões com o total gasto no ano, o uso da cota, o ranking de gastos, o gasto médio mensal e as " \
               "médias da bancada do estado e do partido",
        data: "#{DEPUTY_DETAILS} (e o ano da página)"
      },
      "monthly" => {
        title: "Gastos por mês",
        chart: "barras com o gasto de cada mês do ano",
        data: "#{DEPUTY_DETAILS} e section gastos_por_mes"
      },
      "by_type" => {
        title: "Por tipo de despesa",
        chart: "barras com o gasto em cada tipo de despesa, com destaque quando passa da média da Câmara no tipo",
        data: DEPUTY_DETAILS
      },
      "alerts" => {
        title: "Gastos fora do padrão",
        chart: "lista de alertas de gastos, com a gravidade e o critério",
        reading: "Fugir do padrão não é irregularidade por si só",
        data: DEPUTY_DETAILS
      },
      "suppliers" => {
        title: "Principais fornecedores",
        chart: "tabela com os 10 fornecedores que mais receberam no ano, com o número de notas e o total",
        data: "#{DEPUTY_DETAILS} e section fornecedores"
      },
      "notes" => {
        title: "Despesas",
        chart: "lista das notas do ano, das mais recentes para as mais antigas",
        data: "#{DEPUTY_DETAILS} e section despesas"
      }
    },
    "votes" => {
      "vote_cards" => {
        title: "Participação",
        chart: "cartões com a participação nas votações, o alinhamento com o partido, os votos contra o partido e a " \
               "distribuição dos votos (Sim, Não, abstenção...)",
        data: DEPUTY_DETAILS
      },
      "vote_themes" => {
        title: "Votações por tema",
        chart: "temas dos projetos votados, com quantas votações de cada tema o deputado registrou voto",
        data: "#{DEPUTY_DETAILS} e section votacoes_por_tema"
      },
      "vote_history" => {
        title: "Histórico de votações",
        chart: "lista das votações, das mais recentes para as mais antigas, com o voto do deputado e se ele votou " \
               "com ou contra o partido",
        data: "#{DEPUTY_DETAILS} e section votacoes_recentes"
      }
    },
    "bills" => {
      "bill_cards" => {
        title: "Projetos apresentados",
        chart: "cartões com o total de projetos de lei e os temas mais frequentes",
        data: DEPUTY_DETAILS
      },
      "bill_list" => {
        title: "Projetos de lei",
        chart: "lista dos projetos de lei do deputado, dos mais recentes para os mais antigos",
        data: DEPUTY_DETAILS
      }
    },
    "elections" => {
      "candidacy" => {
        title: "Eleições 2026",
        chart: "dados da candidatura de 2026: nome de urna, número, partido, estado e situação",
        data: "#{DEPUTY_DETAILS} (candidatura_2026) e candidate_details"
      }
    }
  }.freeze

  # Página do partido, por aba (PartiesController::TABS)
  PARTY = {
    "overview" => {
      "party_cards" => {
        title: "Indicadores do partido",
        heading: false,
        chart: "cartões com os deputados na Câmara, os estados com bancada, a coesão nas votações e os candidatos " \
               "em 2026",
        data: PARTY_DETAILS
      },
      "bench" => {
        title: "Bancada na Câmara",
        chart: "mapa do Brasil com os deputados do partido em cada estado e a lista dos deputados",
        data: "#{PARTY_DETAILS} (bancada.por_estado)"
      },
      "party_record" => {
        title: "Histórico",
        chart: "registro no TSE, siglas anteriores, bancada na posse da legislatura, fusões e incorporações e a " \
               "federação na Câmara",
        data: "#{PARTY_DETAILS} (historico)"
      }
    },
    "votes" => {
      "cohesion" => {
        title: "Coesão nas votações",
        chart: "quanto a bancada vota unida e as votações em que ela mais se dividiu",
        data: PARTY_DETAILS
      },
      "leadership" => {
        title: "Orientação da liderança",
        chart: "quanto a bancada segue a orientação do líder e quando a contrariou",
        data: PARTY_DETAILS
      },
      "party_affinity" => {
        title: "Afinidade com outros partidos",
        chart: "partidos com que a bancada mais vota junto e mais vota diferente",
        data: PARTY_DETAILS
      },
      "contested" => {
        title: "Como votou nas votações mais disputadas",
        chart: "votações com o placar mais apertado na Câmara e como a bancada votou",
        data: "#{PARTY_DETAILS} (votacoes_mais_disputadas)"
      },
      "party_dissidents" => {
        title: "Quem mais vota contra o partido",
        chart: "deputados do partido com menor alinhamento à maioria da bancada",
        data: PARTY_DETAILS
      }
    },
    "expenses" => {
      "bench_expense_cards" => {
        title: "Gastos da bancada",
        heading: false,
        chart: "cartões com o gasto da bancada no ano, o gasto por deputado por mês e a média da Câmara",
        data: PARTY_DETAILS
      },
      "top_spenders" => {
        title: "Quem mais gasta por mês",
        chart: "deputados do partido com maior gasto médio mensal",
        data: PARTY_DETAILS
      },
      "by_type" => {
        title: "Principais tipos de gasto",
        chart: "tipos de despesa com mais gasto da bancada",
        data: PARTY_DETAILS
      }
    },
    "bills" => {
      "party_bills" => {
        title: "Projetos de lei",
        chart: "total de projetos apresentados por deputados quando estavam no partido, por tipo",
        data: PARTY_DETAILS
      },
      "recent_bills" => {
        title: "Mais recentes",
        chart: "lista dos projetos mais recentes do partido",
        data: "bill_list com o partido"
      },
      "bill_themes" => {
        title: "Temas mais frequentes",
        chart: "barras com os temas dos projetos do partido",
        data: PARTY_DETAILS
      }
    },
    "candidates" => {
      "profile" => {
        title: "Perfil das candidaturas",
        chart: "distribuição dos candidatos de 2026 por gênero, cor ou raça e escolaridade",
        data: "#{PARTY_DETAILS} (candidatos_2026)"
      },
      "candidate_states" => {
        title: "Candidatos por estado",
        chart: "mapa e lista com os candidatos do partido em cada estado",
        data: "candidate_ranking agrupado por estado, com o partido"
      }
    }
  }.freeze

  # Mapa de partidos da página inicial e da lista de partidos
  PARTY_MAP = {
    "map" => {
      title: "Escolha um estado",
      chart: "mapa do Brasil em que a cor de cada estado mostra o tamanho da bancada dele na Câmara",
      data: "deputy_state_ranking sem criterion"
    },
    "map_parties" => {
      title: "Visão nacional",
      chart: "lista dos partidos com as cadeiras de cada um na Câmara ou, com um estado escolhido, no estado",
      data: "party_ranking com criterion seats e, para um estado, state"
    },
    "compare_parties" => {
      title: "Escolher partidos",
      chart: "botão da lista de partidos que mostra a caixa “Comparar” em cada partido; com 2 a 4 marcados, o " \
             "botão Comparar abre a comparação lado a lado",
      data: "selection_comparison com os partidos"
    }
  }.freeze

  # Lista de deputados: as funcionalidades da página
  DEPUTIES_LIST = {
    "deputy_filters" => {
      title: "Filtros da lista",
      heading: false,
      chart: "busca pelo nome e filtros por estado, partido e situação eleitoral, com ordenação por nome ou por " \
             "indicador (gasto, projetos, participação, alinhamento e votos contra o partido)",
      data: "deputy_ranking com state e party"
    },
    "compare_deputies" => {
      title: "Comparar deputados",
      chart: "botão abaixo dos filtros que mostra a caixa “Comparar” em cada cartão; com 2 ou 3 deputados " \
             "marcados, o botão Comparar abre a comparação lado a lado. O atalho com o mesmo nome leva ao panorama " \
             "de todos os deputados",
      data: "selection_comparison com os deputados"
    }
  }.freeze

  # Página de alertas de gastos
  ALERTS = {
    "alert_ranking" => {
      title: "Alertas de gastos",
      chart: "ranking dos deputados com mais gastos fora do padrão, pela gravidade dos alertas, com filtros de ano, " \
             "estado, partido e gravidade mínima; cada deputado leva às notas com alerta na aba Gastos do perfil",
      reading: "Alertas indicam gastos fora do padrão segundo critérios estatísticos; não são prova de irregularidade",
      data: "expense_alert_ranking"
    }
  }.freeze

  # Recursos presentes em todas as páginas
  SITE = {
    "hints" => {
      title: "Rever dicas",
      chart: "pontos laranja em algumas partes das páginas que abrem uma dica sobre aquele elemento; o X do balão " \
             "desliga as dicas da página, e o link “Rever dicas” no rodapé mostra todas de novo"
    },
    "onboarding" => {
      title: "Como funciona",
      chart: "apresentação em passos das áreas da plataforma (deputados, candidatos, partidos, votações, projetos e " \
             "a Harpia), aberta na primeira visita e pelo link “Como funciona” no rodapé"
    },
    "info_icon" => {
      title: "Ícone de informação",
      heading: false,
      chart: "ícone (i) ao lado dos números que mostra, ao passar o mouse ou tocar, como cada um é calculado"
    }
  }.freeze

  # Página de uma votação
  POLL = {
    "result" => {
      title: "Resultado geral",
      chart: "placar da votação (Sim, Não, abstenção...) e a orientação do Governo",
      data: "poll_details com o poll_id"
    },
    "party_votes" => {
      title: "Como cada partido votou",
      chart: "voto de cada bancada, com a orientação da liderança e se a maioria a seguiu",
      data: "poll_details com o poll_id (por_partido)"
    },
    "poll_dissidents" => {
      title: "Votaram contra a maioria do próprio partido",
      chart: "deputados que votaram diferente da maioria da bancada nesta votação",
      data: "poll_details com o poll_id"
    },
    "state_votes" => {
      title: "Como votou cada estado",
      chart: "votos Sim e Não dos deputados de cada estado",
      data: "poll_details com o poll_id (por_estado)"
    }
  }.freeze
end
