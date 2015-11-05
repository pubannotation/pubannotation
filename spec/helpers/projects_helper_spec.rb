# encoding: utf-8
require 'spec_helper'

describe ProjectsHelper do
  describe 'namespaces_prefix_input_fields' do
    context 'when render for new record' do
      before do
        assign :project, double(:project, {namespaces_prefixes: nil})
      end

      it 'should render partial template without collection' do
        helper.should_receive(:render).with({partial: 'namespace_prefix_input' })
        helper.namespaces_prefix_input_fields
      end
    end

    context 'when render for existing record' do
      before do
        @namespaces_prefixes = [{"prefix" => "rdf", "uri" => "rdf-uri"}]
        assign :project, double(:project, {namespaces_prefixes: @namespaces_prefixes})
      end

      it 'should render partial template with collection' do
        helper.should_receive(:render).with({partial: 'namespace_prefix_input', collection: @namespaces_prefixes })
        helper.namespaces_prefix_input_fields
      end
    end
  end

  describe 'format_namespaces' do
    context 'when namespaces_base present' do
      before do
        @namespaces_base = {"prefix" => "_base", "uri" => "base-uri"}
      end

      context 'when namespaces_prefixes present' do
        before do
          @namespaces_prefixes = [{"prefix" => "rdf", "uri" => "rdf-uri"}]
          assign :project, double(:project, {namespaces_base: @namespaces_base, namespaces_prefixes: @namespaces_prefixes})
        end

        it 'should return BASE and PREFIX' do
          helper.format_namespaces.should eql("BASE   &lt;#{@namespaces_base['uri']}&gt;<br />PREFIX #{@namespaces_prefixes[0]['prefix']}: &lt;#{@namespaces_prefixes[0]['uri']}&gt;<br />")
        end
      end

      context 'when namespaces_prefixes blank' do
        before do
          @namespaces_prefixes = nil
          assign :project, double(:project, {namespaces_base: @namespaces_base, namespaces_prefixes: @namespaces_prefixes})
        end

        it 'should return BASE' do
          helper.format_namespaces.should eql("BASE   &lt;#{@namespaces_base['uri']}&gt;<br />")
        end
      end
    end

    context 'when namespaces_base blank' do
      before do
        @namespaces_base = nil
      end

      context 'when namespaces_prefixes present' do
        before do
          @namespaces_prefixes = [{"prefix" => "rdf", "uri" => "rdf-uri"}]
          assign :project, double(:project, {namespaces_base: @namespaces_base, namespaces_prefixes: @namespaces_prefixes})
        end

        it 'should return PREFIX' do
          helper.format_namespaces.should eql("PREFIX #{@namespaces_prefixes[0]['prefix']}: &lt;#{@namespaces_prefixes[0]['uri']}&gt;<br />")
        end
      end

      context 'when namespaces_prefixes blank' do
        before do
          @namespaces_prefixes = nil
          assign :project, double(:project, {namespaces_base: @namespaces_base, namespaces_prefixes: @namespaces_prefixes})
        end

        it 'should return blank' do
          helper.format_namespaces.should be_blank
        end
      end
    end
  end

  describe 'link_to_project' do
    context 'when @doc, sourcedb and sourceid present' do
      before do
        @doc = FactoryGirl.create(:doc)
        @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      end

      context 'when @doc has_divs?' do
        before do
          @doc.stub(:has_divs?).and_return(true)
        end

        context 'params begin-end present' do
          before do
            @params = {begin: 0, end: 1}
            helper.stub(:params).and_return(@params)
          end

          it 'shoud return path include div and span begin-end' do
            expect(helper.link_to_project(@project)).to have_selector(:a, href: spans_project_sourcedb_sourceid_divs_docs_path(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial, @params[:begin], @params[:end]) )
          end
        end

        context 'params begin-end blank' do
          it 'shoud return path include div' do
            expect(helper.link_to_project(@project)).to have_selector(:a, href: show_project_sourcedb_sourceid_divs_docs_path(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial))
          end
        end
      end

      context 'when @doc has_divs? == false' do
        before do
          @doc.stub(:has_divs?).and_return(false)
        end

        context 'params begin-end present' do
          before do
            @params = {begin: 0, end: 1}
            helper.stub(:params).and_return(@params)
          end

          it 'shoud return path include doc and span begin-end' do
            expect(helper.link_to_project(@project)).to have_selector(:a, href: spans_project_sourcedb_sourceid_docs_path(@project.name, @doc.sourcedb, @doc.sourceid, @params[:begin], @params[:end]))
          end
        end

        context 'params begin-end blank' do
          it 'shoud return path include doc' do
            expect(helper.link_to_project(@project)).to have_selector(:a, href: show_project_sourcedb_sourceid_docs_path(@project.name, @doc.sourcedb, @doc.sourceid))
          end
        end
      end
    end
  end

  describe 'is_my_project?' do
    let ( :user ) { FactoryGirl.create(:user)} 
    let ( :another_user ) { FactoryGirl.create(:user)} 
    let ( :project ) { FactoryGirl.create(:project, user: user)} 

    before do
      helper.stub(:current_user).and_return(user)
    end

    context 'when project.user == current_user' do
      it 'should return  i tag' do
        helper.is_my_project?(project, user).should have_selector(:i)
      end
    end

    context 'when project.user == current_user' do
      it 'should return  i tag' do
        helper.is_my_project?(project, another_user).should_not have_selector(:i)
      end
    end
  end
end
