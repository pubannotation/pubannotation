# encoding: utf-8
require 'spec_helper'

describe "annotations/_summary_and_view_options.html.erb" do
  before do
    @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
    assign :project, @project
    @doc = FactoryGirl.create(:doc)
    assign :doc, @doc
    @annotation_url = '/annotations'
    view.stub(:annotations_url_helper).and_return(@annotation_url)
    view.stub(:visualization_link).and_return('visual')
  end

  describe 'annotations_url_helper' do
    it 'should call annotations_url_helper with without_spans option once' do
      expect(view).to receive(:annotations_url_helper).with({without_spans: true}).once
      render
    end
  end

  describe 'annotation links' do
    before do
      render
    end

    it 'should have anchor tag for table' do
      expect(rendered).to have_selector(:a, href: @annotation_url, content: 'Table')
    end

    it 'should have anchor tag for JSON' do
      expect(rendered).to have_selector(:a, href: @annotation_url + '.json', content: 'JSON')
    end
  end

  describe 'visualization_link' do
    context 'when params[:action] == spand' do
      before do
        view.stub(:params).and_return({action: 'spans'})
      end

      it 'should call visualization_link' do
        view.should_receive(:visualization_link)
        render
      end
    end

    context 'when params[:action] != spand' do
      it 'should_not call visualization_link' do
        view.should_not_receive(:visualization_link)
        render
      end
    end
  end
end
