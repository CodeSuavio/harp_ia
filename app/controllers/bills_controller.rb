class BillsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]

  PER_PAGE = 20

  def index
    # Mesma busca da Harpia (BillListTool)
    search = BillSearch.new(policy_scope(Bill), query: params[:q], year: params[:year], theme: params[:theme],
                                                party: params[:party], type: params[:type], author: params[:author])
    scope = search.results

    @theme_counts = BillTheme.where(bill_id: search.results(except: :theme).select(:id)).group(:theme_id).count

    @total = scope.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @page = @total_pages if @page > @total_pages

    @bills = scope.includes(:deputy, :party, :themes, bill_authors: :deputy)
                  .order(BillSearch::ORDER)
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
end
