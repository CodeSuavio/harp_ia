Rails.application.routes.draw do
  devise_for :users

  # Página inicial principal
  root to: "pages#home"

  # Páginas institucionais (Sobre Nós e Contato)
  get "sobre", to: "pages#about", as: :about
  get "contato", to: "pages#contact", as: :contact

  # ==========================================
  # ÁREA PÚBLICA (Apenas Leitura)
  # ==========================================
  resources :deputies, only: [:index, :show] do
    get :compare, on: :collection
    resources :expenses, only: [:index]
  end

  resources :parties, only: [:index, :show] do
    get :compare, on: :collection
  end
  resources :bills, only: [:index, :show]
  resources :candidates, only: [:index, :show]

  resources :polls, only: [:index, :show]

  # Ranking de deputados pelos alertas de gastos
  get "alertas", to: "expense_alerts#index", as: :expense_alerts

  # ==========================================
  # ÁREA LOGADA (Utilizadores Autenticados)
  # ==========================================
  resources :chats, only: [:index, :show, :create, :destroy] do
    resources :messages, only: [:create]
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
