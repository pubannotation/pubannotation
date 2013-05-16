# encoding: utf-8
require 'spec_helper'

describe AnnsetsController do
  before do
    controller.class.skip_before_filter :authenticate_user!
  end
  
  describe 'index' do
    context 'when sourcedb exists' do
      context 'and when doc exists' do
        context 'and when annsets exists' do
          before do
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 1)
            controller.stub(:get_docspec).and_return([@doc.sourcedb, @doc.sourceid, @doc.serial])
            @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
            controller.stub(:get_annsets).and_return([@annset])
          end
          
          context 'and when format html' do
            before do
              get :index
            end
            
            it 'should render template' do
              response.should render_template('index')
            end
          end
        end
        
        context 'and when annsets does not exist' do
          before do
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 1)
            controller.stub(:get_docspec).and_return([@doc.sourcedb, @doc.sourceid, @doc.serial])
            @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
            controller.stub(:get_annsets).and_return(nil)
            get :index
          end
          
          it 'should redirect to home_path' do
            response.should redirect_to(home_path)
          end
        end
      end

      context 'and when doc does not exists' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 1)
          controller.stub(:get_docspec).and_return([@doc.sourcedb, @doc.sourceid, nil])
          @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
          controller.stub(:get_annsets).and_return([@annset])
        end
        
        context 'and when format html' do
          before do
            get :index
          end
          
          it 'should render template' do
            response.should render_template('index')
          end
        end
      end
    end

    context 'when sourcedb does not exists' do
      before do
        @user = FactoryGirl.create(:user)
        current_user_stub(@user)
        @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
        get :index
      end
      
      it 'should render template' do
        response.should render_template('index')
      end
    end
    
    context 'when format is json' do
      before do
        @annsets = {:a => 'a', :b => 'b'}
        controller.stub(:get_annsets).and_return(@annsets)
        get :index, :format => 'json'
      end
      
      it 'should render json' do
        response.body.should eql(@annsets.to_json)
      end
    end
  end
  
  describe 'show' do
    context 'when annset exists' do
      before do
        @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
        controller.stub(:get_annset).and_return(@annset)  
      end
      
      context 'when sourceid exists' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 'serial')
          controller.stub(:get_docspec).and_return(['', 'sourdeid', ''])
          controller.stub(:get_doc).and_return(@doc, 'notice')
          get :show, :id => @annset.id
        end
        
        it 'should render template' do
          response.should render_template('show')
        end
      end
      
      context 'when sourceid does not exists' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 'serial')
          controller.stub(:get_docspec).and_return(['', nil, ''])
          controller.stub(:get_doc).and_return(@doc, 'notice')
          get :show, :id => @annset.id
        end
        
        it 'should render template' do
          response.should render_template('show')
        end
      end
    end

    context 'when annset does not exists' do
      context 'and when doc does not exists' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 'sourceid', :serial => 'serial')
          get :show, :id => 1
        end
        
        it '' do
          response.should redirect_to(home_path)
        end
      end
    end
  end
  
  describe 'new' do

    context 'when format html' do
      before do
        get :new
      end
      
      it 'should render template' do
        response.should render_template('new')
      end
      
      it 'should set new record' do
        assigns[:annset].new_record?.should be_true
      end
    end

    context 'when format json' do
      before do
        get :new, :format => 'json'
      end
      
      it 'should render json' do
        response.body.should eql(assigns[:annset].to_json)
      end
      
      it 'should set new record' do
        assigns[:annset].new_record?.should be_true
      end
    end
  end
  
  describe 'edit' do
    before do
      @annset = FactoryGirl.create(:annset, :name => 'annset name', :user => FactoryGirl.create(:user))
      @get_docspec = ['sourcedb', 'sourceid', 'serial']
      controller.stub(:get_docspec).and_return(@get_docspec)
      get :edit, :id => @annset.name
    end
    
    it 'should render template' do
      response.should render_template('edit')
    end
    
    it 'should assing sourcedb' do
      assigns[:sourcedb].should eql(@get_docspec[0])
    end
    
    it 'should assing sourceid' do
      assigns[:sourceid].should eql(@get_docspec[1])
    end
    
    it 'should assing serial' do
      assigns[:serial].should eql(@get_docspec[2])
    end
    
    it 'should assign annset' do
      assigns[:annset].should eql(@annset)
    end
  end
  
  describe 'create' do
    before do
      current_user_stub(FactoryGirl.create(:user))  
    end
    
    context 'when saved successfully' do
      before do
        @annset_name = 'ansnet name'
      end

      context 'when format html' do
        before do
          post :create, :annset => {:name => 'ansnet name'}
        end
        
        it 'should redirect to annset_path' do
          response.should redirect_to(annset_path('ansnet name'))
        end
      end

      context 'when format json' do
        before do
          post :create, :format => 'json', :annset => {:name => 'ansnet name'}
        end
        
        it 'should render json' do
          response.body.should eql(assigns[:annset].to_json)
        end

        it 'should return http response created as status' do
          response.status.should eql(201)
        end

        it 'should return annset path as location' do
          response.location.should eql("http://#{request.env['HTTP_HOST']}#{annset_path(assigns[:annset].id)}")
        end
      end
    end
    
    context 'when saved unsuccessfully' do
      context 'when format html' do      
        before do
          post :create, :annset => {:name => nil}
        end
        
        it 'should render new template' do
          response.should render_template('new')
        end
      end
      
      context 'when format html' do      
        before do
          post :create, :format => 'json', :annset => {:name => nil}
        end
        
        it 'should render json' do
          response.body.should eql(assigns[:annset].errors.to_json)
        end
        
        it 'should return status 422' do
          response.status.should eql(422)
        end
      end
    end
  end
  
  describe 'update' do
    before do
      @annset = FactoryGirl.create(:annset, :name => 'annset_name')  
    end
    
    context 'when update successfully' do
      before do
        @params_annset = {:name => 'new_annset_name'}  
      end
      
      context 'and when format html' do
        before do
          post :update, :id => @annset.id, :annset => @params_annset          
        end
        
        it 'should redirect to annset_path' do
          response.should redirect_to(annset_path(@params_annset[:name]))
        end
      end

      context 'and when format json' do
        before do
          post :update, :id => @annset.id, :format => 'json', :annset => @params_annset          
        end
        
        it 'should return response blank header' do
          response.header.should be_blank
        end
      end
    end

    context 'when update unsuccessfully' do
      before do
        @params_annset = {:name => nil}  
      end
      
      context 'and when format html' do
        before do
          post :update, :id => @annset.id, :annset => @params_annset          
        end
        
        it 'should render edit template' do
          response.should render_template('edit')
        end
      end

      context 'and when format json' do
        before do
          post :update, :id => @annset.id, :format => 'json', :annset => @params_annset          
        end
        
        it 'should return response blank header' do
          response.body.should eql(assigns[:annset].errors.to_json)
        end
        
        it 'should return resposne 422' do
          response.status.should eql(422)
        end
      end
    end
  end
  
  describe 'destroy' do
    before do
      @annset = FactoryGirl.create(:annset, :name => 'annset_name')  
    end
    
    context 'format html' do
      before do
        delete :destroy, :id => @annset.name   
      end
      
      it 'should redirect to annsets_path' do
        response.should redirect_to annsets_path
      end
    end
    
    context 'format html' do
      before do
        delete :destroy, :format => 'json', :id => @annset.name   
      end
      
      it 'should return response blank header' do
        response.header.should be_blank
      end
    end
  end
end