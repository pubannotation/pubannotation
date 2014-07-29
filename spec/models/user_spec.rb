require 'spec_helper'

describe User do
  describe 'email uniqueness' do
    before do
      @email = 'test@email.com'
      @username = 'user name'
      FactoryGirl.create(:user, email: @email, username: @username)
    end

    context 'when email already taken' do
      before do
        @user = User.new(username: 'uname', email: @email, password: 'password')
      end

      it 'should not valid and return errors on email' do
        @user.valid?.should be_false
        @user.errors.messages.should eql({:email => ["has already been taken"]})
      end
    end

    context 'when username already taken' do
      before do
        @user = User.new(username: @username, email: 'newe@email.com', password: 'password')
      end

      it 'should not valid and return errors on username' do
        @user.valid?.should be_false
        @user.errors.messages.should eql({:username => ["has already been taken"]})
      end
    end
  end 
  
  describe 'check_invalid_character' do
    context 'when not include invalid character' do
      it 'shoud not raise validation error' do
        User.new(email: 'email@mail.check.com', password: 'password', username:'user').valid?.should be_true
      end
    end

    context 'when include /' do
      before do
        @user = User.new(email: 'email', password: 'password', username:'us/er')
      end

      it 'shoud raise validation error' do
        @user.valid?
        @user.errors.messages[:username].should eql([I18n.t('errors.messages.invalid_character_included')])
      end
    end

    context 'when include .' do
      before do
        @user = User.new(email: 'email', password: 'password', username:'us.er')
      end

      it 'shoud raise validation error' do
        @user.valid?
        @user.errors.messages[:username].should eql([I18n.t('errors.messages.invalid_character_included')])
      end
    end

    context 'when include ?' do
      before do
        @user = User.new(email: 'email', password: 'password', username:'us?er')
      end

      it 'shoud raise validation error' do
        @user.valid?
        @user.errors.messages[:username].should eql([I18n.t('errors.messages.invalid_character_included')])
      end
    end

    context 'when include #' do
      before do
        @user = User.new(email: 'email', password: 'password', username:'us#er')
      end

      it 'shoud raise validation error' do
        @user.valid?
        @user.errors.messages[:username].should eql([I18n.t('errors.messages.invalid_character_included')])
      end
    end

    context 'when include %' do
      before do
        @user = User.new(email: 'email', password: 'password', username:'us%er')
      end

      it 'shoud raise validation error' do
        @user.valid?
        @user.errors.messages[:username].should eql([I18n.t('errors.messages.invalid_character_included')])
      end
    end
  end

  describe 'username_changed' do
    before do
      @user = FactoryGirl.create(:user)
      @user.attributes = {username: 'new username'}#.should raise_exception
    end

    it 'shoud not update username' do
      @user.save.should be_false
      @user.errors.messages[:username].should eql([I18n.t('errors.messages.unupdatable')])
    end
  end

  describe 'scope except_current_user' do
    before do
      @current_user = FactoryGirl.create(:user)
      @anothers_user = FactoryGirl.create(:user)
      @users = User.except_current_user(@current_user)
    end
    
    it 'should include not current_user' do
      @users.should include(@anothers_user)
    end
    
    it 'should not include current_user' do
      @users.should_not include(@current_user)
    end
  end
  
  describe 'scope :except_project_associate_maintainers' do
    before do
      @project = FactoryGirl.create(:project)
      @associate_maintainer_user = FactoryGirl.create(:user)
      @not_associate_user = FactoryGirl.create(:user)
    end
    
    context 'when associate_maintainers present' do
      before do
        FactoryGirl.create(:associate_maintainer, :project => @project, :user => @associate_maintainer_user)
        @users = User.except_project_associate_maintainers(@project.id)
      end
      
      it 'should include not associate maintainer user' do
        @users.should include(@not_associate_user)
      end
      
      it 'should not include associate maintainer user' do
        @users.should_not include(@associate_maintainer_user)
      end
    end
    
    context 'when associate_maintainers present' do
      before do
        @users = User.except_project_associate_maintainers(@project.id)
      end
      
      it 'should include all users' do
        @users.to_a.should =~ User.all
      end
    end
  end
  
  describe 'has_many :associate_maintainers' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @user = FactoryGirl.create(:user)
      @associate_maintainer_1 = FactoryGirl.create(:associate_maintainer, 
        :user => @user,
        :project => @project)
      @associate_maintainer_2 = FactoryGirl.create(:associate_maintainer, 
        :user => @user,
        :project => @project)      
    end
    
    it 'should be present' do
      @user.associate_maintainers.should be_present
    end
    
    it 'should include associate_maineiners' do
      @user.associate_maintainers.to_a.should =~ [@associate_maintainer_1, @associate_maintainer_2]
    end
    
    it 'should destory all associate maintainers when detroyed' do
      @user.destroy
      AssociateMaintainer.all.should be_blank
    end
  end

  describe 'has_many projects' do
    before do
      @user = FactoryGirl.create(:user)
      @project_1 = FactoryGirl.create(:project, :user => @user)
      @project_2 = FactoryGirl.create(:project, :user => @user)
    end
    
    it 'should be present' do
      @user.projects.should be_present
    end
    
    it 'should include projects' do
      @user.projects.to_a.to_a.should =~ [@project_1, @project_2]
    end
  end
  
  describe 'has_many :associate_maintaiain_projecs' do
    before do
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @user = FactoryGirl.create(:user)
      @associate_maintainer_1 = FactoryGirl.create(:associate_maintainer, 
        :user => @user,
        :project => @project_1)
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @associate_maintainer_2 = FactoryGirl.create(:associate_maintainer, 
        :user => @user,
        :project => @project_2)      
    end
    
    it 'should be present' do
      @user.associate_maintaiain_projects.should be_present
    end
    
    it 'should include associate_maineiners' do
      @user.associate_maintaiain_projects.to_a.should =~ [@project_1, @project_2]
    end
  end
  
  describe 'self.find_first_by_auth_conditions' do
    before do
      @user_name = 'user_name'
      @user = FactoryGirl.create(:user, :username => @user_name)
    end

    context 'when conditions include login' do
      it 'should return user who matches login username' do
        User.find_first_by_auth_conditions({:login => @user_name}).should eql(@user)
      end
    end

    context 'when conditions does not include user name' do
      it '' do
        User.find_first_by_auth_conditions({:id => @user.id}).should eql(@user)
      end
    end
  end
end
