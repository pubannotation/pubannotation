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

    context 'when source has config' do
      let(:source) { {
        "text": "Elon Musk is a member of the PayPal Mafia.",
        "denotations":[
            {"span":{"begin": 0, "end": 9}, "obj":"https://example.com/Person"},
            {"span":{"begin": 29, "end": 41}, "obj":"https://example.com/Organization"},
          ],
        "config": {
          "entity types": [
            { "id": "https://example.com/Person", "label": "Person" },
            { "id": "https://example.com/Organization", "label": "Organization" }
          ]
        }
      } }
      let(:expected_format) do
        <<~MD2.chomp
          [Elon Musk][Person] is a member of the [PayPal Mafia][Organization].

          [Person]: https://example.com/Person
          [Organization]: https://example.com/Organization
        MD2
      end

      it 'generate label definition structure' do
        is_expected.to eq(expected_format)
      end
    end
  end
end
