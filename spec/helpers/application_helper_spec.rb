# encoding: utf-8
require 'spec_helper'

describe ApplicationHelper do
  before do
    I18n.locale = :en
  end
  
  describe 'hint_helper' do
    before do
      @result = helper.hint_helper({:model => :project, :column => :author})
    end
    
    it 'should render img tag with title attribute' do
      @result.should have_selector :img, :src => '/assets/hint.png', :title => 'specify the official author/project of the annotations, in case you are uploading annotations produced by someone else'
    end
  end
  
  describe 'errors_helper' do
    before do
      @model_name = 'project'  
    end
    
    context 'when model has no error' do
      before do
        @errors_count = 0
        @model = double(:model, :class => @model_name, :errors => double(:errors, {:count => @errors_count, :full_messages => [''], :any? => true}))#{:count => 2, :full_messages => ['1']})
        @result = helper.errors_helper(@model)
      end
      
      it 'should output nothing' do
        @result.should be_blank
      end
    end
    
    context 'when model has an error' do
      before do
        @errors_count = 1
        @model = double(:model, :class => @model_name, :errors => double(:errors, {:count => @errors_count, :full_messages => [''], :any? => true}))#{:count => 2, :full_messages => ['1']})
        @result = helper.errors_helper(@model)
      end
      
      it 'should output errors count for an error' do
        @result.should include(I18n.t('errors.template.header.one', :model => @model_name))
      end
    end
    
    context 'when model has more than one error' do
      before do
        @errors_count = 2
        @model = double(:model, :class => @model_name, :errors => double(:errors, {:count => @errors_count, :full_messages => [''], :any? => true}))#{:count => 2, :full_messages => ['1']})
        @result = helper.errors_helper(@model)
      end
      
      it 'should output errors count for more than one error' do
        @result.should include(I18n.t('errors.template.header.other', :model => @model_name, :count => @errors_count))
      end
    end
  end
  
  describe 'language_switch_helper' do
   context 'I18n.locale == en' do
     before do
       @url_for = 'url'
       helper.stub(:url_for).and_return(@url_for)
       @text = helper.language_switch_helper
     end 
     
     it 'helper should show link for japanese' do
       @text.should include("English")
       @text.should include("<a href=\"#{@url_for}\">日本語</a>")
     end
   end 
   
   context 'I18n.locale == en' do
     before do
       @url_for = 'url'
       helper.stub(:url_for).and_return(@url_for)
       I18n.locale = :ja
       @text = helper.language_switch_helper
     end 
     
     it 'helper should show link for english' do
       @text.should include("<a href=\"url\">English</a>")
       @text.should include("日本語")
     end
   end
  end
  
  describe 'get_ascii_text' do
    before do
      @text = 'α'
      @ascii_text = helper.get_ascii_text(@text)
    end
    
    it 'should return greek retters' do
      @ascii_text.should eql('alpha')
    end
  end
  
  describe 'sanitize_sql' do
    it 'should trim ""' do
      helper.sanitize_sql('"content"').should eql("'content'")
    end
  end

  describe 'sortable' do
    pending 'link path ambiguous' do
      context 'when title present' do
        before do
          @key = 'key'
          assign :sort_order,  [[@key, 'val2']]
          @result = helper.sortable(@key, 'title')
        end

        it '' do
          @result
        end
      end
    end
  end
end
