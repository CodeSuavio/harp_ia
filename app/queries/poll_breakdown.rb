class PollBreakdown
  def initialize(poll)
    @poll = poll
  end

  def tally
    @tally ||= DeputyOverview::VOTE_ORDER.filter_map do |label|
      total = counts.sum { |(_, _, vote), count| vote == label ? count : 0 }
      [label, total] if total.positive?
    end
  end

  def total
    tally.sum { |_, count| count }
  end

  def by_party
    @by_party ||= counts.group_by { |(id, label, _), _| [id, label] }.map do |(id, label), rows|
      votes = rows.to_h { |(_, _, vote), count| [vote, count] }
      ordered = DeputyOverview::VOTE_ORDER.filter_map { |vote| [vote, votes[vote]] if votes[vote].to_i.positive? }

      {
        party_id: id,
        label: label,
        votes: ordered,
        total: ordered.sum { |_, count| count },
        majority: DeputyMetrics.majority_of(votes["Sim"].to_i, votes["Não"].to_i)
      }
    end.sort_by { |row| [-row[:total], row[:label]] }
  end

  private

  def counts
    @counts ||= Vote.where(poll_id: @poll.id)
                    .joins(deputy: :party)
                    .group("parties.id", "parties.label", "votes.vote")
                    .count
  end
end
