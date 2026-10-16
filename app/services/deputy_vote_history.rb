# Votos de um deputado como a aba Votações do perfil mostra: os temas das
# votações e o histórico, das mais recentes para as mais antigas, com o voto
# da maioria do partido em cada uma.
#
# Usado pela página (DeputiesController#load_votes) e pela Harpia
# (DeputyDetailsTool), para os números serem os mesmos nas duas.
class DeputyVoteHistory
  # Filtro dos votos contra a maioria do partido
  AGAINST_PARTY = "against_party".freeze

  def initialize(deputy, stats = DeputyStats.new(deputy))
    @deputy = deputy
    @stats = stats
  end

  # [[tema, votações com voto do deputado]]
  def themes
    counts = DeputyThemeProfile.new(@deputy).votes_by_theme
    Theme.where(id: counts.keys).map { |theme| [theme, counts[theme.id]] }
  end

  # Votos do deputado, opcionalmente só os de um tipo (Sim, Não...), só os
  # contra o partido (AGAINST_PARTY) ou só os de um tema
  def votes(filter: nil, theme: nil)
    votes = @deputy.votes.joins(:poll).includes(poll: :bill)
    if filter == AGAINST_PARTY
      votes = votes.where(poll_id: against_party_ids)
    elsif filter
      votes = votes.where(vote: filter)
    end
    votes = votes.where(poll_id: PollTheme.where(theme: theme).select(:poll_id)) if theme
    votes.order("polls.date DESC, votes.id DESC")
  end

  # { poll_id => voto da maioria do partido, sem o próprio deputado }
  def majorities(poll_ids)
    @stats.party_majorities(poll_ids)
  end

  def against_party_ids
    @against_party_ids ||= @stats.against_party_poll_ids
  end
end
