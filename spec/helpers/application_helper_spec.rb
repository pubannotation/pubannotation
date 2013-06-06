# encoding: utf-8
require 'spec_helper'

describe ApplicationHelper do
  describe 'hint_helper' do
    before do
      @result = helper.hint_helper({:model => :project, :column => :author})
    end
    
    it 'should render img tag with title attribute' do
      @result.should have_selector :img, :src => '/assets/hint.png', :title => 'specify the official author/project of this annotation set, in case you are uploading an annotation set produced by someone else'
    end
  end
  
  describe 'errors_helper' do
    before do
      @model_name = 'Project'  
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
        @result.should include(I18n.t('errors.template.header.one', :model => @model_name.downcase))
      end
    end
    
    context 'when model has more than one error' do
      before do
        @errors_count = 2
        @model = double(:model, :class => @model_name, :errors => double(:errors, {:count => @errors_count, :full_messages => [''], :any? => true}))#{:count => 2, :full_messages => ['1']})
        @result = helper.errors_helper(@model)
      end
      
      it 'should output errors count for more than one error' do
        @result.should include(I18n.t('errors.template.header.other', :model => @model_name.downcase, :count => @errors_count))
      end
    end
  end
end