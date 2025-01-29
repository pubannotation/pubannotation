Pubann::Application.routes.draw do

  require 'sidekiq/web'
  devise_scope :user do
    authenticate :user, ->(user) {user.root} do
      mount Sidekiq::Web => '/sidekiq'
    end
  end

	resources :evaluators
	resources :evaluations do
		post 'generate' => 'evaluations#generate'
		get 'result' => 'evaluations#result'
		get 'falses' => 'evaluations#falses'
		get 'index_falses' => 'evaluations#index_falses'
		get 'index_tps'
		get 'index_fps'
		get 'index_fns'
	end

	resources :collections do
		member do
			post 'create_annotations_rdf' => 'collections#create_annotations_rdf'
			post 'create_spans_rdf' => 'collections#create_spans_rdf'
			post '/add_project' => 'collections#add_project'
		end
		resources :projects do
			member do
				delete '/' => 'collections#remove_project'
				put '/toggle_primary' => "collections#project_toggle_primary"
				put '/toggle_secondary' => "collections#project_toggle_secondary"
			end
		end
		get 'jobs/latest_jobs_table' => 'jobs#latest_jobs_table'
		get 'jobs/latest_gear_icon' => 'jobs#latest_gear_icon'
		resources :jobs, only: [:index, :show, :update, :destroy] do
			member do
				get 'messages' => 'messages#index'
			end
		end
		delete 'jobs' => 'jobs#clear_finished_jobs', as: 'clear_finished_jobs'

		resources :queries
	end

	resources :queries

	resources :sequencers

	resources :annotators
	resources :editors

	resources :access_tokens, only: %i[create destroy]

	devise_for :users, controllers: {
		:omniauth_callbacks => 'users/omniauth_callbacks',
		:confirmations => 'confirmations',
		:sessions => 'sessions',
		:registrations => 'users/registrations',
		:passwords => 'users/passwords'
	}

	get "home/index"

	namespace :relations do
		get :sql
	end

	namespace :spans do
		get :sql
	end

	resources :sql, only: [:index]

	resources :users, only: [:index] do
		get :autocomplete_username, :on => :collection
	end

	get '/users/:name' => 'users#show', :as => 'show_user'

	resources :docs do
		collection do
			get 'open' => 'docs#open'
			# list sourcedb
			get 'sourcedb' => 'docs#sourcedb_index'
			get 'store_span_rdf' => 'docs#store_span_rdf'
			get 'update_numbers' => 'docs#update_numbers'

			get :autocomplete_doc_sourcedb
		end
	end

	# routings for /docs/sourcedb....
	scope 'docs',  :as => 'doc' do
		scope 'sourcedb', :as => 'sourcedb' do
			scope ':sourcedb' do
				# list sourceids
				get '/' => 'docs#index', :as => 'index'

				scope 'sourceid', :as => 'sourceid' do
					scope ':sourceid' do
						get '/' => 'docs#show', :as =>'show'
						get 'annotations' => 'annotations#doc_annotations_index'
						get 'annotations/merge_view' => 'annotations#doc_annotations_merge_view'
						get 'annotations/list_view' => 'annotations#doc_annotations_list_view'
						get 'annotations/visualize' => 'annotations#doc_annotations_list_view'
						post 'annotations' => 'annotations#align'
						get 'edit' => 'docs#edit'
						get 'uptodate' => 'docs#uptodate'
						delete '/' => 'docs#delete', :as=>'delete'
						get 'spans' => 'spans#doc_spans_index'
						post 'spans' => 'spans#get_url'
						get 'spans/:begin-:end' => 'docs#show', :as => 'span_show'
						get 'spans/:begin-:end/annotations' => 'annotations#doc_annotations_index'
						get 'spans/:begin-:end/annotations/merge_view' => 'annotations#doc_annotations_merge_view', :as => 'span_annotations_merge_view'
						get 'spans/:begin-:end/annotations/list_view' => 'annotations#doc_annotations_list_view', :as => 'span_annotations_list_view'
						get 'spans/:begin-:end/annotations/visualize' => 'annotations#doc_annotations_list_view'
					end
				end
			end
		end
	end

	resources :annotations, only: [:create]

	resources :projects do
		get 'spans/sql' => 'spans#sql'
		get 'relations/sql' => 'relations#sql'
		get 'annotations.tgz' => 'annotations#project_annotations_tgz', :as => 'annotations_tgz'
		get 'annotations.tgz/create' => 'annotations#create_project_annotations_tgz', :as => 'create_annotations_tgz'
		get 'delete_annotations_tgz' => 'annotations#delete_project_annotations_tgz', :as => 'delete_annotations_tgz'
		get 'annotations.rdf' => 'annotations#project_annotations_rdf', :as => 'annotations_rdf'
		post 'docs/upload' => 'docs#create_from_upload', :as => 'create_docs_from_upload'
		post 'annotations/upload' => 'annotations#create_from_upload', :as => 'create_annotations_from_upload'
		post 'annotations/delete' => 'annotations#delete_from_upload', :as => 'delete_annotations_from_upload'
		post 'annotations/obtain' => 'annotations#obtain_batch'
		resource :obtain_annotations_with_callback_job, only: [:new, :create]
		resources :annotations, only: [:index, :destroy]
		resources :associate_maintainers, :only => [:destroy]
		get 'jobs/latest_jobs_table' => 'jobs#latest_jobs_table'
		get 'jobs/latest_gear_icon' => 'jobs#latest_gear_icon'
		resources :jobs, only: [:index, :show, :update, :destroy] do
			member do
				get 'messages' => 'messages#index'
			end
		end

		member do
			post 'create_annotations_rdf' => 'projects#create_annotations_rdf'
			post 'create_spans_rdf' => 'projects#create_spans_rdf'
			post 'store_annotation_rdf' => 'projects#store_annotation_rdf'
			delete 'delete_annotation_rdf' => 'projects#delete_annotation_rdf'
			get 'store_span_rdf' => 'projects#store_span_rdf'
			get 'clean' => 'projects#clean'
			get 'add_docs' => 'projects#add_docs'
			get 'upload_docs' => 'projects#upload_docs'
			get 'uptodate_docs' => 'projects#uptodate_docs'
			get 'obtain_annotations' => 'projects#obtain_annotations'
			get 'import_annotations' => 'projects#import_annotations'
			get 'clean_annotations' => 'projects#clean_annotations'
			get 'rdfize_annotations' => 'projects#rdfize_annotations'
			get 'upload_annotations' => 'projects#upload_annotations'
			get 'delete_annotations' => 'projects#delete_annotations'
			get 'autocomplete_sourcedb' => 'projects#autocomplete_sourcedb'
			get 'autocomplete_project_name'
		end

		collection do
			# auto complete path which use scope and scope argument required :scope_argument param
			get 'autocomplete_project_name'
			get 'autocomplete_editable_project_name'
			get 'autocomplete_project_author'
			# get 'store_annotation_rdf' => 'projects#store_annotation_rdf'
			get 'clean' => 'projects#clean'
		end
	end

	resources :projects do
		post 'annotations' => 'annotations#create'
		delete 'docs' => 'projects#delete_all_docs', as: 'delete_all_docs'
		delete 'annotations' => 'projects#destroy_all_annotations', as: 'destroy_all_annotations'
		delete 'jobs' => 'jobs#clear_finished_jobs', as: 'clear_finished_jobs'

		resources :evaluations

		resources :docs do
			collection do
				get 'index' => 'docs#index'
				post 'add' => 'docs#add'
				post 'add_from_upload' => 'docs#add_from_upload'
				post 'import' => 'docs#import'
				get 'open' => 'docs#open'
				scope 'sourcedb', :as => 'sourcedb' do
					# list sourcedb
					get '/' => 'docs#sourcedb_index'

					scope ':sourcedb' do
						# list sourceids
						get '/' => 'docs#index', :as => 'index'

						scope 'sourceid', :as => 'sourceid' do
							scope ':sourceid' do
								get '/' => 'docs#show_in_project', :as =>'show'
								delete '/' => 'docs#project_delete_doc', :as=>'delete'
								get 'annotations' => 'annotations#project_doc_annotations_index'
								get 'annotations/visualize' => 'annotations#doc_annotations_list_view'
								post 'annotations' => 'annotations#create'
								post 'annotations/obtain' => 'annotations#obtain'
								delete 'annotations' => 'annotations#destroy', as: 'destroy_annotations'
								get 'spans' => 'spans#project_doc_spans_index', :as => 'spans_index'
								get 'spans/:begin-:end' => 'docs#show_in_project', :as => 'span_show'
								get 'spans/:begin-:end/annotations' => 'annotations#project_doc_annotations_index', :as => 'span_annotations'
								post 'spans/:begin-:end/annotations' => 'annotations#create'
								delete 'spans/:begin-:end/annotations' => 'annotations#destroy', as: 'destroy_annotations_in_span'
								post 'spans/:begin-:end/annotations/obtain' => 'annotations#obtain', as: 'annotations_obtain_in_span'
							end
						end
					end
				end
			end

			resources :annotations, only: [:index, :create, :destroy] do
			end
		end

		resources :annotations, only: [:index, :create, :destroy] do
			collection do
				post 'import'  => 'annotations#import'
				post 'analyse' => 'annotations#analyse'
				post 'remove_embeddings' => 'annotations#remove_embeddings'
				post 'remove_boundary_crossings' => 'annotations#remove_boundary_crossings'
				post 'remove_duplicate_labels' => 'annotations#remove_duplicate_labels'
			end
		end

		resources :queries
	end

	resources :messages, only: [:index, :show] do
		member do
			get '/data_source' => 'messages#data_source'
			get '/data_target' => 'messages#data_target'
		end
	end

	match '/annotations/align' => 'annotations#align', :via => ["POST"]

	resources :news_notifications, path: :news do
		collection do
			get 'category/:category' => 'news_notifications#category', as: 'category'
		end
	end

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
	get '/' => 'home#index', :as => :home
	get '/search' => 'graphs#show', :as => :sparql
	get '/projects/:project_name/search' => 'graphs#show', :as => :sparql_project
	get '/collections/:collection_name/search' => 'graphs#show', :as => :sparql_collection
	put '/annotation_reception/:uuid' => 'annotation_reception#update'

  # Evidence Block Search API
  resources :term_search, only: [:index]
  namespace :term_search, only: [:show] do
    resources :docs, only: [:index]
		resources :paragraphs, only: [:index]
		resources :sentences, only: [:index]
	end
	scope :jobs do
		resource :update_paragraph_references_job, only: [:show, :create, :destroy]
		resource :update_sentence_references_job, only: [:show, :create, :destroy]
	end

	# SimpleInlineTextAnnotation conversion API
	namespace :conversions do
		resources :inline2json, only: :create
		resources :json2inline, only: :create
	end

	# TextAE open API
	post '/textae' => 'textae_annotations#create'
	get '/textae/:uuid' => 'textae_annotations#show'
end
