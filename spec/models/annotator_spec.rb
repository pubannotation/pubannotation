require 'spec_helper'

describe Annotator do
  describe 'editable?' do
    let!(:annotator) { FactoryGirl.create(:annotator) }

    context 'when current_user present' do
      let!(:current_user) { FactoryGirl.create(:user) }

      context 'when self.user == current_user' do
        before do
          annotator.stub(:user).and_return(current_user)
        end

        it 'should return true' do
          expect( annotator.editable?(current_user) ).to be_true
        end
      end

      context 'when self.user != current_user' do
        before do
          annotator.stub(:user).and_return(nil)
        end

        it 'should return false' do
          expect( annotator.editable?(current_user) ).to be_false
        end
      end
    end

    context 'when current_user nil' do
      it 'should return false' do
        expect( annotator.editable?(nil) ).to be_false
      end
    end
  end
end
