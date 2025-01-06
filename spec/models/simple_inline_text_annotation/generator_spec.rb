require 'rails_helper'

RSpec.describe SimpleInlineTextAnnotation::Generator, type: :model do
  describe '#generate' do
    subject { SimpleInlineTextAnnotation.generate(source) }

    context 'when source has denotations' do
      let(:source) { {
        "text": "Elon Musk is a member of the PayPal Mafia.",
        "denotations":[
          {"span":{"begin": 0, "end": 9}, "obj":"Person"},
          {"span":{"begin": 29, "end": 41}, "obj":"Organization"},
        ]
        } }
      let(:expected_format) { '[Elon Musk][Person] is a member of the [PayPal Mafia][Organization].' }

      it 'generate annotation structure' do
        is_expected.to eq(expected_format)
      end
    end
  end
end
