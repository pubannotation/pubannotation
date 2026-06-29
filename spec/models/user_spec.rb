# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe '#can_access_media?' do
    subject { user.can_access_media? }

    context 'when root' do
      let(:user) { build(:user, root: true, can_use_media: false) }
      it { is_expected.to be true }
    end

    context 'when can_use_media is true' do
      let(:user) { build(:user, root: false, can_use_media: true) }
      it { is_expected.to be true }
    end

    context 'when neither root nor can_use_media' do
      let(:user) { build(:user, root: false, can_use_media: false) }
      it { is_expected.to be false }
    end
  end
end
