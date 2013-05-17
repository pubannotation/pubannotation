# encoding: utf-8
require 'spec_helper'

describe PmdocsController do
  describe 'index' do
    context 'when params[:annset_id] exists' do
      context 'and when @ansnet exists' do
        before do
          @annset = FactoryGirl.create(:annset)
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0)
          @annset.docs << @doc
          controller.stub(:get_annset).and_return([@annset, 'notice'])
        end
        
        context 'and when format html' do
          before do
            get :index, :annset_id => @annset.id
          end
          
          it 'should render template' do
            response.should render_template('index')
          end
        end
        
        context 'and when format json' do
          before do
            get :index, :format => 'json', :annset_id => @annset.id
          end
          
          it 'should render json' do
            response.body.should eql(@annset.docs.to_json)
          end
        end
      end

      context 'and when @ansnet does not exists' do
        before do
          @notice = 'notice'
          controller.stub(:get_annset).and_return([nil, @notice])
        end
        
        context 'and when format html' do
          before do
            get :index, :annset_id => 1
          end
          
          it 'should render template' do
            should render_template('index')
          end

          it 'should set notice as flash[:notice]' do
            flash[:notice].should eql(@notice)
          end
        end
      end
    end

    context 'when params[:annset_id] exists' do
      before do
        get :index
      end      
      
      it 'should render template' do
        should render_template('index')
      end
    end
  end
  
  describe 'show' do
    context 'when params[:annset_id] exists' do
      context 'and when @ansnet exists' do
        context 'and when get_doc returns @doc' do
          before do
            @annset = FactoryGirl.create(:annset)
            @doc = FactoryGirl.create(:doc, :body => 'doc body')
            controller.stub(:get_annset).and_return([@annset, ''])
            @get_doc_notice = 'get doc notice'
            controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
          end
          
          context 'and when format html' do
            before do
              get :show, :id => @doc.id, :annset_id => @annset.id, :encoding => 'ascii'
            end
            
            it 'should render template' do
              response.should render_template('docs/show')
            end
          end
          
          context 'and when format json' do
            before do
              get :show, :format => 'json', :id => @doc.id, :annset_id => @annset.id
            end
            
            it 'should render json' do
              response.body.should eql({:pmdoc_id => @doc.id.to_s, :text => @doc.body}.to_json)
            end
          end
          
          context 'and when format json' do
            before do
              get :show, :format => 'txt', :id => @doc.id, :annset_id => @annset.id
            end
            
            it 'should render text' do
              response.body.should eql(@doc.body)
            end
          end
        end
      end

      context 'and when @ansnet does not exists' do
        before do
          controller.stub(:get_annset).and_return([nil, ''])
        end
        
        context 'and when format html' do
          before do
            get :show, :id => 1, :annset_id => 1
          end
          
          it 'should redirect to pmdocs_path' do
            response.should redirect_to(pmdocs_path)
          end
        end      
        
        context 'and when format json' do
          before do
            get :show, :format => 'json', :id => 1, :annset_id => 1
          end
          
          it 'should return status 422' do
            response.status.should eql(422)
          end
        end      
        
        context 'and when format json' do
          before do
            get :show, :format => 'txt', :id => 1, :annset_id => 1
          end
          
          it 'should return status 422' do
            response.status.should eql(422)
          end
        end      
      end
    end
    
    context 'when params[:annset_id] does not exists' do
      before do
        get :show, :id => 1
      end      

      it 'should redirect to pmdocs_path' do
        response.should redirect_to(pmdocs_path)
      end
    end
  end
  
  describe 'create' do
    context 'when params[:annset_id] exists' do
      context 'and when format html' do
        before do
          post :create, :pmids => 'pmids'
        end
        
        it 'should redirect to home_path' do
          response.should redirect_to(home_path)
        end
      end

      context 'and when format html' do
        before do
          post :create, :format => 'json', :pmids => 'pmids'
        end
        
        it 'should return status 422' do
          response.status.should eql(422)
        end
      end
    end
    
    context 'when params[:annset_id] exists' do
      context 'and when annset exists' do
        before do
          @annset = FactoryGirl.create(:annset)
          @sourceid = 'sourdeid'
          #@annset.docs << @doc
          controller.stub(:get_annset).and_return([@annset, 'notice'])        
        end
        
        context 'and when doc found by sourcedb and sourceid and serial' do
          before do
            @doc = FactoryGirl.create(:doc, :sourceid => @sourceid, :sourcedb => 'PubMed', :serial => 0)
          end
          
          context 'and when format html' do
            before do
              post :create, :annset_id => 1, :pmids => @sourceid
            end
            
            it 'should redirect to annset_pmdocs_path' do
              response.should redirect_to(annset_pmdocs_path(@annset.name))
            end
          end
          
          context 'and when format json' do
            before do
              post :create, :format => 'json', :annset_id => 1, :pmids => @sourceid
            end
            
            it 'should return status created' do
              response.status.should eql(201)
            end
            
            it 'should return location' do
              response.location.should eql(annset_pmdocs_path(@annset.name))
            end
          end
        end
        
        context 'and when doc not found by sourcedb and sourceid and serial' do
          context 'and when gem_pmdoc returns doc' do
            before do
              @doc = FactoryGirl.create(:doc, :sourceid => @sourceid, :sourcedb => 'PM', :serial => 0)
              controller.stub(:gen_pmdoc).and_return(@doc)
              post :create, :annset_id => 1, :pmids => @sourceid
            end
            
            it 'should redirect to annset_pmdocs_path' do
              response.should redirect_to(annset_pmdocs_path(@annset.name))
            end
          end

          context 'and when gem_pmdoc does not returns doc' do
            before do
              @doc = FactoryGirl.create(:doc, :sourceid => @sourceid, :sourcedb => 'PM', :serial => 0)
              controller.stub(:gen_pmdoc).and_return(nil)
              post :create, :annset_id => 1, :pmids => @sourceid
            end
            
            it 'should redirect to annset_pmdocs_path' do
              response.should redirect_to(annset_pmdocs_path(@annset.name))
            end
          end
        end
      end
    end
  end
  
  describe 'update' do
    context 'when params[:annset_id] exists' do
      context 'and when annset found by name' do
        context 'and when doc found by sourcedb and sourceid' do
          context 'and when doc.annsets does not include annset' do
            before do
              @annset = FactoryGirl.create(:annset)
              @id = 'sourceid'
              @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)
            end
            
            context 'and when format html' do
              before do
                post :update, :annset_id => @annset.name, :id => @id
              end
              
              it 'should redirect to annset_pmdocs_path' do
                response.should redirect_to(annset_pmdocs_path(@annset.name))
              end
            end
            
            context 'and when format json' do
              before do
                post :update, :format => 'json', :annset_id => @annset.name, :id => @id
              end
              
              it 'return blank header' do
                response.header.should be_blank
              end
            end
          end
        end

        context 'and when doc not found by sourcedb and sourceid' do
          context 'and when gen_pmdoc return doc' do
            before do
              @annset = FactoryGirl.create(:annset)
              @id = 'sourceid'
              @doc = FactoryGirl.create(:doc, :sourcedb => 'PM', :sourceid => @id)
              controller.stub(:gen_pmdoc).and_return(@doc)
              post :update, :annset_id => @annset.name, :id => @id
            end

            it 'should redirect to annset_pmdocs_path' do
              response.should redirect_to(annset_pmdocs_path(@annset.name))
            end
            
            it 'should set flash[:notice]' do
              flash[:notice].should eql("The document, #{@doc.sourcedb}:#{@doc.sourceid}, was created in the annotation set, #{@annset.name}.")
            end
          end
          
          context 'and when gen_pmdoc does not return doc' do
            before do
              @annset = FactoryGirl.create(:annset)
              @id = 'sourceid'
              controller.stub(:gen_pmdoc).and_return(nil)
              post :update, :annset_id => @annset.name, :id => @id
            end

            it 'should redirect to annset_pmdocs_path' do
              response.should redirect_to(annset_pmdocs_path(@annset.name))
            end
            
            it 'should set flash[:notice]' do
              flash[:notice].should eql("The document, PubMed:#{@id}, could not be created.")
            end
          end
        end
      end

      context 'and when annset not found by name' do
        before do
          @annset = FactoryGirl.create(:annset)
          @id = 'sourceid'
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)
          @annset_id = 'annset id'
          post :update, :annset_id => @annset_id, :id => @id
        end
        
        it 'should redirect to pmdocs_path' do
          response.should redirect_to(pmdocs_path)
        end

        it 'should set flash[:notice]' do
          flash[:notice].should eql("The annotation set, #{@annset_id}, does not exist.")
        end
      end
    end

    context 'when params[:annset_id] does not exists' do
      context 'and when gen_pmdoc returns doc' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)
          controller.stub(:gen_pmdoc).and_return(@doc)
          @id = 1
          post :update, :id => 1
        end      
        
        it 'should redirect to pmdocs_path' do
          response.should redirect_to(pmdocs_path)  
        end
        
        it 'should set flash[:notice]' do
          flash[:notice].should eql("The document, PubMed:#{@id}, was successfuly created.")
        end
      end

      context 'and when gen_pmdoc does not returns doc' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)
          controller.stub(:gen_pmdoc).and_return(nil)
          @id = 1
        end      
        
        context 'and when format html' do
          before do
            post :update, :id => 1
          end
          
          it 'should redirect to pmdocs_path' do
            response.should redirect_to(pmdocs_path)  
          end
          
          it 'should set flash[:notice]' do
            flash[:notice].should eql("The document, PubMed:#{@id}, could not be created.")
          end
        end
        
        context 'and when format json' do
          before do
            post :update, :format => 'json', :id => 1
          end
          
          it 'should return status 422' do
            response.status.should eql(422) 
          end
        end
      end
    end
  end
  
  describe 'destroy' do
    before do
      @id = 'sourceid'
    end
    
    context 'when params[:annset_id] does not exists' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)  
        delete :destroy, :id => @id
      end
      
      it 'should destroy doc' do
        Doc.where(:id => @doc.id).should be_blank
      end
      
      it 'should redirect to pmdocs_path' do
        response.should redirect_to(pmdocs_path)
      end
      
      it 'should not set flash[:notice]' do
        flash[:notice].should be_nil
      end
    end
    
    context 'when params[:annset_id] exists' do
      before do
        @annset_id = 'annset id'
      end
      
      context 'when annset found by nanme' do
        before do
          @annset = FactoryGirl.create(:annset, :name => @annset_id)  
        end
        
        context 'when annset found by nanme' do
          context 'when doc found by sourcedb and source id' do
            before do
              @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)  
            end
            
            context 'when doc.annsets include annset' do
              before do
                @doc.annsets << @annset
              end
              
              context 'when format html' do
                before do
                  delete :destroy, :annset_id => @annset_id, :id => @id
                end
                
                it 'should redirect to annset_pmdocs_path(annset.name)' do
                  response.should redirect_to(annset_pmdocs_path(@annset.name))
                end
                
                it 'should set flash[:notice]' do
                  flash[:notice].should eql("The document, #{@doc.sourcedb}:#{@doc.sourceid}, was removed from the annotation set, #{@annset.name}.")
                end
              end
              
              context 'when format json' do
                before do
                  delete :destroy, :format => 'json', :annset_id => @annset_id, :id => @id
                end
                
                it 'should return blank header' do
                  response.header.should be_blank
                end
              end
            end
            
            context 'when doc.annsets does not include annset' do
              before do
                delete :destroy, :annset_id => @annset_id, :id => @id
              end
              
              it 'should redirect to annset_pmdocs_path(annset.name)' do
                response.should redirect_to(annset_pmdocs_path(@annset.name))
              end
              
              it 'should set flash[:notice]' do
                flash[:notice].should eql("the annotation set, #{@annset.name} does not include the document, #{@doc.sourcedb}:#{@doc.sourceid}.")
              end
            end
          end

          context 'when doc not found by sourcedb and source id' do
            before do
              delete :destroy, :annset_id => @annset_id, :id => @id
            end
            
            
            it 'should redirect to annset_pmdocs_path(annset.name)' do
              response.should redirect_to(annset_pmdocs_path(@annset.name))
            end
            
            it 'should set flash[:notice]' do
              flash[:notice].should eql("The document, PubMed:#{@id}, does not exist in PubAnnotation.")
            end
          end
        end
      end      

      context 'when annset not found by nanme' do
        before do
          delete :destroy, :annset_id => @annset_id, :id => ''
        end
        
        it 'should redirect_to pmdocs_path' do
          response.should redirect_to(pmdocs_path)
        end

        it 'should not set flash[:notice]' do
          flash[:notice].should eql("The annotation set, #{@annset_id}, does not exist.")
        end
      end
    end
  end
end