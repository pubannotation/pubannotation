Pubann::Application.routes.draw do

	resources :evaluators
	resources :evaluations do
		post 'select_reference_project' => 'projects#select_reference_project'
		post 'delete_reference_project' => 'projects#delete_reference_project'
		post 'generate' => 'evaluations#generate'
		get 'result' => 'evaluations#result'
		get 'falses' => 'evaluations#falses'
	end

	resources :collections do
		member do
			post '/add_project' => 'collections#add_project'
		end
		resources :projects do
			member do
				delete '/' => 'collections#remove_project'
			end
		end
	end

	resources :queries

	resources :sequencers

	resources :annotators
	resources :editors

	devise_for :users, controllers: {
		:omniauth_callbacks => 'callbacks',
		:confirmations => 'confirmations',
		:sessions => 'sessions'
	}

	get "home/index"

	resources :notices, only: :destroy do
		collection do
			get 'delete_project_notices/:id' => 'notices#delete_project_notices', as: 'delete_project'
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

	match '/users/:name' => 'users#show', :as => 'show_user'

	resources :docs do
		collection do
			get 'open' => 'docs#open'
			# list sourcedb
			get 'sourcedb' => 'docs#sourcedb_index'
			get 'search' => 'docs#search'
			get 'store_span_rdf' => 'docs#store_span_rdf'
			get 'update_numbers' => 'docs#update_numbers'

			get :autocomplete_doc_sourcedb
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
						get 'spans/:begin-:end' => 'spans#doc_span_show', :as => 'span_show'
						get 'spans/:begin-:end/annotations' => 'annotations#doc_annotations_index'
						get 'spans/:begin-:end/annotations/merge_view' => 'annotations#doc_annotations_merge_view'
						get 'spans/:begin-:end/annotations/list_view' => 'annotations#doc_annotations_list_view'
						get 'spans/:begin-:end/annotations/visualize' => 'annotations#doc_annotations_list_view'
					end
				end
			end
		end
	end

	resources :projects do
		get 'spans/sql' => 'spans#sql'
		get 'relations/sql' => 'relations#sql'
		get 'annotations.tgz' => 'annotations#project_annotations_tgz', :as => 'annotations_tgz'
		get 'annotations.tgz/create' => 'annotations#create_project_annotations_tgz', :as => 'create_annotations_tgz'
		post 'annotations.tgz' => 'annotations#create_from_tgz', :as => 'create_annotations_from_tgz'
		get 'delete_annotations_tgz' => 'annotations#delete_project_annotations_tgz', :as => 'delete_annotations_tgz'
		get 'annotations.rdf' => 'annotations#project_annotations_rdf', :as => 'annotations_rdf'
		get 'annotations.rdf/create' => 'annotations#create_project_annotations_rdf', :as => 'create_annotations_rdf'
		post 'docs/upload' => 'docs#create_from_upload', :as => 'create_docs_from_upload'
		post 'annotations/upload' => 'annotations#create_from_upload', :as => 'create_annotations_from_upload'
		post 'annotations/delete' => 'annotations#delete_from_upload', :as => 'delete_annotations_from_upload'
		post 'annotations/obtain' => 'annotations#obtain_batch'
		get 'delete_annotations_rdf' => 'annotations#delete_project_annotations_rdf', :as => 'delete_annotations_rdf'
		get 'notices' => 'notices#index'
		get 'tasks' => 'notices#tasks'
		resources :annotations
		resources :associate_maintainers, :only => [:destroy]
		resources :jobs do
			member do
				get 'messages' => 'messages#index'
			end
		end

		member do
			post 'store_annotation_rdf' => 'projects#store_annotation_rdf'
			get 'store_span_rdf' => 'projects#store_span_rdf'
			get 'clean' => 'projects#clean'
			get 'add_docs' => 'projects#add_docs'
			get 'upload_docs' => 'projects#upload_docs'
			get 'uptodate_docs' => 'projects#uptodate_docs'
			get 'obtain_annotations' => 'projects#obtain_annotations'
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
			get 'zip_upload' => 'projects#zip_upload'
			post 'create_from_tgz' => 'projects#create_from_tgz'
			# get 'store_annotation_rdf' => 'projects#store_annotation_rdf'
			get 'clean' => 'projects#clean'
		end
	end

	resources :projects do
		post 'annotations' => 'annotations#create'
		delete 'docs' => 'projects#delete_all_docs', as: 'delete_all_docs'
		delete 'annotations' => 'projects#destroy_all_annotations', as: 'destroy_all_annotations'
		delete 'jobs' => 'projects#clear_finished_jobs', as: 'clear_finished_jobs'

		resources :evaluations

		resources :docs do
			collection do
				get 'index' => 'docs#index'
				post 'add' => 'docs#add'
				post 'add_from_upload' => 'docs#add_from_upload'
				post 'import' => 'docs#import'
				get 'search' => 'docs#search'
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
								get 'spans/:begin-:end' => 'spans#project_doc_span_show', :as => 'span_show'
								get 'spans/:begin-:end/annotations' => 'annotations#project_doc_annotations_index', :as => 'span_annotations'
								post 'spans/:begin-:end/annotations' => 'annotations#create'
								delete 'spans/:begin-:end/annotations' => 'annotations#destroy', as: 'destroy_annotations_in_span'
								post 'spans/:begin-:end/annotations/obtain' => 'annotations#obtain', as: 'annotations_obtain_in_span'
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

		resources :annotations do
			collection do
				post 'import'  => 'annotations#import'
			end
		end

		resources :queries
	end

	resources :messages do
		member do
			get '/data_source' => 'messages#data_source'
			get '/data_target' => 'messages#data_target'
		end
	end

	match '/projects/:project_id/docs/sourcedb/:sourcedb/sourceid/:sourceid/annotations' => 'application#cors_preflight_check', :via => ["OPTIONS"]
	match '/projects/:project_id/docs/sourcedb/:sourcedb/sourceid/:sourceid/spans/:begin-:end/annotations' => 'application#cors_preflight_check', :via => ["OPTIONS"]

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
	match '/' => 'home#index', :as => :home
	get '/search' => 'graphs#show', :as => :sparql
	get '/projects/:project_name/search' => 'graphs#show', :as => :sparql_project

	# See how all your routes lay out with "rake routes"

	# This is a legacy wild controller route that's not recommended for RESTful applications.
	# Note: This route will make all actions in every controller accessible via GET requests.
	# match ':controller(/:action(/:id))(.:format)'
end
