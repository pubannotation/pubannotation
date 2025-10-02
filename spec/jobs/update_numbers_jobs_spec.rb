# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Update Numbers Jobs', type: :job do
  include ActiveJob::TestHelper

  let!(:user) { create(:user) }
  let!(:project1) { create(:project, user: user) }
  let!(:project2) { create(:project, user: user) }

  let!(:doc1) { create(:doc) }
  let!(:doc2) { create(:doc) }
  let!(:doc3) { create(:doc) }

  let!(:pd1) { create(:project_doc, project: project1, doc: doc1) }
  let!(:pd2) { create(:project_doc, project: project1, doc: doc2) }
  let!(:pd3) { create(:project_doc, project: project2, doc: doc1) }
  let!(:pd4) { create(:project_doc, project: project2, doc: doc3) }

  before do
    # Create annotations
    create_list(:denotation, 5, project: project1, doc: doc1)
    create_list(:block, 3, project: project1, doc: doc1)

    create_list(:denotation, 7, project: project1, doc: doc2)
    create_list(:block, 2, project: project1, doc: doc2)

    create_list(:denotation, 4, project: project2, doc: doc1)
    create_list(:block, 6, project: project2, doc: doc3)
  end

  describe UpdateNumbersForProjectDocsJob do
    it 'updates counters for all docs in a project' do
      perform_enqueued_jobs do
        UpdateNumbersForProjectDocsJob.perform_later(project1)
      end

      # Verify project_docs for project1 were updated
      pd1.reload
      expect(pd1.denotations_num).to eq(5)
      expect(pd1.blocks_num).to eq(3)

      pd2.reload
      expect(pd2.denotations_num).to eq(7)
      expect(pd2.blocks_num).to eq(2)

      # Verify docs were updated (should count across ALL projects)
      doc1.reload
      expect(doc1.denotations_num).to eq(9)  # 5 from project1 + 4 from project2
      expect(doc1.blocks_num).to eq(3)       # 3 from project1 + 0 from project2

      doc2.reload
      expect(doc2.denotations_num).to eq(7)  # Only from project1
      expect(doc2.blocks_num).to eq(2)
    end

    it 'does not affect other projects' do
      # Set initial values for project2
      pd3.update_columns(denotations_num: 999, blocks_num: 999)
      pd4.update_columns(denotations_num: 999, blocks_num: 999)

      perform_enqueued_jobs do
        UpdateNumbersForProjectDocsJob.perform_later(project1)
      end

      # project2's project_docs should remain unchanged
      pd3.reload
      expect(pd3.denotations_num).to eq(999)

      pd4.reload
      expect(pd4.denotations_num).to eq(999)
    end

    it 'creates and completes job record' do
      job = nil
      perform_enqueued_jobs do
        UpdateNumbersForProjectDocsJob.perform_later(project1)
        job = Job.last
      end

      expect(job).to be_present
      expect(job.num_items).to eq(2)  # 2 steps
      expect(job.num_dones).to eq(2)  # Completed
    end
  end

  describe UpdateNumbersForDocsJob do
    it 'updates counters for all docs globally' do
      # Create admin project (parameter is not used but required)
      admin_project = create(:project, user: user)

      perform_enqueued_jobs do
        UpdateNumbersForDocsJob.perform_later(admin_project)
      end

      # All project_docs should be updated
      pd1.reload
      expect(pd1.denotations_num).to eq(5)
      expect(pd1.blocks_num).to eq(3)

      pd2.reload
      expect(pd2.denotations_num).to eq(7)
      expect(pd2.blocks_num).to eq(2)

      pd3.reload
      expect(pd3.denotations_num).to eq(4)
      expect(pd3.blocks_num).to eq(0)

      pd4.reload
      expect(pd4.denotations_num).to eq(0)
      expect(pd4.blocks_num).to eq(6)

      # All docs should be updated
      doc1.reload
      expect(doc1.denotations_num).to eq(9)   # 5 + 4
      expect(doc1.blocks_num).to eq(3)        # 3 + 0

      doc2.reload
      expect(doc2.denotations_num).to eq(7)
      expect(doc2.blocks_num).to eq(2)

      doc3.reload
      expect(doc3.denotations_num).to eq(0)
      expect(doc3.blocks_num).to eq(6)
    end

    it 'maintains cross-table consistency' do
      admin_project = create(:project, user: user)

      perform_enqueued_jobs do
        UpdateNumbersForDocsJob.perform_later(admin_project)
      end

      # Verify doc1 count = sum of its project_docs
      doc1.reload
      pd1.reload
      pd3.reload

      expect(doc1.denotations_num).to eq(pd1.denotations_num + pd3.denotations_num)
      expect(doc1.blocks_num).to eq(pd1.blocks_num + pd3.blocks_num)

      # Verify doc2 count = its single project_doc
      doc2.reload
      pd2.reload

      expect(doc2.denotations_num).to eq(pd2.denotations_num)
      expect(doc2.blocks_num).to eq(pd2.blocks_num)
    end

    it 'creates and completes job record' do
      admin_project = create(:project, user: user)
      job = nil

      perform_enqueued_jobs do
        UpdateNumbersForDocsJob.perform_later(admin_project)
        job = Job.last
      end

      expect(job).to be_present
      expect(job.num_items).to eq(2)  # 2 steps
      expect(job.num_dones).to eq(2)  # Completed
    end
  end

  describe 'integration between jobs' do
    it 'UpdateNumbersForProjectDocsJob updates only scoped docs' do
      # First, update globally to establish baseline
      admin_project = create(:project, user: user)
      perform_enqueued_jobs do
        UpdateNumbersForDocsJob.perform_later(admin_project)
      end

      # Add more annotations to project1
      create_list(:denotation, 10, project: project1, doc: doc1)

      # Update only project1
      perform_enqueued_jobs do
        UpdateNumbersForProjectDocsJob.perform_later(project1)
      end

      # project1's docs should be updated
      pd1.reload
      expect(pd1.denotations_num).to eq(15)  # 5 + 10

      doc1.reload
      expect(doc1.denotations_num).to eq(19)  # (5 + 10) from project1 + 4 from project2
    end
  end

  describe 'error resilience' do
    it 'completes successfully even with empty projects' do
      empty_project = create(:project, user: user)
      create(:project_doc, project: empty_project, doc: doc1)

      expect {
        perform_enqueued_jobs do
          UpdateNumbersForProjectDocsJob.perform_later(empty_project)
        end
      }.not_to raise_error

      # Should set counts to zero
      empty_pd = ProjectDoc.find_by(project: empty_project, doc: doc1)
      empty_pd.reload
      expect(empty_pd.denotations_num).to eq(0)
      expect(empty_pd.blocks_num).to eq(0)
    end
  end
end
