Rails.application.routes.draw do
  devise_for :users
  root "searches#new"

  resources :searches, only: [ :new, :create, :show ]

  get "up" => "rails/health#show", as: :rails_health_check
end
