class PagesController < ApplicationController
  # Adicione :about e :contact na lista de páginas públicas
  skip_before_action :authenticate_user!, only: [ :home, :about, :contact ]

  def home
    @candidates = policy_scope(Candidate).includes(:party).order(:ballot_name)
    @states = @candidates.map(&:state_label).compact.uniq.sort

    # Agregados por deputado (indexados pelo json_id, que é o current_deputy_id do candidato)
    deputy_ids = Deputy.pluck(:json_id, :id).to_h
    by_json_id = ->(counts) { deputy_ids.transform_values { |id| counts[id] }.compact }

    @expenses_by_deputy = by_json_id.(Expense.group(:deputy_id).sum(:net_amount))
    @max_expense = @expenses_by_deputy.values.max.to_f

    @votes_by_deputy = by_json_id.(Vote.group(:deputy_id).count)
    @bills_by_deputy = by_json_id.(Bill.group(:deputy_id).count)
    @total_polls = Vote.distinct.count(:poll_id)
  end

  def about
    # Lógica da página sobre nós (se necessário)
  end

  def contact
    # Lógica da página de contato (se necessário)
  end
end
