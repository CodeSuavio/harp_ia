class BillsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  PER_PAGE = 20

  def index
    base = policy_scope(Bill)
    if params[:q].present?
      like = "%#{params[:q].strip}%"
      base = base.where("bills.summary ILIKE :q OR bills.keywords ILIKE :q", q: like)
    end

    filters = {
      year:  params[:year].presence,
      theme: params[:theme].presence,
      party: params[:party].presence
    }.compact

    scope = apply(base, filters)

    @theme_counts = BillTheme.where(bill_id: apply(base, filters.except(:theme)).select(:id)).group(:theme_id).count

    @total = scope.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @page = @total_pages if @page > @total_pages

    @bills = scope.includes(:deputy, :party, :themes)
                  .order(submission_date: :desc, id: :desc)
                  .offset((@page - 1) * PER_PAGE)
                  .limit(PER_PAGE)
                  .to_a

    @years = Bill.distinct.pluck(:year).sort.reverse
    @parties = Party.where(id: Bill.select(:party_id)).order(:label)
    @themes = Theme.order(:name).select { |t| @theme_counts[t.id].to_i.positive? || params[:theme].to_s == t.id.to_s }
  end

  def show
    @bill = Bill.includes(:deputy, :party, :themes).find(params[:id])
    authorize @bill
  end

  private

  def apply(scope, filters)
    filters.reduce(scope) do |current, (key, value)|
      case key
      when :year  then current.where(year: value.to_i)
      when :theme then current.where(id: BillTheme.where(theme_id: value).select(:bill_id))
      when :party then current.where(party_id: value)
      else current
      end
    end
  end
end
