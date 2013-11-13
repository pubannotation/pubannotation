# # encoding: utf-8
# require 'spec_helper'
# 
# describe SprojectsController do
  # describe 'index' do
    # before do
      # @sproject = FactoryGirl.create(:sproject)
      # @current_user = FactoryGirl.create(:user)
      # current_user_stub(@current_user)
      # get :index
    # end
#     
    # it 'should assign all Sproject as @sproject' do
      # assigns[:sprojects] =~ [@sproject]
    # end
  # end
#   
  # describe 'new' do
    # before do
      # controller.class.skip_before_filter :authenticate_user!
    # end
#     
    # context 'when format html' do
      # before do
        # get :new
      # end
#       
      # it 'should render new template' do
        # response.should render_template('new')
      # end
    # end
# 
    # context 'when format json' do
      # before do
        # get :new, format: :json
      # end
#       
      # it 'should render @sproject as json' do
        # response.body.should eql(Sproject.new.to_json)
      # end
    # end
  # end
#   
  # describe 'create' do
    # before do
      # controller.class.skip_before_filter :authenticate_user!
      # @current_user = FactoryGirl.create(:user)
      # current_user_stub(@current_user)
    # end
#     
    # context 'when saved' do
      # context 'when format html' do
        # context 'when project_names blank' do
          # before do
            # post :create, :sproject => {:name => 'sproject'}
          # end
#     
          # it 'should redirect to sproject path' do
            # response.should redirect_to(sproject_path(assigns[:sproject].name))
          # end
        # end
#         
        # context 'when project_names present' do
          # before do
            # @project = FactoryGirl.create(:project, :name => 'sub project1')
            # post :create, :sproject => {:name => 'sproject'}, :project_names => [@project.name]
          # end
#     
          # it 'should redirect to sproject path' do
            # response.should redirect_to(sproject_path(assigns[:sproject].name))
          # end
#           
          # it 'should add projects' do
            # Sproject.find_by_name('sproject').projects.should =~ [@project]
          # end
        # end
      # end
# 
      # context 'when format html' do
        # before do
          # post :create, :sproject => {:name => 'sproject'}, :format => :json
        # end
# 
        # it 'should render @sproject as json' do
          # response.body.should eql(assigns[:sproject].to_json) 
        # end
      # end
    # end
#     
    # context 'when not saved' do
      # context 'when format html' do
        # before do
          # post :create, :sproject => {}
        # end
# 
        # it 'should render new template' do
          # response.should render_template('new') 
        # end
      # end
# 
      # context 'when format html' do
        # before do
          # post :create, :sproject => {}, :format => :json
        # end
# 
        # it 'should render @sproject.errors as json' do
          # response.body.should eql(assigns[:sproject].errors.to_json) 
        # end
      # end
    # end
  # end
#   
  # describe 'show' do
    # before do
      # @sproject = FactoryGirl.create(:sproject)
      # @doc = FactoryGirl.create(:doc)
      # Doc.stub(:order_by).and_return([@doc])
      # controller.stub(:get_sproject).and_return([@sproject, 'notice'])
    # end
# 
    # context 'when @sproject present' do
      # context 'when format html' do
        # before do
          # get :show, :id => @sproject.name
        # end
#         
        # it 'should assign @sproject' do
          # assigns[:sproject].should eql(@sproject)
        # end
#         
        # it 'should assign @pmdocs' do
          # assigns[:pmdocs].should eql([@doc])
        # end
#         
        # it 'should assign @pmcdocs' do
          # assigns[:pmcdocs].should eql([@doc])
        # end
#         
        # it 'should render show template' do
          # response.should render_template('show')
        # end
      # end
# 
      # context 'when format json' do
        # before do
          # get :show, :id => @sproject.name, :format => :json
        # end
#         
        # it 'should render @sproject as json' do
          # response.body.should eql(@sproject.to_json)
        # end
      # end
    # end
#     
    # context 'when @sproject blank' do
      # before do
        # controller.stub(:get_sproject).and_return([nil, 'notice'])
      # end
