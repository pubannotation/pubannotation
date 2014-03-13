# encoding: utf-8
require 'spec_helper'

describe PMDoc do
  describe 'self.generate' do
    context 'when response code is 200' do
      before do
        pmid = '2626671'
        VCR.use_cassette 'lib/pmdoc/generate/response_code_200' do
          @result = PMDoc.generate(pmid)
        end
      end
      
      it 'should return new Doc' do
        @result.class.should eql(Doc)
      end
    end

    context 'when response code is not 200' do
      before do
        pmid = '0'
        VCR.use_cassette 'lib/pmdoc/generate/response_code_nil' do
          @result = PMDoc.generate(pmid)
        end
      end
      
      it 'should return nil' do
        @result.should be_nil
      end
    end
  end
  
  describe 'add_to_project' do
    before do
      @project = FactoryGirl.create(:project)
      @sourceid = '1234'
      @num_created = 0
      @num_added = 0
      @num_failed = 0
    end
    
    context 'when doc present' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @sourceid, :serial => 0)
      end
      
      describe 'before execute' do
        it '@project should not include @doc' do
          @project.docs.should_not include(@doc)
        end
      end
      
      context 'when project.doc not include doc' do
        before do
          @result = PMDoc.add_to_project(@project, @sourceid, 0, 0, 0)
          @project.reload
        end

        it '@project should include @doc' do
          @project.docs.should include(@doc)
        end
        
        it 'should increment num_added' do
          @result.should eql [@num_created + 1, @num_failed]
        end
      end
      
      context 'when project.doc include doc' do
        before do
          @project.docs << @doc
          @project.reload
        end
        
        describe 'before execute' do
          it '@project should include @doc' do
            @project.docs.should include(@doc)
          end
        end
        
        before do
          @result = PMDoc.add_to_project(@project, @sourceid, 0, 0, 0)
        end
        
        it 'should not increment num_added' do
          @result.should eql [@num_created, @num_failed]
        end
      end
    end
    
    context 'when doc blank' do
      context 'when generate crates doc successfully' do
        before do
          @generated_doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 'new sourceid', :serial => 0)
          PMDoc.stub(:generate).and_return(@generated_doc)
          @result = PMDoc.add_to_project(@project, @sourceid, 0, 0, 0)
        end
        
        it 'should increment num_added' do
          @result.should eql [@num_created + 1, @num_failed]
        end
      end
      
      context 'when generate crates doc unsuccessfully' do
        before do
          PMDoc.stub(:generate).and_return(nil)
          @result = PMDoc.add_to_project(@project, @sourceid, 0, 0, 0)
        end
        
        it 'should not increment num_failed' do
          @result.should eql [@num_created, @num_failed + 1]
        end
      end
    end
  end
end