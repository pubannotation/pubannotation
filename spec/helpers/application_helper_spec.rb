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
    require 'utfrewrite'
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

  describe 'sort_order' do
    before do
      @case_insensitive_array = [@sort_key]
      # stub_const('StubModel::CaseInsensitiveArray', @case_insensitive_array)
      @default_sort_key_1 = 'ASC'
      @default_sort_key_2 = 'DESC'
      @default_sort_array = [['name_1', @default_sort_key_1], ['name_2', @default_sort_key_2]]
      stub_const('StubModel::DefaultSortArray', @default_sort_array)
      @lower_sort_key = 'LOWER'
      helper.stub(:lower_sort_key).and_return(@lower_sort_key)
    end

    context 'when param[:sort_key] && params[:sort_direction] present' do
      before do
        @sort_direction = 'DESC'
        @model = StubModel
      end

      context 'when param[:sort_key] == my_project' do
        before do
          @sort_key = 'my_project'
          @params = {sort_key: @sort_key, sort_direction: @sort_direction}
          helper.stub(:params).and_return(@params)
          @current_user = FactoryGirl.create(:user)
          helper.stub(:current_user).and_return(@current_user)
        end

        it 'should call lower_sort_key with model and params[:sort_key]' do
          helper.should_receive(:lower_sort_key).with(@model, "CASE WHEN projects.user_id = #{@current_user.id} THEN 1 WHEN projects.user_id != 1 THEN 0 END")
          helper.sort_order(@model)
        end

        it 'should return lower_sort_key as sort_key and params[:direction] as sort_direction' do
          expect(helper.sort_order(StubModel)).to eql([[@lower_sort_key, @sort_direction]])
        end
      end

      context 'when param[:sort_key] != my_project' do
        before do
          @sort_key = 'sort_key'
          @params = {sort_key: @sort_key, sort_direction: @sort_direction}
          helper.stub(:params).and_return(@params)
        end

        it 'should call lower_sort_key with model and params[:sort_key]' do
          helper.should_receive(:lower_sort_key).with(@model, @sort_key)
          helper.sort_order(@model)
        end

        it 'should return lower_sort_key as sort_key and params[:direction] as sort_direction' do
          expect(helper.sort_order(StubModel)).to eql([[@lower_sort_key, @sort_direction]])
        end
      end
    end

    context 'when params[:sort_key] && params[:sort_direction] blank' do
      before do
        @model = StubModel
      end

      it 'should call lower_sort_key with model::DefaultSortArray' do
        helper.should_receive(:lower_sort_key).with(@model, @default_sort_array[0][0])
        helper.should_receive(:lower_sort_key).with(@model, @default_sort_array[1][0])
        helper.sort_order(@model)
      end

      it 'should return model::DefaultSortArray include lower sort key' do
        expect(helper.sort_order(@model)).to eql([[@lower_sort_key, @default_sort_key_1], [@lower_sort_key, @default_sort_key_2]])
      end
    end

    describe 'lower column' do
      before do
        @case_insensitive_array = %w(name)
        stub_const('StubModel::DefaultSortArray', @default_sort_array)
        stub_const('StubModel::CaseInsensitiveArray', @case_insensitive_array)
      end

      context 'when include CaseInsensitive column name' do
        it 'should return model::DefaultSortArray' do
          # p @sort_order = helper.sort_order(StubModel)
        end
      end
    end
  end

  describe 'lower_sort_key' do
    before do
      @case_insensitive_array = %w(name)
      stub_const('StubModel::CaseInsensitiveArray', @case_insensitive_array)
    end

    context 'when included in CaseInsensitive column name' do
      it 'should return LOWER(sort_key)' do
        @sort_key = @case_insensitive_array[0]
        expect(helper.lower_sort_key(StubModel, @sort_key)).to eql("LOWER(#{@sort_key})")
      end
    end

    context 'when not included in CaseInsensitive column name' do
      it 'should return sort_key' do
        @sort_key = @case_insensitive_array[0] + 'key'
        expect(helper.lower_sort_key(StubModel, @sort_key)).to eql(@sort_key)
      end
    end
  end

  describe 'sortable' do
    context 'when params[:controller] is not home' do
      context 'when title present' do
        before do
          @sort_key = 'sort_key'
          @lower_sort_key = 'LOWER'
          helper.stub(:lower_sort_key).and_return(@lower_sort_key)
          @model = double(:model)
          @title = 'title'
          helper.stub(:link_to).and_return(nil)
        end

        context 'when @sort_order present' do
          context 'when sort_key column is sorted' do
            context 'when sort direction is ASC' do
              before do
                @sort_direction = 'ASC'
                helper.stub(:sort_order).and_return([[@lower_sort_key, @sort_direction]])
              end

              context 'when params[:text] is present' do
                context 'when sort params present' do
                  before do
                    helper.stub(:params).and_return({text: 'text'})
                    @request_full_path = '?name=&description=&author=&user=&commit=search'
                    helper.stub_chain(:request, :fullpath).and_return(@request_full_path)
                  end

                  it 'should call link_to with search_projects params and sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                    helper.should_receive(:link_to).with(@title, "#{@request_full_path}&sort_direction=DESC&sort_key=#{@lower_sort_key}", {class: "sortable-#{@sort_direction}"})
                    helper.sortable(@model, @sort_key, @title)
                  end
                end

                context 'when sort params is nil' do
                  before do
                    helper.stub(:params).and_return({text: 'text'})
                  end

                  it 'should call link_to with sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                    helper.should_receive(:link_to).with(@title, "&sort_direction=DESC&sort_key=#{@lower_sort_key}", {class: "sortable-#{@sort_direction}"})
                    helper.sortable(@model, @sort_key, @title)
                  end
                end
              end

              context 'when params[:text] is nil' do
                it 'should call link_to with sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                  helper.should_receive(:link_to).with(@title, {sort_key: @lower_sort_key, sort_direction: 'DESC'}, {class: "sortable-#{@sort_direction}"})
                  helper.sortable(@model, @sort_key, @title)
                end
              end
            end

            context 'when sort direction is DESC' do
              before do
                @sort_direction = 'DESC'
                helper.stub(:sort_order).and_return([[@lower_sort_key, @sort_direction]])
              end

              context 'when params[:text] is prensent' do
                context 'when sort params present' do
                  before do
                    helper.stub(:params).and_return({text: 'text'})
                    @request_full_path = '?name=&description=&author=&user=&commit=search'
                    helper.stub_chain(:request, :fullpath).and_return(@request_full_path)
                  end

                  it 'should call link_to with search_projects params and sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                    helper.should_receive(:link_to).with(@title, "#{@request_full_path}&sort_direction=ASC&sort_key=#{@lower_sort_key}", {class: "sortable-#{@sort_direction}"})
                    helper.sortable(@model, @sort_key, @title)
                  end
                end

                context 'when sort params is nil' do
                  before do
                    helper.stub(:params).and_return({text: 'text'})
                  end

                  it 'should call link_to with sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                    helper.should_receive(:link_to).with(@title, "&sort_direction=ASC&sort_key=#{@lower_sort_key}", {class: "sortable-#{@sort_direction}"})
                    helper.sortable(@model, @sort_key, @title)
                  end
                end
              end

              context 'when params[:text] is nil' do
                it 'should call link_to with sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                  helper.should_receive(:link_to).with(@title, {sort_key: @lower_sort_key, sort_direction: 'ASC'}, {class: "sortable-#{@sort_direction}"})
                  helper.sortable(@model, @sort_key, @title)
                end
              end
            end
          end

          context 'when sort_key column is not sorted' do
            context 'when sort direction is ASC' do
              before do
                @sort_direction = 'ASC'
                helper.stub(:sort_order).and_return([['key', @sort_direction]])
              end

              context 'when params[:text] is prensent' do
                context 'when sort params present' do
                  before do
                    helper.stub(:params).and_return({text: 'text'})
                    @request_full_path = '?name=&description=&author=&user=&commit=search'
                    helper.stub_chain(:request, :fullpath).and_return(@request_full_path)
                  end

                  it 'should call link_to with search_projects params and sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                    helper.should_receive(:link_to).with(@title, "#{@request_full_path}&sort_direction=ASC&sort_key=#{@lower_sort_key}", {class: "sortable-DESC"})
                    helper.sortable(@model, @sort_key, @title)
                  end
                end

                context 'when sort params is nil' do
                  before do
                    helper.stub(:params).and_return({text: 'text'})
                  end

                  it 'should call link_to with sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                    helper.should_receive(:link_to).with(@title, "&sort_direction=ASC&sort_key=#{@lower_sort_key}", {class: "sortable-DESC"})
                    helper.sortable(@model, @sort_key, @title)
                  end
                end
              end

              context 'when params[:text] is nil' do
                it 'should call link_to with sort_key: lower_sort_key, sort_direction: current_direction, class: sortable-default direction(DESC)' do
                  helper.should_receive(:link_to).with(@title, {sort_key: @lower_sort_key, sort_direction: @sort_direction}, {class: "sortable-DESC"})
                  helper.sortable(@model, @sort_key, @title)
                end
              end
            end

            context 'when sort direction is DESC' do
              before do
                @sort_direction = 'DESC'
                helper.stub(:sort_order).and_return([['key', @sort_direction]])
              end

              context 'when params[:text] is prensent' do
                context 'when sort params present' do
                  before do
                    helper.stub(:params).and_return({text: 'text'})
                    @request_full_path = '?name=&description=&author=&user=&commit=search'
                    helper.stub_chain(:request, :fullpath).and_return(@request_full_path)
                  end

                  it 'should call link_to with search_projects params and sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                    helper.should_receive(:link_to).with(@title, "#{@request_full_path}&sort_direction=ASC&sort_key=#{@lower_sort_key}", {class: "sortable-DESC"})
                    helper.sortable(@model, @sort_key, @title)
                  end
                end

                context 'when sort params is nil' do
                  before do
                    helper.stub(:params).and_return({text: 'text'})
                  end

                  it 'should call link_to with sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                    helper.should_receive(:link_to).with(@title, "&sort_direction=ASC&sort_key=#{@lower_sort_key}", {class: "sortable-DESC"})
                    helper.sortable(@model, @sort_key, @title)
                  end
                end
              end

              context 'when params[:text] is nil' do
                it 'should call link_to with sort_key: lower_sort_key, sort_direction: another direction, class: sortable-current_direction' do
                  helper.should_receive(:link_to).with(@title, {sort_key: @lower_sort_key, sort_direction: 'ASC'}, {class: "sortable-DESC"})
                  helper.sortable(@model, @sort_key, @title)
                end
              end
            end
          end
        end
      end
    end

    context 'when params[:controller] is home' do

    end
  end

  describe 'total_number' do
    context 'when list respond_to total_entries' do
      before do
        @list = double(:list, total_entries: 30, size: 10)
      end

      it 'should return list.total_entries' do
        expect(helper.total_number(@list, 'projects')).to eql(t('views.projects.total_number', total_number: @list.total_entries))
      end
    end
    
    context 'when list not respond_to total_entries' do
      before do
        @list = double(:list, size: 10)
      end

      it 'should return list.size' do
        expect(helper.total_number(@list, 'projects')).to eql(t('views.projects.total_number', total_number: @list.size))
      end
    end
  end
end
