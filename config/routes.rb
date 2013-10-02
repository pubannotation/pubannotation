Pubann::Application.routes.draw do
  devise_for :users
  get "home/index"
  
  namespace :spans do
    get :sql
  end
  
  resource :sql do
    get :index
  end
  
  resource :users do
   get :autocomplete_username, :on => :collection
  end
  
  resources :docs

  resources :projects_sprojects, :only => [:destroy]
  resources :sprojects do
    resources :pmdocs do
      member do
        # spans
        get 'spans/:begin-:end/' => 'pmdocs#spans', :as => 'spans'
        # annotations
        get 'spans/:begin-:end/annotations' => 'pmdocs#annotations', :as => 'spans_annotation'
      end
      resources :annotations do
        collection do
          post :destroy_all
        end
      end
    end
    
    resources :pmcdocs do
      resources :divs do
        member do
          # spans
          get 'spans/:begin-:end/' => 'divs#spans', :as => 'spans'
          # annotations
          get 'spans/:begin-:end/annotations' => 'divs#annotations', :as => 'spans_annotation'
        end
      end
    end
    
    member do
      get :search  
    end
    
    collection do
      # auto complete path which use scope and scope argument required :scope_argument param
      get 'autocomplete_pmdoc_sourceid/:scope_argument'   => 'sprojects#autocomplete_pmdoc_sourceid',  :as => 'autocomplete_pmdoc_sourceid'
      get 'autocomplete_pmcdoc_sourceid/:scope_argument'  => 'sprojects#autocomplete_pmcdoc_sourceid', :as => 'autocomplete_pmcdoc_sourceid'
    end
  end
  
  resources :projects do
    resources :docs
    resources :annotations
    resources :associate_maintainers, :only => [:destroy]
    
    member do
      get :search  
    end
    
    collection do
      # auto complete path which use scope and scope argument required :scope_argument param
      get 'autocomplete_pmdoc_sourceid/:scope_argument'   => 'projects#autocomplete_pmdoc_sourceid',  :as => 'autocomplete_pmdoc_sourceid'
      get 'autocomplete_pmcdoc_sourceid/:scope_argument'  => 'projects#autocomplete_pmcdoc_sourceid', :as => 'autocomplete_pmcdoc_sourceid'
      get 'autocomplete_project_name/:scope_argument'  => 'projects#autocomplete_project_name', :as => 'autocomplete_project_name'
    end
  end

  resources :pmdocs do
    collection do
      get :search
      get :autocomplete_doc_sourceid
    end
    
    member do
      get 'spans/:begin-:end' => 'pmdocs#spans', :as => 'spans'
      get 'spans/:begin-:end/annotations' => 'pmdocs#annotations'
    end
    
    resources :projects do
      resources :annotations
    end
  end

  resources :pmcdocs do
    collection do
      get :search
      get :autocomplete_doc_sourceid
    end
    
    resources :divs do
      member do
        # spans
        get 'spans/:begin-:end' => 'divs#spans', :as => 'spans'
        # annotations
        get 'spans/:begin-:end/annotations' => 'divs#annotations'
      end
      resources :projects do
        resources :annotations
      end
    end
  end

  resources :projects do
    resources :pmdocs do
      member do
        # spans
        get 'spans/:begin-:end/' => 'pmdocs#spans', :as => 'spans'
        # annotations
        get 'spans/:begin-:end/annotations' => 'pmdocs#annotations', :as => 'spans_annotation'
      end
      resources :annotations do
        collection do
          post :destroy_all
        end
      end
    end
  end

  resources :projects do
    resources :pmcdocs do
      resources :divs do
        member do
          # spans
          get 'spans/:begin-:end/' => 'divs#spans', :as => 'spans'
          # annotations
          get 'spans/:begin-:end/annotations' => 'divs#annotations', :as => 'spans_annotation'
        end
        resources :annotations do
          collection do
            post :destroy_all
          end
        end
      end
    end
  end

  #match '/projects/:project_id/pmdocs/:pmdoc_id/annotations' => 'annotations#index', :via => ["OPTIONS"]

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
  root :to => 'home#index'
  match '/' => 'home#index', :as => :home

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
