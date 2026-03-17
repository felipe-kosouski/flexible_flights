Rails.application.routes.draw do
  devise_for :users
  root "searches#new"

  resources :searches, only: [ :new, :create, :show ]

  get "history", to: "search_history#index", as: :search_history

  get "up" => "rails/health#show", as: :rails_health_check
end
