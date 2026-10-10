class PagesController < ApplicationController
  # Adicione :about e :contact na lista de páginas públicas
  skip_before_action :authenticate_user!, only: [ :home, :about, :contact ]

  def home
    @candidates = policy_scope(Candidate).includes(:party).with_attached_photo.order(:ballot_name)
    @states = @candidates.map(&:state_label).compact.uniq.sort

    # Agregados por deputado (indexados pelo json_id, que é o current_deputy_id do candidato)
    deputy_ids = Deputy.pluck(:json_id, :id).to_h
    by_json_id = ->(counts) { deputy_ids.transform_values { |id| counts[id] }.compact }

    @expenses_by_deputy = by_json_id.(Expense.group(:deputy_id).sum(:net_amount))
    @max_expense = @expenses_by_deputy.values.max.to_f

    @votes_by_deputy = by_json_id.(Vote.group(:deputy_id).count)
    @bills_by_deputy = by_json_id.(Bill.group(:deputy_id).count)
    @polls_by_deputy = by_json_id.(polls_during_term_by_deputy)
  end

  def about
    # Lógica da página sobre nós (se necessário)
  end

  def contact
    # Lógica da página de contato (se necessário)
  end

  private

  # Votações que ocorreram enquanto cada deputado estava em exercício.
  # Não temos as datas de mandato, então o período é aproximado pela primeira
  # e última votação em que o deputado registrou voto (cobre suplentes que
  # assumiram ou saíram no meio da legislatura).
  def polls_during_term_by_deputy
    sql = <<~SQL
      WITH terms AS (
        SELECT votes.deputy_id, MIN(polls.date) AS first_date, MAX(polls.date) AS last_date
        FROM votes
        JOIN polls ON polls.id = votes.poll_id
        GROUP BY votes.deputy_id
      ),
      voted_polls AS (
        SELECT id, date FROM polls WHERE id IN (SELECT DISTINCT poll_id FROM votes)
      )
      SELECT terms.deputy_id, COUNT(voted_polls.id) AS total
      FROM terms
      JOIN voted_polls ON voted_polls.date BETWEEN terms.first_date AND terms.last_date
      GROUP BY terms.deputy_id
    SQL

    ActiveRecord::Base.connection.select_rows(sql).to_h { |deputy_id, total| [deputy_id.to_i, total.to_i] }
  end
end
