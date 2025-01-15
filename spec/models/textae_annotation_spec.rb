require 'rails_helper'

RSpec.describe TextaeAnnotation, type: :model do
  describe '#clean_old_annotations' do
    context 'when creating new instance' do
      it 'should delete old annotations' do
        old_annotation = TextaeAnnotation.create(annotation: '{ "text": "hello" }', created_at: 2.days.ago)
        TextaeAnnotation.create(annotation: '{ "text": "hello" }')

        expect(TextaeAnnotation.count).to eq(1)
        expect(TextaeAnnotation.find_by(id: old_annotation.id)).to be_nil
      end
    end
  end
end