#       
      # context 'when format html' do
        # before do
          # get :show, :id => 678
        # end
#         
        # it 'should redirect to home_path' do
          # response.should redirect_to(home_path)
        # end
      # end
# 
      # context 'when format json' do
        # before do
          # get :show, :id => 678, :format => :json
        # end
#         
        # it 'should render json' do
          # response.status.should eql(422)
        # end
      # end
    # end
  # end
#   
  # describe 'edit' do
    # before do
      # @sproject = FactoryGirl.create(:sproject)
      # @projects_sproject = FactoryGirl.create(:projects_sproject, :project_id => 1, :sproject_id => @sproject.id)
      # controller.class.skip_before_filter :authenticate_user!
      # get :edit, :id => @sproject.name
    # end
#     
    # it 'should assign @sproject' do
      # assigns[:sproject].should eql(@sproject)
    # end
#     
    # it 'should assign @sproject' do
      # assigns[:projects_sprojects].should =~ [@projects_sproject]
    # end
  # end
#   
  # describe 'update' do
    # before do
      # controller.class.skip_before_filter :authenticate_user!
      # @sproject = FactoryGirl.create(:sproject)
      # @project = FactoryGirl.create(:project, :pmdocs_count => 1, :pmcdocs_count => 2, :relations_count => 3, :denotations_count => 4)
      # @updated_name = 'udpated_name'
    # end
#     
    # context 'when params[:project_names] present' do
      # context 'when updated' do
        # context 'when format html' do
          # context 'when add one project' do
            # before do
              # post :update, :id => @sproject.id, :sproject => {:name => @updated_name}, :project_names => [@project.name]
            # end
#             
            # it 'should update sproject' do
              # Sproject.find(@sproject).name.should eql(@updated_name)
            # end
#             
            # it 'should add projects to sproject.projects' do
              # Sproject.find(@sproject).projects.should =~ [@project]
            # end
#             
            # it 'should redirect to sproject path' do
              # response.should redirect_to(sproject_path(@updated_name))
            # end
#             
            # it 'all counters should equal 0' do
              # @sproject.pmdocs_count.should eql(0)
              # @sproject.pmcdocs_count.should eql(0)
              # @sproject.relations_count.should eql(0)
              # @sproject.denotations_count.should eql(0)
            # end
#             
            # it 'should update counters' do
              # @sproject.reload
              # @sproject.pmdocs_count.should eql(1)
              # @sproject.pmcdocs_count.should eql(2)
              # @sproject.relations_count.should eql(3)
              # @sproject.denotations_count.should eql(4)
            # end
          # end
# 
          # context 'when add some projects' do
            # before do
              # @project_2 = FactoryGirl.create(:project, :pmdocs_count => 10, :pmcdocs_count => 20, :relations_count => 30, :denotations_count => 40)
              # @project_3 = FactoryGirl.create(:project, :pmdocs_count => 10, :pmcdocs_count => 20, :relations_count => 30, :denotations_count => 40)
              # post :update, :id => @sproject.id, :sproject => {:name => @updated_name}, :project_names => [@project.name, @project_2.name, @project_3.name]
            # end
#             
            # it 'should update sproject' do
              # Sproject.find(@sproject).name.should eql(@updated_name)
            # end
#             
            # it 'should add projects to sproject.projects' do
              # Sproject.find(@sproject).projects.should =~ [@project, @project_2, @project_3]
            # end
#             
            # it 'should redirect to sproject path' do
              # response.should redirect_to(sproject_path(@updated_name))
            # end
#             
            # it 'all counters should equal 0' do
              # @sproject.pmdocs_count.should eql(0)
              # @sproject.pmcdocs_count.should eql(0)
              # @sproject.relations_count.should eql(0)
              # @sproject.denotations_count.should eql(0)
            # end
#             
            # it '' do
              # @sproject.reload
              # @sproject.pmdocs_count.should eql(21)
              # @sproject.pmcdocs_count.should eql(42)
              # @sproject.relations_count.should eql(63)
              # @sproject.denotations_count.should eql(84)
            # end
          # end
        # end
