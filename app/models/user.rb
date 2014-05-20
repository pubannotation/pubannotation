class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :login, :username, :email, :password, :password_confirmation, :remember_me
  # attr_accessible :title, :body
  # Virtual attribute for authenticating by either username or email
  # This is in addition to a real persisted field like 'username'
  attr_accessor :login
  
  has_many :projects
  has_many :associate_maintainers, :dependent => :destroy
  has_many :associate_maintaiain_projects, :through => :associate_maintainers, :source => :project, :class_name => 'Project'

  scope :except_current_user, lambda { |current_user| where(["id != ?", current_user.id]) }
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
end
