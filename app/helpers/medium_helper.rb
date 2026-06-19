module MediumHelper
  def current_user_owns_medium?(medium)
    medium.user == current_user
  end
end
