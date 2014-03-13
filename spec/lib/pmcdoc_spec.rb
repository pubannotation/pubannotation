# encoding: utf-8
require 'spec_helper'

describe PMCDoc do
  describe 'self.generate' do
    context 'when pmcdoc.doc exists' do
      context 'and when divs exists' do
        before do
          VCR.use_cassette 'lib/pmcdoc/generate/div_exists' do
            @result = PMCDoc.generate('2626672')
          end
        end
        
        it 'should return docs and nil' do
          @result[0].collect{|doc| doc.class}.uniq[0].should eql(Doc)
          @result[1].should be_nil
        end
      end

      context 'and when divs does not exists' do
        before do
          PMCDoc.any_instance.stub(:get_divs).and_return(nil)
          VCR.use_cassette 'lib/pmcdoc/generate/div_does_not_exists' do
            @result = PMCDoc.generate('2626671')
          end
        end
        
        it 'should return nil and nobody message' do
          @result.should eql([nil, "no body in the document."])
        end
      end
    end
    
    context 'when pmcdoc.doc does not exists' do
      before do
        @result = PMCDoc.generate('0')
      end
      
      it 'should return nil and message' do
        @result.should eql([nil, 'PubMed Central unreachable.'])
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
    
    context 'when divs present' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => @sourceid, :serial => 0)
        FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => @sourceid, :serial => 1)
      end
      
      describe 'before execute' do
        it '@project should not include @doc' do
          @project.docs.should_not include(@doc)
        end
      end      
      
      context 'when project docs not include divs.first' do
        before do
          @result = PMCDoc.add_to_project(@project, @sourceid, 0, 0, 0)
          @project.reload
        end

        it '@project should include @doc' do
          @project.docs.should include(@doc)
        end
        
        it 'should increment num_added by added docs size' do
          @result.should eql [Doc.find_all_by_sourcedb_and_sourceid('PMC', @sourceid).size, @num_failed]
        end        
      end
      
      context 'when project docs include divs.first' do
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
          @result = PMCDoc.add_to_project(@project, @sourceid, 0, 0, 0)
          @project.reload
        end

        it '@project should include @doc' do
          @project.docs.should include(@doc)
        end
        
        it 'should not increment num_added' do
          @result.should eql [@num_created, @num_failed]
        end      
      end
    end
    
    context 'when divs blank' do
      context 'when generate crates doc successfully' do
        before do
          @new_sourceid = 'new sourceid'
          @generated_doc_1 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => @new_sourceid, :serial => 0)
          @generated_doc_2 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => @new_sourceid, :serial => 1)
          
          PMCDoc.stub(:generate).and_return([[@generated_doc_1, @generated_doc_2], nil])
          @result = PMCDoc.add_to_project(@project, @sourceid, 0, 0, 0)
        end
        
        it 'should increment num_added' do
          @result.should eql [Doc.find_all_by_sourcedb_and_sourceid('PMC', @new_sourceid).size, @num_failed]
        end
      end
      
      context 'when generate crates doc unsuccessfully' do
        before do
          PMDoc.stub(:generate).and_return(nil)
          @result = PMCDoc.add_to_project(@project, @sourceid, 0, 0, 0)
        end
        
        it 'should not increment num_failed' do
          @result.should eql [@num_created, @num_failed + 1]
        end
      end     
    end
  end
end