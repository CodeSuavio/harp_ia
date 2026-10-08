class PollBreakdown
  NON_VOTING = "Artigo 17".freeze

  def self.unanimous_label(pairs)
    considered = pairs.reject { |label, _| label == NON_VOTING }
    considered.first&.first if considered.size == 1
  end

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

  def unanimous
    self.class.unanimous_label(tally)
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
        majority: majority(ordered),
        unanimous: self.class.unanimous_label(ordered),
        cohesion: cohesion(ordered)
      }
    end.sort_by { |row| [-row[:total], row[:label]] }
  end

  def dissidents
    majorities = by_party.to_h { |row| [row[:party_id], row[:majority]] }
    Vote.where(poll_id: @poll.id, vote: Vote::DECISIVE)
        .includes(deputy: :party)
        .filter_map do |vote|
          majority = majorities[vote.deputy.party_id]
          [vote, majority] if Vote::DECISIVE.include?(majority) && vote.vote != majority
        end
        .sort_by { |vote, _| [vote.deputy.party.label, vote.deputy.name] }
  end

  private

  def majority(pairs)
    considered = pairs.reject { |label, _| label == NON_VOTING }
    top = considered.map(&:last).max
    leaders = considered.select { |_, count| count == top }
    leaders.size == 1 ? leaders.first.first : nil
  end

  def cohesion(pairs)
    considered = pairs.reject { |label, _| label == NON_VOTING }
    total = considered.sum { |_, count| count }
    top = considered.map { |_, count| count }.max.to_i
    DeputyMetrics.percentage(top, total)
  end

  def counts
    @counts ||= Vote.where(poll_id: @poll.id)
                    .joins(deputy: :party)
                    .group("parties.id", "parties.label", "votes.vote")
                    .count
  end
end
