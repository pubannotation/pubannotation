# encoding: utf-8
require 'spec_helper'

describe "docs/show.html.erb" do
  before do
    @doc = FactoryGirl.create(:doc,
      :sourcedb => 'sourcedb',
      :sourceid => 'sourceid',
      :serial => 0
    )
    assign :doc, @doc
    assign :text, 'text'
    view.stub(:current_user).and_return(nil)
    @annotation_url = '/annotations'
    view.stub(:annotations_url_helper).and_return(@annotation_url)
  end

  context 'when @project present' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      stub_template "annotations/_options" => 'test'
      view.stub(:user_signed_in?).and_return(false)
      assign :project, @project
    end

    describe 'counter' do
      before do
        @denotations_count_helper = 'denotations_count_helper'
        view.stub(:denotations_count_helper).and_return(@denotations_count_helper)
        @relations_count_helper = 'relations_count_helper'
        view.stub(:relations_count_helper).and_return(@relations_count_helper)
        render
      end
      
      it 'should render denotations_count_helper' do
        rendered.should include(@denotations_count_helper)
      end
      
      it 'should render relations_count_helper' do
        rendered.should include(@relations_count_helper)
      end
    end
  end

  describe 'annotaitons link' do
    context 'when @project.blank?' do
      before do
        render
      end

      it 'should render annotaitons link' do
        expect(rendered).to have_selector(:a, href: @annotation_url, content: I18n.t('views.shared.annotations'))
      end
    end

    context 'when @project.present' do
      before do
        assign :project, FactoryGirl.create(:project, user: FactoryGirl.create(:user))
        view.stub(:user_signed_in?).and_return(false)
        render
      end

      it 'should not  render annotaitons link' do
        expect(rendered).not_to have_selector(:a, href: @annotation_url, content: I18n.t('views.shared.annotations'))
      end
    end
  end
end
