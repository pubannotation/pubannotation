# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StoreAnnotationsCollectionUploadJob, type: :job do
  let!(:user) { create(:user) }
  let!(:project) { create(:project, user: user) }
  let!(:doc1) { create(:doc, sourcedb: 'PMC', sourceid: '123456') }
  let!(:doc2) { create(:doc, sourcedb: 'PMC', sourceid: '789012') }
  let!(:project_doc1) { create(:project_doc, project: project, doc: doc1) }
  let!(:project_doc2) { create(:project_doc, project: project, doc: doc2) }

  describe 'counter update methods' do
    let(:job_instance) { described_class.new }

    before do
      job_instance.instance_variable_set(:@project, project)

      # Create annotations directly
      create_list(:denotation, 5, project: project, doc: doc1)
      create_list(:block, 3, project: project, doc: doc1)
      create_list(:denotation, 7, project: project, doc: doc2)
      create_list(:block, 2, project: project, doc: doc2)
    end

    it 'project.update_annotation_stats_from_database updates project_docs for the project' do
      project.update_annotation_stats_from_database

      project_doc1.reload
      expect(project_doc1.denotations_num).to eq(5)
      expect(project_doc1.blocks_num).to eq(3)

      project_doc2.reload
      expect(project_doc2.denotations_num).to eq(7)
      expect(project_doc2.blocks_num).to eq(2)
    end

    it 'project.update_annotation_stats_from_database updates docs for the project' do
      project.update_annotation_stats_from_database

      doc1.reload
      expect(doc1.denotations_num).to eq(5)
      expect(doc1.blocks_num).to eq(3)

      doc2.reload
      expect(doc2.denotations_num).to eq(7)
      expect(doc2.blocks_num).to eq(2)
    end

    it 'update_final_project_stats updates project counters from database' do
      job_instance.send(:update_final_project_stats)

      project.reload
      expect(project.denotations_num).to eq(12)  # 5 + 7
      expect(project.blocks_num).to eq(5)        # 3 + 2
      expect(project.relations_num).to eq(0)
    end

    it 'update_final_project_stats updates all three tables' do
      job_instance.send(:update_final_project_stats)

      # Verify project
      project.reload
      expect(project.denotations_num).to eq(12)
      expect(project.blocks_num).to eq(5)

      # Verify project_docs
      project_doc1.reload
      expect(project_doc1.denotations_num).to eq(5)
      expect(project_doc1.blocks_num).to eq(3)

      project_doc2.reload
      expect(project_doc2.denotations_num).to eq(7)
      expect(project_doc2.blocks_num).to eq(2)

      # Verify docs
      doc1.reload
      expect(doc1.denotations_num).to eq(5)
      expect(doc1.blocks_num).to eq(3)

      doc2.reload
      expect(doc2.denotations_num).to eq(7)
      expect(doc2.blocks_num).to eq(2)
    end

    it 'maintains cross-table consistency after update' do
      job_instance.send(:update_final_project_stats)

      # Verify consistency: doc count = sum of its project_docs
      doc1.reload
      project_doc1.reload

      expect(doc1.denotations_num).to eq(project_doc1.denotations_num)
      expect(doc1.blocks_num).to eq(project_doc1.blocks_num)

      # Verify project total = sum across all docs
      project.reload
      total_denotations = ProjectDoc.where(project: project).sum(:denotations_num)
      total_blocks = ProjectDoc.where(project: project).sum(:blocks_num)

      expect(project.denotations_num).to eq(total_denotations)
      expect(project.blocks_num).to eq(total_blocks)
    end

    it 'updates counters correctly when annotations are added incrementally' do
      # Initial update
      job_instance.send(:update_final_project_stats)

      project.reload
      initial_count = project.denotations_num
      expect(initial_count).to eq(12)

      # Add more annotations
      create_list(:denotation, 10, project: project, doc: doc1)

      # Update again
      job_instance.send(:update_final_project_stats)

      project.reload
      expect(project.denotations_num).to eq(22)  # 12 + 10
    end

    it 'handles empty project gracefully' do
      empty_project = create(:project, user: user)
      empty_doc = create(:doc)
      create(:project_doc, project: empty_project, doc: empty_doc)

      empty_job = described_class.new
      empty_job.instance_variable_set(:@project, empty_project)

      expect {
        empty_job.send(:update_final_project_stats)
      }.not_to raise_error

      empty_project.reload
      expect(empty_project.denotations_num).to eq(0)
      expect(empty_project.blocks_num).to eq(0)
    end
  end

  describe 'counter accuracy' do
    it 'project counters match actual database counts' do
      # Create annotations
      create_list(:denotation, 15, project: project, doc: doc1)
      create_list(:block, 8, project: project, doc: doc2)

      job_instance = described_class.new
      job_instance.instance_variable_set(:@project, project)

      job_instance.send(:update_final_project_stats)

      project.reload

      # Verify counts match database
      expect(project.denotations_num).to eq(Denotation.where(project: project).count)
      expect(project.blocks_num).to eq(Block.where(project: project).count)
      expect(project.relations_num).to eq(Relation.where(project: project).count)
    end
  end
end
