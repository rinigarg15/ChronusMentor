class RemoveUser
  attr_accessor :progress
  def initialize(users, invalid_user_ids, options = {})
    @users = users
    @progress = ProgressStatus.create!(maximum: @users.count + invalid_user_ids.count, ref_obj: options[:current_user], for: ProgressStatus::For::User::REMOVE_USER, completed_count: invalid_user_ids.count)
  end

  def remove_users_background
    @users.each do |user|
      user.destroy
      @progress.increment!(:completed_count)
    end
  end
end