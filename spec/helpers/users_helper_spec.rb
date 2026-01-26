# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsersHelper, type: :helper do
  describe '#user_link' do
    let(:user) { create(:user, username: 'testuser') }
    let(:root_user) { create(:user, username: 'rootuser', root: true) }
    let(:other_user) { create(:user, username: 'otheruser') }

    context 'when user is nil' do
      it 'returns Unknown' do
        expect(helper.user_link(nil)).to eq('Unknown')
      end
    end

    context 'when user is present and anonymize is false' do
      before { allow(helper).to receive(:current_user).and_return(nil) }

      it 'returns a link with username' do
        result = helper.user_link(user, false)
        expect(result).to include('<a')
        expect(result).to include('href="/users/testuser"')
        expect(result).to include('testuser')
      end

      it 'includes display:block style' do
        result = helper.user_link(user, false)
        expect(result).to include('display:block')
      end
    end

    context 'when user is present and anonymize is true' do
      context 'when current_user is nil' do
        before { allow(helper).to receive(:current_user).and_return(nil) }

        it 'returns only the anonymization icon' do
          result = helper.user_link(user, true)
          expect(result).to include('fa-user-secret')
          expect(result).not_to include('<a')
        end
      end

      context 'when current_user is a root user' do
        before { allow(helper).to receive(:current_user).and_return(root_user) }

        it 'returns a link with username and anonymization icon' do
          result = helper.user_link(user, true)
          expect(result).to include('<a')
          expect(result).to include('href="/users/testuser"')
          expect(result).to include('testuser')
          expect(result).to include('fa-user-secret')
        end
      end

      context 'when current_user is the same user' do
        before { allow(helper).to receive(:current_user).and_return(user) }

        it 'returns a link with username and anonymization icon' do
          result = helper.user_link(user, true)
          expect(result).to include('<a')
          expect(result).to include('href="/users/testuser"')
          expect(result).to include('testuser')
          expect(result).to include('fa-user-secret')
        end
      end

      context 'when current_user is a different non-root user' do
        before { allow(helper).to receive(:current_user).and_return(other_user) }

        it 'returns only the anonymization icon' do
          result = helper.user_link(user, true)
          expect(result).to include('fa-user-secret')
          expect(result).not_to include('<a')
        end
      end
    end
  end

  describe '#user_name' do
    let(:user) { create(:user, username: 'testuser') }

    context 'when user is nil' do
      it 'returns Unknown' do
        expect(helper.user_name(nil)).to eq('Unknown')
      end
    end

    context 'when user is present and anonymize is false' do
      it 'returns the username' do
        expect(helper.user_name(user, false)).to eq('testuser')
      end
    end

    context 'when user is present and anonymize is true' do
      it 'returns anonymized' do
        expect(helper.user_name(user, true)).to eq('anonymized')
      end
    end
  end
end
