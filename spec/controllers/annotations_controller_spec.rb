# encoding: utf-8
require 'spec_helper'

describe AnnotationsController do
  describe 'index' do
    context 'when annset exists' do
      before do
        @user = FactoryGirl.create(:user)
        @annset = FactoryGirl.create(:annset, 
          :user => @user, 
          :name => 'test_name',
          :rdfwriter => '',
          :xmlwriter => '',
        )
        @annset.docs << FactoryGirl.create(:doc)
        controller.stub(:get_annset).and_return(@annset)
        controller.stub(:get_docspec).and_return(nil)
        controller.stub(:get_doc).and_return('doc')
        @annotations = {
            :text => 'text val',
            :catanns => 'catanns val',
            :insanns => 'insanns val',
            :insanns => 'relanns val',
            :insanns => 'insanns val'
          }
        controller.stub(:get_annotations).and_return(@annotations)
      end
      
      context 'and when params pmdoc_id or pmc_doc_id exists' do
        
        context 'and when format is html' do
          before do
            get :index, :format => 'html', :annset_id => @annset.name, :pmdoc_id => 5
          end

          it 'should render html template' do
            response.should render_template('index')
          end
        end
        
        context 'and when format is json' do
          before do
            get :index, :format => 'json', :annset_id => @annset.name, :pmdoc_id => 5
          end

          it 'should render annotations as json' do
            response.body.should eql(@annotations.to_json)
          end
        end
        
        context 'and when format is ttl' do
          context 'and when annset.rdfwriter is empty' do
            before do
              get :index, :format => 'ttl', :annset_id => @annset.name, :pmdoc_id => 5
            end
  
            it 'should return error 422' do
              response.status.should eql(422)
            end
          end

          context 'and when annset.rdfwriter is not empty' do
            before do            
              @annset = FactoryGirl.create(:annset, 
                :user => @user, 
                :name => 'test_name2',
                :rdfwriter => 'rdfwriter'
              )
              controller.stub(:get_annset).and_return(@annset)
              @get_conversion_text = 'rendered text'
              controller.stub(:get_conversion).and_return(@get_conversion_text)
              get :index, :format => 'ttl', :annset_id => @annset.name, :pmdoc_id => 5
            end

            it 'should return get_conversion text' do
              response.body.should eql(@get_conversion_text)
            end
          end
        end
        
        context 'and when format is xml' do
          context 'and when annset.rdfwriter is empty' do
            before do
              get :index, :format => 'xml', :annset_id => @annset.name, :pmdoc_id => 5
            end
  
            it 'should return error 422' do
              response.status.should eql(422)
            end
          end

          context 'and when annset.rdfwriter is not empty' do
            before do
              @annset = FactoryGirl.create(:annset, 
                :user => @user, 
                :name => 'test_name3',
                :xmlwriter => 'xmlwriter'
              )
              controller.stub(:get_annset).and_return(@annset)
              @get_conversion_text = 'rendered text'
              controller.stub(:get_conversion).and_return(@get_conversion_text)
              get :index, :format => 'xml', :annset_id => @annset.name, :pmdoc_id => 5
            end
  
            it 'should return get_conversion text' do
              response.body.should eql(@get_conversion_text)
            end
          end
        end
      end

      context 'and when params pmdoc_id nor pmc_doc_id does not exists' do
        context 'and when anncollection exists' do
          context 'when format is json' do
            before do
              controller.stub(:get_annotations).and_return(
              {
                :source_db => 'source_db',
                :source_id => 'source_id',
                :division_id => 1,
                :section => 'section',
               })
              get :index, :format => 'json', :annset_id => @annset.name
            end
            
            it 'should returns zip' do
              response.header['Content-Type'].should eql('application/zip')
            end
          end
  
          context 'when format is ttl' do
            before do
              controller.stub(:get_conversion).and_return(
              'line1
              line2
              line3
              line4
              line5
              line6
              line7
              line8
              line9
              ')
              get :index, :format => 'ttl', :annset_id => @annset.name
            end
            
            it 'should returns x-turtle' do
              response.header['Content-Type'].should eql('application/x-turtle; charset=utf-8')
            end
          end
        end

        context 'and when anncollection does not exists' do
          before do
            controller.stub(:get_annotations).and_return('')
          end
          
          context 'and whern format html' do
            before do
              get :index, :format => 'html', :annset_id => @annset.name
            end
            
            it 'should render template' do
              response.should render_template('index')
            end
          end
          
          context 'and whern format json' do
            before do
              get :index, :format => 'json', :annset_id => @annset.name
            end
            
            it 'should return error 422' do
              response.status.should eql(422)
            end
          end
          
          context 'and whern format ttl' do
            before do
              get :index, :format => 'ttl', :annset_id => @annset.name
            end
            
            it 'should return error 422' do
              response.status.should eql(422)
            end
          end
        end
      end
    end
  end
end 