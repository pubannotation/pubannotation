# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Relation, type: :model do
  let(:project) { create(:project) }
  let(:doc) { create(:doc) }
  let(:first) { create(:block, project:, doc:) }
  let(:second) { create(:block, project:, doc:) }
  let(:other) { create(:block, project:, doc:) }
  let!(:from_first) { create(:relation, project:, doc:, subj: first, obj: other) }
  let!(:to_second) { create(:relation, project:, doc:, subj: other, obj: second) }
  let!(:unrelated) { create(:relation, project:, doc:, subj: other, obj: other) }

  describe '.on_blocks' do
    it 'finds the ones from or to any of the blocks' do
      expect(Relation.on_blocks([first.id, second.id])).to contain_exactly(from_first, to_second)
    end
  end

  describe '.delete_on_blocks' do
    it 'deletes the ones from or to any of the blocks, with the attributes on them, counting them' do
      Attrivute.create!(project:, doc:, hid: 'A1', subj: from_first, obj: 'true', pred: 'checked')
      Attrivute.create!(project:, doc:, hid: 'A2', subj: unrelated, obj: 'true', pred: 'checked')

      expect(Relation.where(project:, doc:).delete_on_blocks([first.id, second.id])).to eq(2)
      expect(Relation.where(doc:)).to contain_exactly(unrelated)
      expect(Attrivute.where(doc:).pluck(:hid)).to eq(['A2'])
    end
  end
end
