# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectDoc, '#save_annotations message format', type: :model do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:doc) { create(:doc, sourcedb: 'PMC', sourceid: '12345', body: 'Sample text.') }
  let!(:project_doc) { create(:project_doc, project: project, doc: doc, denotations_num: 5, blocks_num: 2) }

  describe 'messages returned by save_annotations are compatible with Job#add_message' do
    context 'when upload is skipped due to existing annotations' do
      it 'returns a hash with sourcedb, sourceid, and body' do
        messages = project_doc.save_annotations({ text: doc.body }, { mode: :skip })

        expect(messages.length).to eq(1)
        message = messages.first
        expect(message).to be_a(Hash)
        expect(message[:sourcedb]).to eq('PMC')
        expect(message[:sourceid]).to eq('12345')
        expect(message[:body]).to eq('Upload is skipped due to existing annotations')
      end

      it 'can be passed to Job#add_message without error' do
        job = create(:job, organization: project)
        messages = project_doc.save_annotations({ text: doc.body }, { mode: :skip })

        expect {
          messages.each { |m| job.add_message(m) }
        }.not_to raise_error

        expect(job.messages.last.body).to eq('Upload is skipped due to existing annotations')
        expect(job.messages.last.sourcedb).to eq('PMC')
        expect(job.messages.last.sourceid).to eq('12345')
      end
    end

    context 'when text does not match the original document' do
      it 'returns a hash with sourcedb, sourceid, and body' do
        messages = project_doc.save_annotations({ text: 'Different text.' }, {})

        expect(messages.length).to eq(1)
        message = messages.first
        expect(message).to be_a(Hash)
        expect(message[:sourcedb]).to eq('PMC')
        expect(message[:sourceid]).to eq('12345')
        expect(message[:body]).to eq('The text in the annotations is not identical to the original document')
      end

      it 'can be passed to Job#add_message without error' do
        job = create(:job, organization: project)
        messages = project_doc.save_annotations({ text: 'Wrong text.' }, {})

        expect {
          messages.each { |m| job.add_message(m) }
        }.not_to raise_error

        expect(job.messages.last.body).to eq('The text in the annotations is not identical to the original document')
        expect(job.messages.last.sourcedb).to eq('PMC')
        expect(job.messages.last.sourceid).to eq('12345')
      end
    end
  end
end
