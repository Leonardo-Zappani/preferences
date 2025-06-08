Rails.application.routes.draw do
  root "predictions#new"
  resources :predictions, only: [:new, :create, :index]
  get 'dashboard', to: 'dashboard#index'

  namespace :admin do
    resources :predictions
  end

end
