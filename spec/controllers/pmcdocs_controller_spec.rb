# encoding: utf-8
require 'spec_helper'

describe PmcdocsController do
  describe 'index' do
    before do
      @user = FactoryGirl.create(:user)  
      @annset = FactoryGirl.create(:annset, :user => @user)
      @doc_pmc_0 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0)
      @doc_pmc_1 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 1)
    end
    
    context 'when params[:annset_id] exists' do
      context 'and when annset exists' do
        before do
          @annsets = [@annset]
          @annset.docs << @doc_pmc_0
          @annset.docs << @doc_pmc_1
          controller.stub(:get_annset).and_return([@annset, 'notice'])
        end
        
        context 'when format html' do
          before do
            get :index, :annset_id => 1
          end
          
          it '@docs should include only which sourcedb == PMC and serial == 0' do
            assigns[:docs].should include(@doc_pmc_0)
            assigns[:docs].should_not include(@doc_pmc_1)
          end
          
          it 'should render template' do
            response.should render_template('index')
          end
        end
        
        context 'when format json' do
          before do
            get :index, :annset_id => 1, :format => 'json'
          end
          
          it 'should render json' do
            response.body.should eql(assigns[:docs].to_json)
          end
        end
      end

      context 'and when annset does not exists' do
        before do
          @notice = 'notice'
          controller.stub(:get_annset).and_return([nil, @notice])
        end
        
        context 'when format html' do
          before do
            get :index, :annset_id => 1
          end
          
          it '@docs should be nil' do
            assigns[:docs].should be_nil
          end
          
          it 'should render template' do
            response.should render_template('index')
          end
          
          it 'should set get_annset notice as flash[:notice]' do
            flash[:notice].should eql(@notice)
          end
        end

        context 'when format json' do
          before do
            get :index, :format => 'json', :annset_id => 1
          end
          
          it 'should return status 422' do
            response.status.should eql(422)
          end
        end
      end
    end
      
    context 'when params[:annset_id] does not exists' do
      before do
        get :index
      end
      
      it '@docs should include only which sourcedb == PMC and serial == 0' do
        assigns[:docs].should include(@doc_pmc_0)
        assigns[:docs].should_not include(@doc_pmc_1)
      end
    end
  end
  
  describe 'show' do
    before do
      @get_annset_notice = 'annset notice'
      @get_divs_notice = 'annset notice'
      @user = FactoryGirl.create(:user)  
      @annset = FactoryGirl.create(:annset, :user => @user)
      @div = FactoryGirl.create(:doc, :sourcedb => 'PMC')
      @divs = [@div]
    end
    
    context 'when params[:annset_id] exists' do
      context 'and when annset exists' do
        before do
          controller.stub(:get_annset).and_return([@annset, @get_annset_notice])
        end
        
        context 'and when divs exists' do
          before do
            controller.stub(:get_divs).and_return([@divs, @get_divs_notice])
            get :show, :annset_id => 1, :id => 1
          end
          
          it 'should redirect to annset_pmcdoc_divs_path' do
            response.should redirect_to(annset_pmcdoc_divs_path(1, 1))
          end
        end

        context 'and when divs does not exists' do
          before do
            controller.stub(:get_divs).and_return([nil, @get_divs_notice])
          end
          
          context 'and when format html' do
            before do
              get :show, :annset_id => 1, :id => 1
            end
            
            it 'should redirect to annset_pmcdoc_divs_path' do
              response.should redirect_to(annset_pmcdocs_path(1))
            end
          end
          
          context 'and when format json' do
            before do
              get :show, :format => 'json', :annset_id => 1, :id => 1
            end
            
            it 'should return status 422' do
              response.status.should eql(422)
            end
          end
        end
      end

      context 'and when annset does not exists' do
        before do
          controller.stub(:get_annset).and_return([nil, @get_annset_notice])
          controller.stub(:get_divs).and_return([@divs, @get_divs_notice])
          get :show, :annset_id => 1, :id => 1
        end
        
        it 'should redirect to pmcdocs_path' do
          response.should redirect_to(pmcdocs_path)
        end
      end
    end
    
    context 'when params[:annset_id] does not exists' do
      context 'and when divs exists' do
        before do
          controller.stub(:get_divs).and_return([@divs, @get_divs_notice])
        end
        
        context 'and when format html' do
          before do
            get :show, :id => 1
          end
          
          it 'should redirect to' do
            response.should redirect_to(pmcdoc_divs_path(1))
          end
        end
        
        context 'and when format json' do
          before do
            get :show, :id => 1, :format => 'json'
          end
          
          it 'should redirect to' do
            response.body.should eql(@divs.to_json)
          end
        end
      end
    end
  end
  
  describe 'create' do
    context 'when params[:annset_id] exists' do
      context 'and when annset exists' do
        before do
          @annset = FactoryGirl.create(:annset, :user => @user)
          controller.stub(:get_annset).and_return([@annset, 'notice'])
        end
        
        context 'and when divs found by sourcedb and sourceid' do
          before do
            @sourcedb = 'PMC'
            @sourceid = 'sourceid'
            @div = FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @sourceid)            
          end
          
          context 'and when annset.docs does not include divs.first' do
            context 'and when format html' do
              before do
                post :create, :annset_id => 1, :pmcids => @sourceid
              end
              
              it 'should redirect_to annset_pmcdocs_path' do
                response.should redirect_to(annset_pmcdocs_path(@annset.name))
              end
            end

            context 'and when format json' do
              before do
                post :create, :format => 'json', :annset_id => 1, :pmcids => @sourceid
              end
              
              it 'should return status 201' do
                response.status.should eql(201)
              end
              
              it 'should return location' do
                response.location.should eql(annset_pmcdocs_path(@annset.name))
              end
            end
          end
        end
        
        context 'and when divs not found by sourcedb and sourceid' do
          context 'and when divs returned by gen_pmcdoc' do
            before do
              @div = FactoryGirl.create(:doc, :id => 2, :sourcedb => 'sourcedb', :sourceid => 'sourceid')
              controller.stub(:gen_pmcdoc).and_return([[@div], 'message'])            
              post :create, :annset_id => 1, :pmcids => 'abcd'
            end
            
            it '' do
              
            end
          end

          context 'and when divs does not returned by gen_pmcdoc' do
            before do
              @div = FactoryGirl.create(:doc, :id => 2, :sourcedb => 'sourcedb', :sourceid => 'sourceid')
              controller.stub(:gen_pmcdoc).and_return([nil, 'message'])            
              post :create, :annset_id => 1, :pmcids => 'abcd,cdef'
            end
            
            it 'should redirect to annset_pmcdocs_path' do
              response.should redirect_to(annset_pmcdocs_path(@annset.name))
            end
          end
        end
      end
    end

    context 'when params[:annset_id] does not exists' do
      context 'and when format html' do
        before do
          post :create
        end
        
        it 'should redirect to home_path' do
          response.should redirect_to home_path
        end
      end

      context 'and when format html' do
        before do
          post :create, :format => 'json'
        end
        
        it 'should return status 422' do
          response.status.should eql(422)
        end
      end
    end
  end
end