# 
        # context 'when format json' do
          # before do
            # post :update, :format => :json, :id => @sproject.id, :sproject => {:name => @updated_name}, :project_names => [@project.name]
          # end
#           
          # it 'should redirect to sproject path' do
            # response.status.should eql(204)
            # response.body.should be_blank
          # end
        # end
      # end
# 
      # context 'when not updated' do
        # context 'when format html' do
          # before do
            # post :update, :id => @sproject.id, :sproject => {:name => ''}
          # end
#           
          # it 'should render edit template' do
            # response.should render_template('edit') 
          # end
        # end
# 
        # context 'when format json' do
          # before do
            # post :update, :id => @sproject.id, :format => :json, :sproject => {:name => ''}
          # end
#           
          # it 'should render errors as json' do
            # response.body.should eql(assigns[:sproject].errors.to_json) 
          # end
        # end
      # end
    # end
  # end
#   
  # describe 'destroy' do
    # before do
      # controller.class.skip_before_filter :authenticate_user!
      # @sproject = FactoryGirl.create(:sproject)
    # end
#     
    # context 'when format html' do
      # before do
        # delete :destroy, :id => @sproject.name
      # end
# 
      # it 'should redirect to sprojects path' do
        # response.should redirect_to(sprojects_path)
      # end
    # end
#     
    # context 'when format json' do
      # before do
        # delete :destroy, :id => @sproject.name, :format => :json
      # end
# 
      # it 'should redirect to sprojects path' do
        # response.status.should eql(204)
        # response.body.should be_blank
      # end
    # end
  # end
#   
  # describe 'search' do
    # before do
      # @sproject = FactoryGirl.create(:sproject)
      # controller.stub(:get_sproject).and_return(@sproject, 'notice')
      # @body = 'body'
      # @sourceid = 'sourceid'
      # @pmdoc = FactoryGirl.create(:doc, :sourceid => @sourceid, :body => @body)
      # # pmdoc not included in @sproject.pmdocs 
      # FactoryGirl.create(:doc, :sourceid => @sourceid, :body => @body)
      # Sproject.any_instance.stub(:pmdocs).and_return(Doc.where(:id => @pmdoc.id))
      # @pmcdoc = FactoryGirl.create(:doc, :sourceid => @sourceid, :body => @body)
      # # pmcdoc not included in @sproject.pmcdocs 
      # FactoryGirl.create(:doc, :sourceid => @sourceid, :body => @body)
      # Sproject.any_instance.stub(:pmcdocs).and_return(Doc.where(:id => @pmcdoc.id))
    # end
#     
    # context 'when params[:doc] = PubMed' do
      # context 'when sourceid match' do
        # before do
          # get :search, :id => @sproject.id, :doc => 'PubMed', :sourceid => @sourceid
        # end
#         
        # it 'should return matched docs included in sproject.pmdocd' do
          # assigns[:pmdocs].should =~ [@pmdoc]
        # end
      # end
# 
      # context 'when sourceid match' do
        # before do
          # get :search, :id => @sproject.id, :doc => 'PubMed', :body => @body
        # end
#         
        # it 'should return matched docs included in sproject.pmdocd' do
          # assigns[:pmdocs].should =~ [@pmdoc]
        # end
      # end
    # end
#     
    # context 'when params[:doc] = PMC' do
      # context 'when sourceid match' do
        # before do
          # get :search, :id => @sproject.id, :doc => 'PMC', :sourceid => @sourceid
        # end
#         
        # it 'should return matched docs included in sproject.pmcdocs' do
          # assigns[:pmcdocs].should =~ [@pmcdoc]
        # end
      # end
# 
      # context 'when sourceid match' do
        # before do
          # get :search, :id => @sproject.id, :doc => 'PMC', :body => @body
        # end
#         
        # it 'should return matched docs included in sproject.pmcdocs' do
          # assigns[:pmcdocs].should =~ [@pmcdoc]
        # end
      # end
    # end
  # end
# end