class BillsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  PER_PAGE = 20
  NUMBER_QUERY = %r{\A\s*(PL|PLP|PEC|PDL|PRC|MPV)\s*(?:n[ºo°.]?\s*)?([\d.]+)(?:\s*/\s*(\d{4}))?\s*\z}i

  def index
    base = search(policy_scope(Bill))

    filters = {
      year:  params[:year].presence,
      theme: params[:theme].presence,
      party: params[:party].presence,
      type:  params[:type].presence,
      author: params[:author].presence
    }.compact

    scope = apply(base, filters)

    @theme_counts = BillTheme.where(bill_id: apply(base, filters.except(:theme)).select(:id)).group(:theme_id).count

    @total = scope.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @page = @total_pages if @page > @total_pages

    @bills = scope.includes(:deputy, :party, :themes, bill_authors: :deputy)
                  .order(submission_date: :desc, id: :desc)
                  .offset((@page - 1) * PER_PAGE)
                  .limit(PER_PAGE)
                  .to_a

    @years = Bill.distinct.pluck(:year).compact.sort.reverse

    @types = Bill.where.not(bill_type: nil).distinct.order(:bill_type).pluck(:bill_type)
    @parties = Party.where(id: Bill.select(:party_id)).order(:label)
    @themes = Theme.order(:name).select { |t| @theme_counts[t.id].to_i.positive? || params[:theme].to_s == t.id.to_s }
  end

  def show
    @bill = Bill.includes(:deputy, :party, :themes, :authors).find(params[:id])
    authorize @bill
    @votings = @bill.votings.order(date: :desc)
  end

  private

  def search(scope)
    return scope if params[:q].blank?

    if (match = params[:q].match(NUMBER_QUERY))
      found = scope.where(bill_type: match[1].upcase, number: match[2].delete(".").to_i)
      return match[3] ? found.where(year: match[3].to_i) : found
    end

    scope.where("bills.summary ILIKE :q OR bills.keywords ILIKE :q", q: "%#{Bill.sanitize_sql_like(params[:q].strip)}%")
  end

  def apply(scope, filters)
    filters.reduce(scope) do |current, (key, value)|
      case key
      when :year  then current.where(year: value.to_i)
      when :theme then current.where(id: BillTheme.where(theme_id: value).select(:bill_id))
      when :party then current.where(party_id: value)
      when :type  then current.where(bill_type: value)
      when :author then current.where(id: BillAuthor.where(deputy_id: value).select(:bill_id))
      else current
      end
    end
  end
end
