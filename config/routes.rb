Pubann::Application.routes.draw do
  devise_for :users
  get "home/index"

  resources :notices, only: :destroy do
    collection do
      get 'delete_project_notices/:id' => 'notices#delete_project_notices', as: 'delete_project'
    end
  end
  
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

  resources :docs do
    collection do
      get 'records' => 'docs#records'
      # list sourcedb
      get 'sourcedb' => 'docs#sourcedb_index'
      get 'search' => 'docs#search'
      get 'index_rdf' => 'docs#index_rdf'

      get :autocomplete_sourcedb
    end  
    member do
      get 'annotations' => 'annotations#doc_annotations_index'
      get 'spans' => 'spans#spans_index', :as => 'spans_index'
      # get 'spans/:begin-:end' => 'docs#spans', :as => 'spans'
      get 'spans/:begin-:end' => 'spans#span_show', :as => 'span_show'
      get 'spans/:begin-:end/annotations' => 'annotations#doc_annotations_index'    
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
            get 'annotations' => 'annotations#doc_annotations_index'
            get 'annotations/visualize' => 'annotations#doc_annotations_visualize'
            # post 'annotations' => 'annotations#create'
            get 'uptodate' => 'docs#uptodate'
            get 'index_rdf' => 'docs#index_rdf'
            get 'spans' => 'spans#doc_spans_index'
            get 'spans/:begin-:end' => 'spans#doc_span_show', :as => 'span_show'
            get 'spans/:begin-:end/annotations' => 'annotations#doc_annotations_index'
            get 'spans/:begin-:end/annotations/visualize' => 'annotations#doc_annotations_visualize'
            
            scope 'divs', :as => 'divs' do
              get '/' => 'divs#index', :as => 'index'
              get 'search' => 'divs#search'

              scope ':divid' do
                get '/' => 'divs#show', :as => 'show'
                get 'annotations' => 'annotations#div_annotations_index'
                get 'annotations/visualize' => 'annotations#div_annotations_visualize'
                # post 'annotations' => 'annotations#create'
                get 'spans' => 'spans#div_spans_index'
                get 'spans/:begin-:end' => 'spans#div_span_show', :as => 'span_show'
                get 'spans/:begin-:end/annotations' => 'annotations#div_annotations_index'
                get 'spans/:begin-:end/annotations/visualize' => 'annotations#div_annotations_visualize'
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
    get 'annotations.zip' => 'annotations#project_annotations_zip', :as => 'annotations_zip'
    get 'annotations.zip/create' => 'annotations#create_project_annotations_zip', :as => 'create_annotations_zip'
    post 'annotations.zip' => 'annotations#create_from_zip', :as => 'create_annotations_from_zip'
    get 'delete_annotations_zip' => 'annotations#delete_project_annotations_zip', :as => 'delete_annotations_zip'
    get 'annotations.rdf' => 'annotations#project_annotations_rdf', :as => 'annotations_rdf'
    get 'annotations.rdf/create' => 'annotations#create_project_annotations_rdf', :as => 'create_annotations_rdf'
    get 'delete_annotations_rdf' => 'annotations#delete_project_annotations_rdf', :as => 'delete_annotations_rdf'
    get 'notices' => 'notices#index'
    get 'tasks' => 'notices#tasks'
    resources :annotations
    resources :associate_maintainers, :only => [:destroy]
    
    member do
      get :search
      get 'index_rdf' => 'projects#index_project_annotations_rdf'
    end
    
    collection do
      # auto complete path which use scope and scope argument required :scope_argument param
      get 'autocomplete_project_name/:scope_argument'  => 'projects#autocomplete_project_name', :as => 'autocomplete_project_name'
      get 'autocomplete_project_author'  => 'projects#autocomplete_project_author', :as => 'autocomplete_project_author'
      get 'zip_upload' => 'projects#zip_upload'
      post 'create_from_zip' => 'projects#create_from_zip'
    end
  end

  resources :projects do
    post 'annotations' => 'annotations#create'
    delete 'annotations' => 'projects#destroy_annotations', as: 'destroy_annotations'

    resources :docs do
      collection do
        post 'add' => 'docs#add'
        # post 'project_docs' => 'docs#create_project_docs'
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
                get '/' => 'docs#project_doc_show', :as =>'show'
                get 'annotations' => 'annotations#project_doc_annotations_index'
                get 'annotations/visualize' => 'annotations#doc_annotations_visualize'
                post 'annotations' => 'annotations#create'
                post 'annotations/generate' => 'annotations#generate'
                delete 'annotations' => 'annotations#destroy', as: 'destroy_annotations'
                get 'spans' => 'spans#project_doc_spans_index', :as => 'spans_index'
                get 'spans/:begin-:end' => 'spans#project_doc_span_show', :as => 'span_show'
                get 'spans/:begin-:end/annotations' => 'annotations#project_doc_annotations_index', :as => 'span_annotations'
                post 'spans/:begin-:end/annotations' => 'annotations#create'
                delete 'spans/:begin-:end/annotations' => 'annotations#destroy', as: 'destroy_annotations_in_span'
                delete 'delete_project_doc' => 'docs#delete_project_doc'
                
                scope 'divs', :as => 'divs' do
                  get '/' => 'divs#project_divs_index', :as => 'index'
                  get 'annotations/visualize' => 'annotations#div_annotations_visualize'
                  get 'search' => 'divs#search'
    
                  scope ':divid' do
                    get '/' => 'divs#project_div_show', :as => 'show'
                    get 'annotations' => 'annotations#project_div_annotations_index'
                    get 'annotations/visualize' => 'annotations#div_annotations_visualize'
                    post 'annotations' => 'annotations#create'
                    post 'annotations/generate' => 'annotations#generate'
                    delete 'annotations' => 'annotations#destroy', as: 'destroy_annotations'
                    get 'spans' => 'spans#project_div_spans_index', :as => 'spans_index'
                    get 'spans/:begin-:end' => 'spans#project_div_span_show', :as => 'span_show'
                    get 'spans/:begin-:end/annotations' => 'annotations#project_div_annotations_index', :as => 'span_annotations'
                    post 'spans/:begin-:end/annotations' => 'annotations#create'
                    delete 'spans/:begin-:end/annotations' => 'annotations#destroy', as: 'destroy_annotations_in_span'
                  end  
                end    
              end
            end
          end
        end
      end  
      
      member do
        get 'annotations' => 'annotations#project_doc_annotations_index'
        get 'spans' => 'spans#spans_index', :as => 'spans_index'
        get 'spans/:begin-:end' => 'spans#span_show', :as => 'span_show'
        get 'spans/:begin-:end/annotations' => 'annotations#project_doc_annotations_index'    
      end
      resources :annotations do
      end
    end
  end
  
  match '/projects/:project_id/docs/sourcedb/:sourcedb/sourceid/:sourceid/annotations' => 'annotations#project_doc_annotations_index', :via => ["OPTIONS"]
  match '/projects/:project_id/docs/sourcedb/:sourcedb/sourceid/:sourceid/spans/:begin-:end/annotations' => 'annotations#project_doc_annotations_index', :via => ["OPTIONS"]
  match '/projects/:project_id/docs/sourcedb/:sourcedb/sourceid/:sourceid/divs/:divid/annotations' => 'annotations#project_div_annotations_index', :via => ["OPTIONS"]
  match '/projects/:project_id/docs/sourcedb/:sourcedb/sourceid/:sourceid/divs/:divid/spans/:begin-:end/annotations' => 'annotations#project_div_annotations_index', :via => ["OPTIONS"]

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
  match '/index_projects_annotations_rdf' => 'home#index_projects_annotations_rdf'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
