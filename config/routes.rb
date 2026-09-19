  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  # CHAT: provisório
  # resources :chats, only: [:index, :show, :create] do
  #   resources :messages, only: [:create]
  # end
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  # Defines the root path route ("/")
  # root "posts#index"
  
  Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  # ==========================================
  # ÁREA PÚBLICA (Apenas Leitura)
  # ==========================================
  resources :deputies, only: [:index, :show] do
    resources :expenses, only: [:index]
  end

  resources :parties, only: [:index, :show]
  resources :bills, only: [:index, :show]
  resources :candidates, only: [:index, :show]

  resources :polls, only: [:index, :show] do
    # Rota aninhada para ver os votos de um projeto específico (/polls/:poll_id/votes)
    resources :votes, only: [:index]
  end

  # ==========================================
  # ÁREA LOGADA (Utilizadores Autenticados)
  # ==========================================
  resources :chats, only: [:index, :show, :create] do
    resources :messages, only: [:create]
  end

  # ==========================================
  # ÁREA ADMINISTRATIVA (CRUD Completo)
  # ==========================================
  # URLs geradas: /admin/deputies/new, /admin/parties/1/edit, etc.
  namespace :admin do
    resources :deputies
    resources :expenses
    resources :parties
    resources :bills
    resources :polls
    resources :votes
    resources :candidates
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
