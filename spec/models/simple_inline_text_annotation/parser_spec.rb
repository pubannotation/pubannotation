require 'rails_helper'

RSpec.describe SimpleInlineTextAnnotation::Parser, type: :model do
  describe '#parse' do
    subject { SimpleInlineTextAnnotation.parse(source).to_json }

    context 'when source has annotation structure' do
      let(:source) { '[Elon Musk][Person] is a member of the [PayPal Mafia][Organization].' }
      let(:expected_format) { {
        "text": "Elon Musk is a member of the PayPal Mafia.",
        "denotation":[
            {"span":{"begin": 0, "end": 8}, "obj":"Person"},
            {"span":{"begin": 29, "end": 40}, "obj":"Organization"},
          ]
      }.to_json }

      it 'parse as denotation' do
        is_expected.to eq(expected_format)
      end
    end

    context 'when surce has reference structure' do
      let(:source) do
        <<~MD2
          [Elon Musk][Person] is a member of the [PayPal Mafia][Organization].

          [Person]: https://example.com/Person
          [Organization]: https://example.com/Organization
        MD2
      end
      let(:expected_format) { {
        "text": "Elon Musk is a member of the PayPal Mafia.",
        "denotation":[
            {"span":{"begin": 0, "end": 8}, "obj":"https://example.com/Person"},
            {"span":{"begin": 29, "end": 40}, "obj":"https://example.com/Organization"},
          ],
        "config": {
          "entity types": [
            { "id": "https://example.com/Person", "label": "Person" },
            { "id": "https://example.com/Organization", "label": "Organization" }
          ]
        }
      }.to_json }

      it 'parse as entity types and apply id to denotation obj' do
        is_expected.to eq(expected_format)
      end
    end

    context 'when source has metacharacter escape' do
      let(:source) { '\[Elon Musk][Person] is a member of the [PayPal Mafia][Organization].' }
      let(:expected_format) { {
        "text": "[Elon Musk][Person] is a member of the PayPal Mafia.",
        "denotation":[
            {"span":{"begin": 40, "end": 51}, "obj":"Organization"}
          ]
      }.to_json }

      it 'is not parsed as annotation' do
        is_expected.to eq(expected_format)
      end
    end

    context 'when reference definitions do not have a blank line above' do
      let(:source) do
        <<~MD2
          [Elon Musk][Person] is a member of the PayPal Mafia.
          [Person]: https://example.com/Person
        MD2
      end
      let(:expected_format) { {
        "text": "Elon Musk is a member of the PayPal Mafia.\n[Person]: https://example.com/Person",
        "denotation":[
            {"span":{"begin": 0, "end": 8}, "obj":"Person"}
          ]
      }.to_json }

      it 'does not use as references' do
        is_expected.to eq(expected_format)
      end
    end

    context 'when reference definitions have a blank line above' do
      let(:source) do
        <<~MD2
          [Elon Musk][Person] is a member of the PayPal Mafia.

          [Person]: https://example.com/Person
        MD2
      end
      let(:expected_format) { {
        "text": "Elon Musk is a member of the PayPal Mafia.",
        "denotation":[
            {"span":{"begin": 0, "end": 8}, "obj":"https://example.com/Person"}
          ],
        "config": {
          "entity types": [
            { "id": "https://example.com/Person", "label": "Person" }
          ]
        }
      }.to_json }

      it 'use definitions as references' do
        is_expected.to eq(expected_format)
      end
    end

    context 'when text is written below the reference definition' do
      let(:source) do
        <<~MD2
          [Elon Musk][Person] is a member of the PayPal Mafia.

          [Person]: https://example.com/Person
          hello
        MD2
      end
      let(:expected_format) { {
        "text": "Elon Musk is a member of the PayPal Mafia.\n\nhello",
        "denotation":[
            {"span":{"begin": 0, "end": 8}, "obj":"https://example.com/Person"}
          ],
        "config": {
          "entity types": [
            { "id": "https://example.com/Person", "label": "Person" }
          ]
        }
      }.to_json }

      it 'parse as expected format' do
        is_expected.to eq(expected_format)
      end
    end

    context 'when reference id is duplicated' do
      let(:source) do
        <<~MD2
          [Elon Musk][Person] is a member of the PayPal Mafia.

          [Person]: https://example.com/Person
          [Person]: https://example.com/Organization
        MD2
      end
      let(:expected_format) { {
        "text": "Elon Musk is a member of the PayPal Mafia.",
        "denotation":[
            {"span":{"begin": 0, "end": 8}, "obj":"https://example.com/Person"},
          ],
        "config": {
          "entity types": [
            { "id": "https://example.com/Person", "label": "Person" }
          ]
        }
      }.to_json }

      it 'use first defined id in priority' do
        is_expected.to eq(expected_format)
      end
    end

    context 'when reference label and id is same' do
      let(:source) do
        <<~MD2
          [Elon Musk][Person] is a member of the PayPal Mafia.

          [Person]: Person
          MD2
      end
      let(:expected_format) { {
        "text": "Elon Musk is a member of the PayPal Mafia.",
        "denotation":[
            {"span":{"begin": 0, "end": 8}, "obj":"Person"},
          ],
      }.to_json }

      it 'is do not create config' do
        is_expected.to eq(expected_format)
      end
    end
  end
end
