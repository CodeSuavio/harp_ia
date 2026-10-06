# Cruza, por tema, as propostas ligadas ao deputado (dele e do partido) com os
# projetos de lei que ele apresentou e as votações em que votou.
#
# Coerência: nas votações ligadas a uma proposta (ProposalPoll), quantos votos
# Sim/Não do deputado foram no sentido que cumpre a proposta.
class DeputyThemeProfile
  # Abaixo disso o indicador de coerência é mostrado com aviso de pouca evidência
  MIN_EVIDENCE = 5

  Row = Struct.new(:theme, :proposals, :bills_count, :votes_count, :coherent, :contrary, keyword_init: true) do
    def evaluated = coherent + contrary
  end

  def initialize(deputy)
    @deputy = deputy
  end

  def proposals
    @proposals ||= Proposal.for_deputy(@deputy).includes(:theme, :party, :deputy).order(:source_kind, :title).to_a
  end

  def bills_by_theme
    @bills_by_theme ||= BillTheme.joins(:bill).where(bills: { deputy_id: @deputy.id }).group(:theme_id).count
  end

  def votes_by_theme
    @votes_by_theme ||= PollTheme.where(poll_id: @deputy.votes.select(:poll_id)).group(:theme_id).count
  end

  # { proposal_id => { coherent:, contrary: } }
  def coherence_by_proposal
    @coherence_by_proposal ||= begin
      votes = @deputy.votes.where(vote: Vote::DECISIVE).pluck(:poll_id, :vote).to_h
      ProposalPoll.where(proposal_id: proposals.map(&:id), poll_id: votes.keys)
                  .pluck(:proposal_id, :poll_id, :favorable_vote)
                  .each_with_object(Hash.new { |h, k| h[k] = { coherent: 0, contrary: 0 } }) do |(proposal_id, poll_id, favorable), result|
                    result[proposal_id][votes[poll_id] == favorable ? :coherent : :contrary] += 1
                  end
    end
  end

  def coherence
    coherent = coherence_by_proposal.values.sum { |row| row[:coherent] }
    contrary = coherence_by_proposal.values.sum { |row| row[:contrary] }
    total = coherent + contrary
    { coherent: coherent, total: total, pct: DeputyMetrics.percentage(coherent, total), conclusive: total >= MIN_EVIDENCE }
  end

  # Temas com alguma proposta, projeto ou voto, começando pelos que têm propostas
  def rows
    by_theme = proposals.group_by(&:theme_id)
    theme_ids = by_theme.keys | bills_by_theme.keys | votes_by_theme.keys

    Theme.where(id: theme_ids).map do |theme|
      theme_proposals = by_theme.fetch(theme.id, [])
      Row.new(
        theme: theme,
        proposals: theme_proposals,
        bills_count: bills_by_theme[theme.id].to_i,
        votes_count: votes_by_theme[theme.id].to_i,
        coherent: theme_proposals.sum { |p| coherence_by_proposal.dig(p.id, :coherent).to_i },
        contrary: theme_proposals.sum { |p| coherence_by_proposal.dig(p.id, :contrary).to_i }
      )
    end.sort_by { |row| [row.proposals.any? ? 0 : 1, -(row.bills_count + row.votes_count), row.theme.position] }
  end

  # Temas em que o deputado mais apresentou projetos
  def top_themes(limit = 3)
    names = Theme.where(id: bills_by_theme.keys).to_h { |theme| [theme.id, theme.name] }
    bills_by_theme.sort_by { |_, count| -count }.first(limit).map { |theme_id, count| [names[theme_id], count] }
  end
end
