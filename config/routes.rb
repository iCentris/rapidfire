Rapidfire::Engine.routes.draw do
  resources :surveys do

    member do
      get "export" 
      get 'results', defaults: { format: :csv }
    end
    collection do 
      get "export"
      get 'import'
      get "new_import"
      post "create_import"
    end 

    resources :questions
    resources :attempts, only: [:new, :create, :edit, :update, :show]
  end

  root :to => "surveys#index"
end
