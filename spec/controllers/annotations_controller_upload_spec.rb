# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AnnotationsController#create_from_upload', type: :request do
  include Devise::Test::IntegrationHelpers

  before do
    allow(Elasticsearch::IndexQueue).to receive(:index_doc)
    allow(Elasticsearch::IndexQueue).to receive(:delete_doc)
    allow(Elasticsearch::IndexQueue).to receive(:update_embedding)
  end

  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:project) { create(:project, user: user) }
  let(:doc) { create(:doc, sourcedb: 'TestDB', sourceid: 'doc_1', body: 'Hello world. This is a test.') }
  let!(:project_doc) { create(:project_doc, project: project, doc: doc) }

  def upload_json(json_hash, mode: 'replace')
    file = Tempfile.new(['annotations', '.json'])
    file.write(json_hash.to_json)
    file.rewind

    post project_create_annotations_from_upload_path(project.name),
      params: {
        upfile: Rack::Test::UploadedFile.new(file.path, 'application/json', false, original_filename: 'test.json'),
        mode: mode
      }

    file.close
    file.unlink
  end

  context 'when annotations are valid' do
    it 'reports success' do
      sign_in user
      upload_json({
        sourcedb: doc.sourcedb,
        sourceid: doc.sourceid,
        text: doc.body,
        denotations: [{ id: 'T1', span: { begin: 0, end: 5 }, obj: 'test' }]
      })

      expect(response).to redirect_to(anything)
      expect(flash[:notice]).to eq('Annotations are successfully uploaded.')
    end

    it 'stores the denotations' do
      sign_in user
      upload_json({
        sourcedb: doc.sourcedb,
        sourceid: doc.sourceid,
        text: doc.body,
        denotations: [
          { id: 'T1', span: { begin: 0, end: 5 }, obj: 'test' },
          { id: 'T2', span: { begin: 6, end: 11 }, obj: 'test' }
        ]
      })

      expect(project.denotations.count).to eq(2)
    end
  end

  context 'when text alignment loses denotations' do
    it 'reports warnings instead of silent success' do
      sign_in user

      # Upload with text that differs from the stored doc body,
      # causing alignment to lose denotations and produce dangling attribute references
      upload_json({
        sourcedb: doc.sourcedb,
        sourceid: doc.sourceid,
        text: 'Completely different text that will not align.',
        denotations: [
          { id: 'T1', span: { begin: 0, end: 10 }, obj: 'test' },
          { id: 'T2', span: { begin: 12, end: 20 }, obj: 'test' }
        ],
        attributes: [
          { id: 'A1', subj: 'T1', pred: 'note', obj: 'value' }
        ]
      })

      expect(response).to redirect_to(anything)
      expect(flash[:notice]).to include('warnings')
    end
  end

  context 'when document does not exist' do
    it 'reports an error about the missing document' do
      sign_in user
      upload_json({
        sourcedb: 'NonExistent',
        sourceid: 'no_such_doc',
        text: 'Some text.',
        denotations: [{ id: 'T1', span: { begin: 0, end: 4 }, obj: 'test' }]
      })

      expect(response).to redirect_to(anything)
      expect(flash[:notice]).to include('NonExistent')
    end
  end

  context 'when user is not signed in' do
    it 'does not allow upload' do
      upload_json({
        sourcedb: doc.sourcedb,
        sourceid: doc.sourceid,
        text: doc.body,
        denotations: []
      })

      # Should not succeed - either redirect to sign in or error
      expect(flash[:notice]).not_to eq('Annotations are successfully uploaded.')
    end
  end
end
