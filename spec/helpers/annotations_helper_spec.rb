# encoding: utf-8
require 'spec_helper'

describe AnnotationsHelper do
  describe 'get_annotations' do
    context 'when doc exists' do
      context 'when project exists' do
        context 'when options spans present' do
          context 'when hdenotations, hinstances, hrelations, hmodifications exists' do
            before do
              @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
              @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
              @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc, :begin => 0, :end => 9)
              @instance = FactoryGirl.create(:instance, :project => @project, :obj => @denotation)
              @subcatrel = FactoryGirl.create(:subcatrel,:subj_id => @denotation.id, :obj => @denotation, :project => @project)
              @insmod = FactoryGirl.create(:modification, :obj => @instance, :project => @project)
            end
            
            context 'when project.presentt' do
              before do
                @result = helper.get_annotations(@project, @doc)
              end
              
              it 'should returns doc params, denotations, instances, relations and modifications' do
                @result.should eql({
                  :project => @project.name,
                  :source_db => @doc.sourcedb, 
                  :source_id => @doc.sourceid, 
                  :division_id => @doc.serial, 
                  :section => @doc.section, 
                  :text => @doc.body,
                  :denotations => [{:id => @denotation.hid, :span => {:begin => @denotation.begin, :end => @denotation.end}, :obj => @denotation.obj}],
                  :instances => [{:id => @instance.hid, :pred => @instance.pred, :obj => @instance.obj.hid}],
                  :relations => [{:id => @subcatrel.hid, :pred => @subcatrel.pred, :subj => @subcatrel.subj.hid, :obj => @subcatrel.obj.hid}],
                  :modifications => [{:id => @insmod.hid, :pred => @insmod.pred, :obj => @insmod.obj.hid}]
                  })
              end
            end
          end
        end
  
        context 'when options nothing' do
          context 'when hdenotations, hinstances, hrelations, hmodifications does not exists' do
            before do
              @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
              @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
              @result = helper.get_annotations(@project, @doc)
            end
            
            it 'should returns doc params' do
              @result.should eql({
              :project => @project.name,
                :source_db => @doc.sourcedb, 
                :source_id => @doc.sourceid, 
                :division_id => @doc.serial, 
                :section => @doc.section, 
                :text => @doc.body
                })
            end
          end
        
          context 'when hdenotations, hinstances, hrelations, hmodifications exists' do
            before do
              @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
              @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
              @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
              @instance = FactoryGirl.create(:instance, :project => @project, :obj => @denotation)
              @subcatrel = FactoryGirl.create(:subcatrel,:subj_id => @denotation.id, :obj => @denotation, :project => @project)
              @insmod = FactoryGirl.create(:modification, :obj => @instance, :project => @project)
              @result = helper.get_annotations(@project, @doc)
            end
            
            it 'should returns doc params, denotations, instances, relations and modifications' do
              @result.should eql({
                :project => @project.name,
                :source_db => @doc.sourcedb, 
                :source_id => @doc.sourceid, 
                :division_id => @doc.serial, 
                :section => @doc.section, 
                :text => @doc.body,
                :denotations => [{:id => @denotation.hid, :span => {:begin => @denotation.begin, :end => @denotation.end}, :obj => @denotation.obj}],
                :instances => [{:id => @instance.hid, :pred => @instance.pred, :obj => @instance.obj.hid}],
                :relations => [{:id => @subcatrel.hid, :pred => @subcatrel.pred, :subj => @subcatrel.subj.hid, :obj => @subcatrel.obj.hid}],
                :modifications => [{:id => @insmod.hid, :pred => @insmod.pred, :obj => @insmod.obj.hid}]
                })
            end
          end
        end
  
        context 'when option encoding ascii exist' do
          before do
            @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
            @get_ascii_text = 'DOC body'
            helper.stub(:get_ascii_text).and_return(@get_ascii_text)
            @result = helper.get_annotations(@project, @doc, :encoding => 'ascii')
          end
  
          it 'should return doc params and ascii encoded text' do
            @result.should eql({
              :project => @project.name,
              :source_db => @doc.sourcedb, 
              :source_id => @doc.sourceid, 
              :division_id => @doc.serial, 
              :section => @doc.section, 
              :text => @get_ascii_text})
          end
        end
  
        context 'when option :discontinuous_annotation exist' do
          before do
            @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
            @get_ascii_text = 'DOC body'
            @hdenotations = 'hdenotations'
            @hrelations = 'hrelations'
            helper.stub(:bag_denotations).and_return([@hdenotations, @hrelations])
            @result = helper.get_annotations(@project, @doc, :discontinuous_annotation => 'bag')
          end
          
          it 'should return doc params' do
            @result.should eql({
              :project => @project.name,
              :source_db => @doc.sourcedb, 
              :source_id => @doc.sourceid, 
              :division_id => @doc.serial, 
              :section => @doc.section, 
              :text => @doc.body,
              :denotations => @hdenotations,
              :relations => @hrelations
              })
          end
        end
      end
    end

    context 'anntet and doc does not exists' do
      before do
        @result = helper.get_annotations(nil, nil)
      end
      
      it 'should returns nil' do
        @result.should be_nil
      end
    end
  end  

  describe 'bag_denotations' do
    context 'when relation type = lexChain' do
      before do
        doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
        project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
        denotation1 = FactoryGirl.create(:denotation, :project => project, :doc => doc)
        denotation2 = FactoryGirl.create(:denotation, :project => project, :doc => doc)
        denotations = Array.new
        denotations << denotation1.get_hash << denotation2.get_hash
        relation = FactoryGirl.create(:relation, 
          :pred => '_lexChain',
          :obj_id => denotation1.id,
          :project => project,
          :subj_id => denotation2.id,
          :subj_type => 'Denotation')
        relations = Array.new
        relations << relation.get_hash
        @new_denotations, @new_relations = helper.bag_denotations(denotations, relations)
      end
      
      it 'denotations should be_blank' do
        @new_denotations[1].should be_blank
      end

      it 'denotations should be_blank' do
        @new_relations[0].should be_blank
      end
    end
    
    context 'when relation type not = lexChain' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
        @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
        @denotations = Array.new
        @denotations << @denotation.get_hash
        @relation = FactoryGirl.create(:relation, 
          :pred => 'NotlexChain',
          :obj => @denotation, 
          :project => @project,
          :subj_id => @denotation.id,
          :subj_type => 'Denotation'
        )
        @relations = Array.new
        @relations << @relation.get_hash
        @result = helper.bag_denotations(@denotations, @relations)
      end
      
      it 'denotations should be_blank' do
        @result[0][0].should eql({:id => "T1", :span => {:begin => 1 , :end => 5}, :obj => "Protein"})
      end
      
      it '' do
        @result[1][0].should eql(@relation.get_hash)
      end
    end
  end
end