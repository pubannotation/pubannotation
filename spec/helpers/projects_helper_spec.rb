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
end
