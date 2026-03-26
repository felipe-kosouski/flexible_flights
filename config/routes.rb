Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }
  root "pages#home"

  get "check-email", to: "pages#check_email", as: :check_email

  resources :searches, only: [ :new, :create, :show ]

  get "history", to: "search_history#index", as: :search_history

  resource :profile, only: [ :show, :update, :destroy ], controller: "profile"

  resources :payments, only: [ :new, :create ] do
    collection do
      get :success
    end
  end

  post "/stripe/webhooks", to: "stripe_webhooks#create"

  get "up" => "rails/health#show", as: :rails_health_check
end
