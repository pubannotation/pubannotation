Pubann::Application.routes.draw do
  devise_for :users
  get "home/index"
  
  resources :documentations do
    collection do
      get 'category/:name' => 'documentations#category', :as => 'documentations_category'
    end
  end
  
  namespace :relations do
    get :sql
  end
  
  namespace :spans do
    get :sql
  end
  
  resource :sql do
    get :index
  end
  
  resource :users do
    get '/' => 'users#index'
    get :autocomplete_username, :on => :collection
  end

  # Mdocs
  
  resources :docs do
    collection do
      get 'records' => 'docs#records'
      # list sourcedb
      get 'sourcedb' => 'docs#sourcedb_index'
      get 'search' => 'docs#search'
    end  
    member do
      get 'annotations' => 'annotations#annotations_index'
      get 'spans' => 'docs#spans_index', :as => 'spans_index'
      get 'spans/:begin-:end' => 'docs#spans', :as => 'spans'
      get 'spans/:begin-:end/annotations' => 'docs#annotations'    
    end
  end
  
  # routings for /docs/sourcedb....
  scope 'docs',  :as => 'doc' do
    scope 'sourcedb', :as => 'sourcedb' do
      
      scope ':sourcedb' do
        # list sourceids
        get '/' => 'docs#sourceid_index', :as => 'sourceid_index'
      
        scope 'sourceid', :as => 'sourceid' do
          # list docs
          get '/' => 'docs#sourcedb_sourceid_index', :as => 'sourceid_index'
          
          scope ':sourceid' do
            get '/' => 'docs#show', :as =>'show'
            get 'annotations' => 'annotations#annotations_index'
            get 'spans' => 'docs#spans_index', :as => 'spans_index'
            get 'spans/:begin-:end' => 'docs#spans', :as => 'spans'
            get 'spans/:begin-:end/annotations' => 'docs#annotations'
            
            scope 'divs', :as => 'divs' do
              get '/' => 'divs#index', :as => 'index'

              scope ':div_id' do
                get '/' => 'divs#show', :as => 'show'
                get 'annotations' => 'annotations#annotations_index'
                get 'spans' => 'docs#spans_index', :as => 'spans_index'
                get 'spans/:begin-:end' => 'docs#spans', :as => 'spans'
                get 'spans/:begin-:end/annotations' => 'docs#annotations'
              end  
            end    
          end
        end
      end
    end
  end
  
  delete '/associate_projects_projects/:project_id/:associate_project_id' => 'associate_projects_projects#destroy', :as => 'delete_associate_projects_project'
  
  resources :projects do
    get 'spans/sql' => 'spans#sql'
    get 'relations/sql' => 'relations#sql'
    resources :annotations
    resources :associate_maintainers, :only => [:destroy]
    
    member do
      get :search  
    end
    
    collection do
      # auto complete path which use scope and scope argument required :scope_argument param
      get 'autocomplete_project_name/:scope_argument'  => 'projects#autocomplete_project_name', :as => 'autocomplete_project_name'
    end
  end

  resources :projects do
    resources :docs do
      collection do
        post 'project_docs' => 'docs#create_project_docs'
        get 'records' => 'docs#records'
        get 'search' => 'docs#search'
        scope 'sourcedb', :as => 'sourcedb' do
          # list sourcedb
          get '/' => 'docs#sourcedb_index' 
          
          scope ':sourcedb' do
            # list sourceids
            get '/' => 'docs#sourceid_index', :as => 'sourceid_index'
          
            scope 'sourceid', :as => 'sourceid' do
              # list docs
              get '/' => 'docs#sourcedb_sourceid_index', :as => 'sourceid_index'
              
              scope ':sourceid' do
                get '/' => 'docs#show', :as =>'show'
                get 'annotations' => 'annotations#index'
                post 'annotations' => 'annotations#create', :as => 'create_annotatons'
                post 'annotations/generate' => 'annotations#generate', :as => 'generate_annotatons'
                post 'annotations/destroy_all' => 'annotations#destroy_all'
                get 'spans' => 'docs#spans_index', :as => 'spans_index'
                get 'spans/:begin-:end' => 'docs#spans', :as => 'spans'
                get 'spans/:begin-:end/annotations' => 'docs#annotations', :as => 'spans_annotations'
                delete 'delete_project_docs' => 'docs#delete_project_docs'
                
                scope 'divs', :as => 'divs' do
                  get '/' => 'divs#index', :as => 'index'
    
                  scope ':div_id' do
                    get '/' => 'divs#show', :as => 'show'
                    get 'annotations' => 'annotations#index'
                    post 'annotations' => 'annotations#create', :as => 'create_annotatons'
                    post 'annotations/generate' => 'annotations#generate', :as => 'generate_annotatons'
                    post 'annotations/destroy_all' => 'annotations#destroy_all'
                    get 'spans' => 'docs#spans_index', :as => 'spans_index'
                    get 'spans/:begin-:end' => 'docs#spans', :as => 'spans'
                    get 'spans/:begin-:end/annotations' => 'docs#annotations', :as => 'spans_annotations'
                  end  
                end    
              end
            end
          end
        end
      end  
      
      member do
        get 'annotations' => 'annotations#index'
        get 'spans' => 'docs#spans_index', :as => 'spans_index'
        get 'spans/:begin-:end' => 'docs#spans', :as => 'spans'
        get 'spans/:begin-:end/annotations' => 'docs#annotations'    
      end
      resources :annotations do
      end
    end
  end
  
  match '/projects/:project_id/docs/sourcedb/:sourcedb/sourceid/:sourceid/divs/:divs_id/annotations' => 'annotations#index', :via => ["OPTIONS"]
  match '/projects/:project_id/docs/sourcedb/:sourcedb/sourceid/:sourceid/annotations' => 'annotations#index', :via => ["OPTIONS"]

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
