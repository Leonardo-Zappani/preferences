Rails.application.routes.draw do
  root "predictions#new"
  resources :predictions, only: [:new, :create, :index, :show] do
    collection do
      post :process_pdf
    end
  end
  get 'dashboard', to: 'dashboard#index'

  namespace :admin do
    resources :predictions
  end

end
