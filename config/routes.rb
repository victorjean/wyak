Wyak::Application.routes.draw do
  

  resources :process do
    collection do
      get 'yahoostart'
      get 'espnstart'
      get 'players'
      get 'players_seven'
      get 'logs'
      get 'users'
    end
  end
  
  resources :static do
    collection do
      get 'privacy'
      get 'terms'
      get 'contact'
    end
  end
  
  resources :teams do
    collection do
      get 'update_all'
      get 'showbatters'
      get 'showpitchers'
      get 'manage'
      get 'setup'
      get 'preview_lineup'
      post 'manage'
      post 'set_lineup'
      post 'refresh_lineup'
      post 'start_lineup'
    end
  end
  resources :user do
    collection do
    get 'login'
    post 'login'
    get 'signup'
    post 'signup'
    get 'welcome'
    get 'logout'
    get 'change_password'
    post 'change_password'
    get 'forgot_password'
    post 'forgot_password'
    end
  end
  
  root :to => 'user#index'
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
