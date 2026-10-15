# robots.txt e sitemap.xml montados com o endereço em que o site está rodando
class SeoController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_after_action :verify_authorized, raise: false
  skip_after_action :verify_policy_scoped, raise: false

  def robots
    expires_in 1.day, public: true
    render plain: <<~TXT
      User-agent: *
      Disallow: /chats
      Disallow: /users
      Disallow: /up

      Sitemap: #{request.base_url}/sitemap.xml
    TXT
  end

  def sitemap
    expires_in 6.hours, public: true
    @urls = [root_url, deputies_url, compare_deputies_url, compare_parties_url, candidates_url,
             polls_url, bills_url, expense_alerts_url, about_url, contact_url]
    @urls += Deputy.ids.map { |id| deputy_url(id) }
    @urls += Party.ids.map { |id| party_url(id) }
    @urls += Poll.ids.map { |id| poll_url(id) }
    @urls += listed_ids(Bill).map { |id| bill_url(id) }
    @urls += Candidate.ids.map { |id| candidate_url(id) }
  end

  private

  # Os mesmos registros que a listagem mostra
  def listed_ids(model)
    policy_scope(model).ids
  rescue Pundit::NotDefinedError
    model.ids
  end
end
