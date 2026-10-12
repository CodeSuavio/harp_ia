class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  include Pundit::Authorization

  # Condiciona pelo nome da ação (em vez de only/except: :index) porque nem
  # todo controller tem index, e o Rails acusa erro nesse caso (ex.: messages).
  after_action :verify_authorized, unless: -> { skip_pundit? || index_action? }
  after_action :verify_policy_scoped, if: :index_action?, unless: :skip_pundit?

  def configure_permitted_parameters
    # For additional fields in app/views/devise/registrations/new.html.erb
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name])

    # For additional in app/views/devise/registrations/edit.html.erb
    devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name])
  end

  private

  def index_action?
    action_name == "index"
  end

  def skip_pundit?
    devise_controller? || params[:controller] =~ /^pages$/
  end
end
