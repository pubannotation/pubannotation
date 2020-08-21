class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, :omniauth_providers => [:google_oauth2]

  # Setup accessible (or protected) attributes for your model
  attr_accessible :login, :username, :email, :password, :password_confirmation, :remember_me
  # attr_accessible :title, :body
  # Virtual attribute for authenticating by either username or email
  # This is in addition to a real persisted field like 'username'
  attr_accessor :login

  has_many :projects, :dependent => :destroy
  has_many :associate_maintainers, :dependent => :destroy
  has_many :associate_maintaiain_projects, :through => :associate_maintainers, :source => :project, :class_name => 'Project'
  validates :username, :presence => true, :length => {:minimum => 5, :maximum => 20}, uniqueness: true
  validates_format_of :username, :with => /\A[a-zA-Z0-9][a-zA-Z0-9 _-]+\z/i
  validate :username_changed, on: :update

  before_destroy :destroy_all_user_sourcedb_docs

  scope :except_current_user, lambda { |current_user|
    if current_user.present?
      where(["id != ?", current_user.id])
    else
      all
    end
  }
  scope :except_project_associate_maintainers, lambda{|project_id|
      project = Project.find(project_id)
      associate_maintainers_ids = project.associate_maintainers.collect{|associate_maintainer| associate_maintainer.user_id}
      if associate_maintainers_ids.present?
        where(["id NOT IN (?)", associate_maintainers_ids])
      else
        all
      end
  }

  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    else
      where(conditions).first
    end
  end

  def root?
    root
  end

  def check_invalid_character
    if username =~/(\/|\?|\#|\%)/
      errors.add(:username, I18n.t('errors.messages.invalid_character_included'))
    end
  end

  def username_changed
    errors.add(:username, I18n.t('errors.messages.unupdatable')) if username_changed?
  end

  def destroy_all_user_sourcedb_docs
    Doc.user_source_db(self.username).destroy_all
  end

  def self.from_omniauth(auth)
    user = User.find_by_email(auth.info.email)
    return user if user and user.confirmed?

    user = User.new(email: auth.info.email,
                    username: auth.info.name,
                    password: Devise.friendly_token[0,20]
                   )
    user.save
    user
  end
end
